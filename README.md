# Pinna

Linux için AirPods yöneticisi. Kulaklığı bağlar, pilini ve kulakta olup olmadığını gösterir, iPhone'daki ayarların neredeyse hepsini buradan değiştirmeni sağlar.

![Pinna](docs/screenshot.png)

## Neler yapıyor

- Sol, sağ ve kutu pilini gösteriyor, son 24 saatin pil grafiğini tutuyor. Kutu kapalıyken son bilinen değerini, kulaklık bağlı değilken en son ne zaman görüldüğünü yazıyor. Pil azalınca (eşiği sen seçiyorsun) ve şarj bitince bildirim gönderiyor.
- Gürültü engelleme, şeffaf, uyarlanabilir ve kapalı modları arasında anında geçiyor. Uyarlanabilir modda ne kadar ortam sesi gireceğini 0 ile 100 arasında ayarlayabiliyorsun.
- Konuşma algılama, kişiselleştirilmiş ses düzeyi, tek kulaklıkla gürültü engelleme, ses kaydırma, basma hızı, basılı tutma süresi, kutu hoparlörünün sesi, uyku algılama, işitme desteği.
- Sapı basılı tutunca hangi modlar arasında geçileceğini ve sol ile sağ kulaklığın ne yapacağını seçebiliyorsun. Kulaklık bunları her yeni cihazda unuttuğu için Pinna her bağlantıda yeniden yazıyor.
- Bağlanınca kulaklığı varsayılan ses çıkışı yapıyor. Ses düzeyi ve profil uygulamanın içinden.
- Görüşmede mikrofon olarak üç seçenek var. Bilgisayarın mikrofonu ya da AirPods'un yüksek kaliteli mikrofonu seçiliyken kulaklık müzik kalitesinde (AAC) kalıyor. İkincisi deneysel: kulaklığın mikrofonu AAC-ELD olarak ayrı bir kanaldan geliyor, Pinna bunu çözüp "(Pinna)" adlı bir mikrofon olarak sunuyor ve bir uygulama dinleyince kendiliğinden açıyor. Üçüncüsü Bluetooth'un telefon profili; orada ses de mikrofon da telefon kalitesine düşüyor (bu kulaklıkta LC3, 24 kHz).
- Birden fazla eşli AirPods ya da Beats varsa aralarında geçebiliyor, yenisini eşleştirebiliyor, eskisini unutabiliyorsun.
- Sistem tepsisinde duruyor: pil, mod değiştirme, bağlan ve kes. Pencereyi kapatınca tepside kalıyor, istersen oturum açılınca tepside başlıyor.
- Bir kulaklığı çıkarınca çalan şey duruyor, takınca devam ediyor (MPRIS destekleyen her oynatıcıda). Konuşmaya başlayınca bilgisayarın sesini de kısıyor.
- Kutuyu açınca ya da kulaklık bağlanınca köşede küçük bir kart çıkıyor.
- Kulaklık pilini BlueZ üzerinden sisteme de bildiriyor, böylece UPower, GNOME, KDE ve bar uygulamaları kendi pil göstergelerinde gösteriyor.
- Kulaklık bağlı değilken yayınının sinyal gücüyle yakındaki kulaklığı bulmana yardım ediyor.
- İstersen tek kulaklık takılıyken konuşma algılamayı kapatıyor, ikisi takılınca geri açıyor.
- Türkçe ve İngilizce. Varsayılan olarak sistem dilini izliyor, Bu Bilgisayar sayfasından değiştirilebiliyor.
- Baş takibini canlı gösteriyor: başını çevirdikçe ve eğdikçe açılar güncelleniyor.
- Uzamsal ses: stereo ses önündeki iki hoparlörden geliyormuş gibi duyuluyor (PipeWire'ın HRTF süzgeci). Baş takipli modda başını çevirince ses yerinde kalıyor. Bunun için `libmysofa` ve `/usr/share/libmysofa/default.sofa` gerekiyor.
- Sapa çift, üç kez ya da uzun basışı her kulaklık için ayrı ayrı bilgisayarda bir işe bağlayabiliyorsun: mikrofonu susturmak, ses düzeyi, parça değiştirmek ya da kendi yazdığın bir komut. Atanmamış basışlar kulaklığın her zamanki işini yapıyor.

Kulaklık uyarlama, şeffaflık modunu özelleştirme, mikrofon seçimi ve kulak algılamayı kapatma şimdilik yok. Kulaklık bu ayarların değerini geri bildirmediği için doğru çalıştıklarından emin olamadım.

Şu an AirPods Pro 2 (USB-C) üzerinde denendi. Diğer AirPods ve Beats modelleri de aynı protokolü konuştuğu için çoğu ayar çalışmalı, ama kulaklık bir özelliği desteklemiyorsa o ayar bir şey yapmaz.

## Kurulum

Gerekenler: Rust (1.85 ya da yenisi), Qt 6.8 ya da yenisi (Widgets, Quick, QuickControls2, QuickEffects, DBus, Svg), CMake, Ninja, BlueZ, PipeWire (`wpctl` ve `pactl`), FFmpeg'in libavcodec geliştirme paketi (Ubuntu'da `libavcodec-dev`). Çeviri için `lrelease` gerekiyor; yoksa arayüz Türkçe kalır.

```bash
./install.sh
```

Betik her şeyi `~/.local` altına kurar, `pinnad` servisini `systemctl --user` ile açar. sudo istemez. Servis kısıtlı bir ortamda çalışır: sadece `~/.config/pinna`, `~/.local/state/pinna`, kendi çalışma klasörü ve görüşme ayarı için `~/.config/wireplumber/wireplumber.conf.d` altına yazabilir, ağa çıkamaz. BLE anahtarlarının durduğu ayar dosyası 0600 izinle yazılır.

Kulaklığı önce sistemin Bluetooth ayarlarından bir kez eşleştirmen yeterli. Sonrasında Pinna kendisi bulur.

Bazı özellikler kulaklığın karşısında bir Apple cihazı olduğunu görmek istiyor. Bu Bilgisayar sayfasındaki DeviceID ayarı `/etc/bluetooth/main.conf` dosyasına şu satırı ekleyip Bluetooth'u yeniden başlatıyor. Çalıştırmadan önce komutu gösterip parola soruyor. Elle yapmak istersen:

```
DeviceID = bluetooth:004C:0000:0000
```

Hyprland'de pencerenin yüzmesi ve kartın sağ üstte açılması için:

```lua
hl.window_rule({ name = "pinna", match = { class = "^(dev.pinna.Pinna)$" }, float = true, center = true, size = "900 620" })
hl.window_rule({ name = "pinna-kart", match = { class = "^(dev.pinna.Popup)$" }, float = true, pin = true, move = "(monitor_w-window_w-16) 16", no_initial_focus = true })
```

## Komut satırı

```bash
pinnactl                     # durum
pinnactl mode adaptive       # off, anc, transparency, adaptive
pinnactl cycle               # modlar arasında sırayla geç
pinnactl set conversationAwareness on
pinnactl watch               # her değişiklikte bir satır JSON
```

`pinnactl cycle` Hyprland'de bir kısayola bağlamak için uygun:

```
bind = SUPER, A, exec, pinnactl cycle
```

## Caelestia barı

`shell/caelestia/PinnaStatus.qml` barda kulaklık simgesini, en düşük pili ve modu gösterir. Sol tık modu değiştirir, sağ tık uygulamayı açar. Dosyayı `modules/bar/components/status/` altına koyup `StatusIcons.qml` içine bir `DelegateChoice` eklemen yeterli.

## Nasıl çalışıyor

Proje üç parça:

- `crates/core` protokolün kendisi: paketler, BLE reklamlarının çözümü, ayar tablosu. İşletim sisteminden bağımsız, ileride Windows ve Android sürümleri de bunu kullanacak.
- `crates/linux` BlueZ ile konuşan `pinnad` servisi ve `pinnactl`. Servis durumu D-Bus üzerinden `dev.pinna.Daemon` adıyla yayınlıyor.
- `app` Qt Quick ile yazılmış arayüz. Yeni metin ekleyince `app/i18n/update.py` çeviri dosyasını günceller.

Kulaklık görselleri Blender'da render ediliyor. Model Jed Falcone'un [AirPods Pro](https://sketchfab.com/3d-models/3f84ddc3d87a4ec0a5e5f379abfecd9c) çalışması, [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) lisanslı. Modelin kendisi repoda yok; Sketchfab'den indirip görselleri şöyle yeniden üretebilirsin:

```bash
art/build.sh ~/Downloads/airpods-pro/source/Airpods_ForSketchfab.fbx
```

Işık, malzeme ve kadraj `art/render.py` içinde. Modeldeki sol kulaklığın sapı eksik olduğu için sağ kulaklık aynalanarak kullanılıyor.

Protokol konusundaki çalışmaları için [LibrePods](https://github.com/kavishdevar/librepods) ekibine teşekkürler.

## Lisans

GPL-3.0. AirPods, Apple'ın ticari markasıdır; Pinna'nın Apple ile bir bağı yok.
