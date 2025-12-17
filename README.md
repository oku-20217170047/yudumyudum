Şu an adım sıralamasını **“MVP’yi en hızlı bitir + gösterişli (göz boyayan) özellikler”** mantığıyla gidiyoruz: önce giriş/tema/veri akışı, sonra su takibi (çekirdek), sonra alışkanlık/rozet (sunumluk), en son bildirim ve dashboard.

## Şu ana kadar yaptıklarımız

* **6.1–6.3**: Proje + paketler + temel UI/tema (dark uyumlu)
* **6.4.1**: Boot akışı (login mi app mi)
* **6.4.2**: Auth (login + register) Supabase
* **6.5**: Su takibi `water_logs` (ekle/listele/undo) + hedef güncelleme fix
* **6.6**: Alışkanlıklar CRUD `habits`
* **6.7**: Rozet sistemi `user_badges` (tek seferlik rozet)
* **6.8**: Profil ekranı Supabase + tema seçimi (Riverpod notifier ile)
* **6.9.1–6.9.3**: Local notification altyapısı (desugaring dahil)

## Şu an bulunduğumuz yer

* **6.9.4**: Habit ekleyince otomatik bildirim planla, kapatınca iptal et (MVP hatırlatma)

## Bundan sonraki plan (benim önerdiğim sıralama)

* **6.10 Dashboard (sunumluk ekran)**

  * Son 7 gün su grafiği (basit bar/line)
  * “bugün hedefe ne kadar kaldı” kartı
  * “streak” (kaç gün üst üste hedef)
* **6.11 Streak rozeti**

  * `streak_7_days` rozetini otomatik ver
* **6.12 UI cilası**

  * ikonlar, animasyonlu progress, skeleton loading
* **6.13 Edge case**

  * internet yok uyarısı, boş state’ler, hata mesajları
* **6.14 Release hazırlık**

  * app icon/splash, version, apk/abb build komutları

İstersen bu sırayı “senin case’lerdeki numaralara” birebir hizalayacak şekilde de yeniden adlandırırım ama mantık değişmez: **çekirdek -> CRUD -> rozet -> bildirim -> dashboard -> polish**.


