#!/usr/bin/env bash
#
# CachyOS / Arch Linux Privacy Auto-Setup
# - Boot'ta rastgele MAC adresi (macchanger)
# - Cloudflare WARP otomatik bağlantı
# - NetworkManager "sınırlı bağlantı" (?) simgesi düzeltmesi
#
set -uo pipefail
# NOT: set -e kasıtlı olarak KULLANILMIYOR. warp-cli gibi araçlar zaten
# bağlıyken/kayıtlıyken sıfırdan farklı çıkış kodu döndürebiliyor; script
# bu yüzden erken durmasın diye her adım kendi hata kontrolünü yapıyor.

VIRTUAL_IFACE_REGEX='^(lo|docker|veth|br-|virbr|tun|tap|wg|vboxnet|zt)'

log()  { echo "[+] $*"; }
warn() { echo "[!] $*" >&2; }
die()  { echo "[X] $*" >&2; exit 1; }

require_cmd() {
    command -v "$1" &> /dev/null
}

# ---------------------------------------------------------------------------
# 1) Aktif / fiziksel ağ arayüzünü bul
# ---------------------------------------------------------------------------
log "Aktif ağ arayüzü aranıyor..."

INTERFACE=$(ip route | awk '/^default/ {print $5; exit}')

if [ -z "${INTERFACE:-}" ]; then
    INTERFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -Ev "$VIRTUAL_IFACE_REGEX" | head -n 1)
fi

if [ -z "${INTERFACE:-}" ]; then
    die "Kullanılabilir bir ağ arayüzü bulunamadı. Elle ayarlamak için scripti düzenleyin."
fi

if echo "$INTERFACE" | grep -Eq "$VIRTUAL_IFACE_REGEX"; then
    die "Bulunan arayüz ($INTERFACE) sanal görünüyor. Güvenlik için işlem durduruldu."
fi

log "Kullanılacak ağ arayüzü: $INTERFACE"

# ---------------------------------------------------------------------------
# 2) Paketler
# ---------------------------------------------------------------------------
log "Pacman paketleri yükleniyor..."
sudo pacman -S macchanger --needed --noconfirm || die "macchanger kurulamadı."

log "Cloudflare WARP kontrol ediliyor..."
if ! require_cmd warp-cli; then
    if require_cmd yay; then
        yay -S cloudflare-warp-bin --needed --noconfirm
    elif require_cmd paru; then
        paru -S cloudflare-warp-bin --needed --noconfirm
    else
        die "'yay' veya 'paru' bulunamadı. 'cloudflare-warp-bin' paketini AUR üzerinden elle yükleyip scripti tekrar çalıştırın."
    fi
fi

require_cmd warp-cli || die "warp-cli kurulumdan sonra bulunamadı."

# ---------------------------------------------------------------------------
# 3) NetworkManager'ın kendi MAC yönetimini devre dışı bırak
#    (macchanger ile çakışmaması için)
# ---------------------------------------------------------------------------
if require_cmd nmcli; then
    log "NetworkManager MAC yönetimi macchanger ile çakışmasın diye 'preserve' yapılıyor..."
    sudo mkdir -p /etc/NetworkManager/conf.d/
    printf '[device]
wifi.scan-rand-mac-address=no

[connection]
wifi.cloned-mac-address=preserve
ethernet.cloned-mac-address=preserve
' | sudo tee /etc/NetworkManager/conf.d/10-mac-preserve.conf > /dev/null
fi

# ---------------------------------------------------------------------------
# 4) MAC Changer systemd servisi
# ---------------------------------------------------------------------------
log "MAC Changer servisi oluşturuluyor ($INTERFACE için)..."

# systemd device unit adları özel karakterler için escape gerektirir
# (örn. arayüz adında '-' varsa). systemd-escape ile doğru isim üretilir.
ESCAPED_IFACE=$(systemd-escape "$INTERFACE")

printf '[Unit]
Description=macchanger on %s
Wants=network-pre.target
Before=network-pre.target NetworkManager.service
BindsTo=sys-subsystem-net-devices-%s.device
After=sys-subsystem-net-devices-%s.device

[Service]
Type=oneshot
ExecStart=/usr/bin/ip link set dev %s down
ExecStart=/usr/bin/macchanger -r %s
ExecStart=/usr/bin/ip link set dev %s up
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
' "$INTERFACE" "$ESCAPED_IFACE" "$ESCAPED_IFACE" "$INTERFACE" "$INTERFACE" "$INTERFACE" \
    | sudo tee /etc/systemd/system/macchanger.service > /dev/null

sudo systemctl daemon-reload
sudo systemctl enable --now macchanger.service || warn "macchanger.service başlatılamadı, logları kontrol edin: journalctl -u macchanger.service"

# ---------------------------------------------------------------------------
# 5) Cloudflare WARP
# ---------------------------------------------------------------------------
log "Cloudflare WARP servisi başlatılıyor..."
sudo systemctl enable --now warp-svc.service || die "warp-svc.service başlatılamadı."

# warp-svc'nin soket üzerinden hazır olmasını bekle
for i in $(seq 1 10); do
    warp-cli --accept-tos status &> /dev/null && break
    sleep 1
done

warp-cli --accept-tos registration new  &> /dev/null || true
warp-cli --accept-tos mode warp          &> /dev/null || true
warp-cli --accept-tos connect            &> /dev/null || true

log "WARP otomatik bağlanma servisi oluşturuluyor..."
printf '[Unit]
Description=Auto Connect Cloudflare WARP
After=warp-svc.service network-online.target
Wants=warp-svc.service network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/warp-cli --accept-tos connect
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
' | sudo tee /etc/systemd/system/warp-autoconnect.service > /dev/null

sudo systemctl daemon-reload
sudo systemctl enable warp-autoconnect.service

# ---------------------------------------------------------------------------
# 6) NetworkManager "sınırlı bağlantı" (?) ikonu düzeltmesi
# ---------------------------------------------------------------------------
log "NetworkManager captive-portal kontrolü kapatılıyor..."
sudo mkdir -p /etc/NetworkManager/conf.d/
printf '[connectivity]
enabled=false
' | sudo tee /etc/NetworkManager/conf.d/20-connectivity.conf > /dev/null

sudo systemctl restart NetworkManager

# ---------------------------------------------------------------------------
# 7) Durum kontrolü
# ---------------------------------------------------------------------------
log "Kurulum tamamlandı! Durum kontrolleri:"
macchanger -s "$INTERFACE" || true
warp-cli --accept-tos status || true
curl -s https://www.cloudflare.com/cdn-cgi/trace || warn "curl trace başarısız oldu (WARP henüz bağlanmamış olabilir)."
