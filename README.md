# CachyOS / Arch Linux Privacy Auto-Setup

Bu proje, Arch tabanlı sistemlerde (CachyOS vb.) sistem açılışında otomatik MAC adresi değiştirmeyi, Cloudflare WARP tünellemesini ve NetworkManager sınırlı bağlantı simgesi düzeltmesini otomatize eder.

## Özellikler

- **MAC Spoofing:** `wlan0` arayüzü için her boot esnasında rastgele MAC adresi atar.
- **Cloudflare WARP:** Sistem açıldığında otomatik bağlanan tünel servisi kurar.
- **NetworkManager Fix:** Captive Portal denetimini devre dışı bırakarak Wi-Fi üzerindeki soru işareti simgesini düzeltir.

## Kullanım

Çalıştırma izni verip betiği çalıştırın:

```bash
chmod +x setup.sh
./setup.sh
