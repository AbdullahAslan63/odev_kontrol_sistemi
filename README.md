<div align="center">

  <img src="assets/images/eduly_app_icon_1024.png" alt="Eduly Logo" width="140" />

  # Eduly — Ödev & Deneme Sınavı Takip Platformu

  **Öğretmenler için merkezi sınıf yönetimi, veliler için şeffaf öğrenci takibi**

  [![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
  [![Firebase](https://img.shields.io/badge/Firebase-Auth%20%7C%20Firestore%20%7C%20Crashlytics-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)

</div>

---

## ✨ Özellikler

### 👨‍🏫 Öğretmen Modülü
* **Sınıf & Öğrenci Yönetimi:** Sınıf oluşturma, öğrenci ekleme/silme, okul numarası ve öğretmen notu takibi.
* **Tek Kullanımlık Davet Kodu (`OT-XXXXXX`):** Kriptografik rastgele, 14 gün geçerli davet kodu üretme ve tek dokunuşla kopyalama.
* **Ödev Takip Paneli:** Sınıfa toplu ödev tanımlama; *Tamamlandı*, *Yapılmadı*, *Bekliyor* durum güncellemesi.
* **Deneme Sınavı & Net Hesabı:** Ders bazlı Doğru/Yanlış/Boş girişleri ile otomatik net hesabı (4 Yanlış = 1 Doğru) ve `fl_chart` gelişim grafikleri.
* **Duyuru & Mesajlaşma:** Sınıf velilerine veya tüm velilere duyuru iletme, gönderilen duyuruları görüntüleme ve uygulama içi bildirim oluşturma.

### 👨‍👩‍👧‍👦 Veli Modülü
* **Davet Koduyla Güvenli Kayıt:** Öğretmenden alınan kod ile öğrenciye bağlanma, e-posta ve şifre ile güvenli giriş.
* **Çoklu Çocuk Desteği:** Birden fazla çocuğu profil üzerinden bağlayıp tek ekranda aralarında geçiş yapabilme.
* **Ödev, Deneme & Duyuru Takibi:** Çocuğun ödev durumlarını, deneme net grafiklerini, öğretmen değerlendirme notlarını ve bildirimlerini anlık izleme.

---

## 🏗️ Proje Mimarisi

```text
lib/
├── app/                  # GoRouter yönlendirme (refreshListenable) ve RoleGuard
├── core/                 # Tema, sabitler, logo, URL/net yardımcıları, ortak bileşenler
└── features/
    ├── analytics/        # fl_chart grafikleri ve hedef ilerleme analizleri
    ├── auth/             # Firebase Auth (Öğretmen & Veli), rol koruma ve kalıcı hesap silme
    ├── classes/          # Sınıf listesi ve detay ekranları
    ├── dashboard/        # Öğretmen & Veli canlı ana panelleri
    ├── exams/            # Deneme sınavı sonuçları ve net hesaplayıcı
    ├── goals/            # Öğrenci hedef modeli ve deposu
    ├── homeworks/        # Ödev atama ve kontrol listesi
    ├── messages/         # Veli duyuru ve mesajlaşma servisleri
    ├── notifications/    # Uygulama içi bildirim merkezi
    ├── profile/          # Profil, şifre değiştirme, gizlilik/koşullar ve hesap silme
    └── students/         # Öğrenci profilleri, çoklu çocuk seçici ve davet kodu üretimi
```

---

## 🧪 Doğrulama

```bash
flutter pub get
flutter analyze
flutter test
```

Mağaza yayını ve Firebase/Keystore adımları için [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md) dosyasına bakın.

---

© 2026 **Eduly**. Tüm hakları saklıdır.
