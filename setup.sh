#!/usr/bin/env bash

set -e

echo "[+] Aktif ağ arayüzü aranıyor..."
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n 1)

if [ -z "$INTERFACE" ]; then
    INTERFACE=$(ip link | awk -F: '$1 ~ /^[0-9]+$/ && $2 !~ /lo/ {print $2; exit}' | tr -d ' ')
fi
echo "[+] Kullanılacak ağ arayüzü: $INTERFACE"

echo "[+] Paketler yükleniyor..."
sudo pacman -S macchanger wget --needed --noconfirm
yay -S cloudflare-warp-bin --needed --noconfirm

echo "[+] MAC Changer servisi oluşturuluyor ($INTERFACE için)..."
sudo tee /etc/systemd/system/macchanger.service > /dev/null << EOF
[Unit]
Description=macchanger on $INTERFACE
Wants=network-pre.target
Before=network-pre.target NetworkManager.service
BindsTo=sys-subsystem-net-devices-$INTERFACE.device
After=sys-subsystem-net-devices-$INTERFACE.device

[Service]
Type=oneshot
ExecStart=/usr/bin/ip link set dev $INTERFACE down
ExecStart=/usr/bin/macchanger -r $INTERFACE
ExecStart=/usr/bin/ip link set dev $INTERFACE up
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now macchanger.service

echo "[+] Cloudflare WARP servisi ve ayarları yapılıyor..."
sudo systemctl enable --now warp-svc.service

warp-cli registration new || true
warp-cli mode warp
warp-cli connect

echo "[+] WARP otomatik bağlanma servisi oluşturuluyor..."
sudo tee /etc/systemd/system/warp-autoconnect.service > /dev/null << 'EOF'
[Unit]
Description=Auto Connect Cloudflare WARP
After=warp-svc.service network-online.target
Wants=warp-svc.service network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/warp-cli connect
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable warp-autoconnect.service

echo "[+] NetworkManager bağlantı kontrolü kapatılıyor..."
sudo mkdir -p /etc/NetworkManager/conf.d/
sudo tee /etc/NetworkManager/conf.d/20-connectivity.conf > /dev/null << 'EOF'
[connectivity]
enabled=false
EOF

sudo systemctl restart NetworkManager

echo "[+] Kurulum tamamlandı! Durum kontrolleri:"
macchanger -s $INTERFACE
curl https://www.cloudflare.com/cdn-cgi/trace
