#!/usr/bin/env bash

set -e

echo "[+] Paketler yükleniyor..."
sudo pacman -S macchanger wget --needed --noconfirm[cite: 1]
yay -S cloudflare-warp-bin --needed --noconfirm[cite: 1]

echo "[+] MAC Changer servisi oluşturuluyor..."
sudo tee /etc/systemd/system/macchanger.service > /dev/null << 'EOF'
[Unit]
Description=macchanger on wlan0
Wants=network-pre.target
Before=network-pre.target NetworkManager.service
BindsTo=sys-subsystem-net-devices-wlan0.device
After=sys-subsystem-net-devices-wlan0.device

[Service]
Type=oneshot
ExecStart=/usr/bin/ip link set dev wlan0 down
ExecStart=/usr/bin/macchanger -r wlan0
ExecStart=/usr/bin/ip link set dev wlan0 up
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload[cite: 1]
sudo systemctl enable --now macchanger.service[cite: 1]

echo "[+] Cloudflare WARP servisi ve ayarları yapılıyor..."
sudo systemctl enable --now warp-svc.service[cite: 1]

warp-cli registration new || true[cite: 1]
warp-cli mode warp[cite: 1]
warp-cli connect[cite: 1]

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

sudo systemctl enable warp-autoconnect.service[cite: 1]

echo "[+] NetworkManager bağlantı kontrolü kapatılıyor..."
sudo mkdir -p /etc/NetworkManager/conf.d/
sudo tee /etc/NetworkManager/conf.d/20-connectivity.conf > /dev/null << 'EOF'
[connectivity]
enabled=false
EOF

sudo systemctl restart NetworkManager[cite: 1]

echo "[+] Kurulum tamamlandı! Durum kontrolleri:"
macchanger -s wlan0[cite: 1]
curl https://www.cloudflare.com/cdn-cgi/trace[cite: 1]
