# CachyOS / Arch Linux Privacy Auto-Setup

Bu proje, Arch tabanlı sistemlerde (CachyOS vb.) sistem açılışında otomatik MAC adresi değiştirmeyi, Cloudflare WARP tünellemesini ve NetworkManager sınırlı bağlantı simgesi düzeltmesini otomatize eder.

## Özellikler

- **Dinamik Ağ Algılama:** Sistemdeki aktif, fiziksel ağ kartını (`wlan0`, `eth0`, `wlp3s0` vb.) otomatik tespit eder; `docker0`, `veth*`, `br-*`, `virbr*`, `tun*`, `wg*` gibi sanal arayüzleri hariç tutar.
- **MAC Spoofing:** Algılanan ağ arayüzü için her boot esnasında rastgele MAC adresi atar.
- **NetworkManager Uyumluluğu:** NM'nin kendi MAC randomizasyon/yönetim mekanizmasını `preserve` moduna alarak macchanger servisiyle çakışmasını engeller.
- **Cloudflare WARP:** Sistem açıldığında otomatik bağlanan tünel servisi kurar.
- **NetworkManager Fix:** Captive Portal denetimini devre dışı bırakarak Wi-Fi üzerindeki soru işareti simgesini düzeltir.
- **Hataya Dayanıklı Kurulum:** `warp-cli` zaten kayıtlı/bağlıysa script durmaz; her adım kendi hata kontrolünü yapar.

## Kullanım

### Yöntem 1 — Dosyayı çalıştırarak

```bash
chmod +x setup.sh
./setup.sh
```

### Yöntem 2 — Tek satır (fish shell)

Aşağıdaki tek komut, scripti indirip/oluşturup doğrudan çalıştırır:

```fish
curl -fsSL https://raw.githubusercontent.com/Praxis1071/CachyOS-Privacy-Setup/main/setup.sh | bash
```

> `<kullanici>/<repo>` kısmını kendi deponuzla değiştirin. Depo yoksa, aşağıdaki "Chat'ten kopyala-yapıştır" komutunu kullanabilirsiniz.

## Önemli Notlar / Uyarılar

- Script `sudo` gerektiren birçok sistem dosyasını değiştirir (systemd unit'leri, NetworkManager konfigürasyonu). Çalıştırmadan önce içeriğini gözden geçirmeniz önerilir.
- `cloudflare-warp-bin` AUR paketidir; `yay`/`paru` ile `--noconfirm` bayrağı kullanılarak kurulur. AUR paketlerini güvenmeden önce PKGBUILD'ini incelemeniz tavsiye edilir.
- `connectivity.enabled=false` ayarı, captive portal (havaalanı/otel Wi-Fi giriş sayfaları) algılamasını da etkileyebilir.
- Sanal makine, konteyner veya çoklu ağ kartı olan sistemlerde otomatik arayüz tespiti yanlış kart seçebilir; gerekirse `INTERFACE` değişkenini elle ayarlayın.
- Script tekrar çalıştırılabilir (idempotent); mevcut servis/konfigürasyon dosyalarının üzerine güvenle yazar.
- **WARP bağlantı doğrulaması manueldir:** MAC değişimi ve WARP bağlantısı sırasında ağ birkaç saniyeliğine kesintiye uğrayabildiğinden, script içinde otomatik bir `curl` testi YOKTUR (yanlış-negatif hata vermesin diye). Kurulum bittikten birkaç saniye sonra bağlantıyı kendiniz doğrulayın:

  ```bash
  warp-cli --accept-tos status && curl -s https://www.cloudflare.com/cdn-cgi/trace
  ```

  Çıktıda `warp=on` satırını görmelisiniz.

## Kaldırma

```bash
sudo systemctl disable --now macchanger.service warp-autoconnect.service
sudo rm /etc/systemd/system/macchanger.service /etc/systemd/system/warp-autoconnect.service
sudo rm /etc/NetworkManager/conf.d/10-mac-preserve.conf /etc/NetworkManager/conf.d/20-connectivity.conf
sudo systemctl daemon-reload
sudo systemctl restart NetworkManager
warp-cli disconnect
```
