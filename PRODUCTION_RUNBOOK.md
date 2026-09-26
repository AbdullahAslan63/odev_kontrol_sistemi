# Eduly — Production Yayın Runbook (Manuel Adımlar)

Son güncelleme: 2026-09-26.

Bu dosya **senin (Vefa) Console / Apple / Play tarafında yapman gerekenleri** adım adım anlatır.  
Ajanın tamamladığı teknik hazırlıklar en altta “Tamamlananlar” bölümünde.

Paket kimlikleri:

| Platform | ID |
|----------|-----|
| Android | `com.eduly.app` |
| iOS | `com.eduly.mobile` |
| Firebase | `eduly-server` |
| Sürüm | `1.0.1+4` |

Yasal URL’ler (canlı):

- Gizlilik: https://eduly-server.web.app/privacy.html
- Koşullar: https://eduly-server.web.app/terms.html
- Destek: https://eduly-server.web.app/support.html

---

## 0) Önce bunu yap (5 dk) — yedek doğrula

1. Finder’da aç: `~/Documents/Eduly-Release-Secrets/`
2. İçinde şunlar olmalı:
   - `upload-keystore.jks`
   - `UPLOAD_KEYSTORE_CREDENTIALS.txt`
   - `upload_certificate.pem`
   - `key.properties`
3. Bu klasörü **ikinci bir yere** kopyala (1Password Secure Note / şifreli USB / özel Drive klasörü).
4. **Keystore’u kaybedersen** Play’de aynı uygulamayı güncelleyemezsin (upload key reset mümkün ama ağır).

---

## 1) Firebase — iOS APNs (bloklayıcı)

Phone Auth + FCM production için şart.

### 1.1 Apple Developer’da APNs Key oluştur

1. https://developer.apple.com/account → **Certificates, Identifiers & Profiles**
2. Sol menü **Keys** → **+**
3. Key Name: `Eduly APNs`
4. **Apple Push Notifications service (APNs)** işaretle → Continue → Register
5. **Download** `.p8` (bir kez indirilir) → `~/Documents/Eduly-Release-Secrets/` içine koy
6. Not et:
   - **Key ID** (ör. `AB12CD34EF`)
   - **Team ID**: `77462Y5U57`

### 1.2 App ID’de Push açık mı?

1. **Identifiers** → `com.eduly.mobile`
2. **Push Notifications** capability açık olmalı (Production)

### 1.3 Firebase’e yükle

1. https://console.firebase.google.com/project/eduly-server/settings/cloudmessaging
2. **Apple app configuration** → iOS app `com.eduly.mobile`
3. **APNs Authentication Key** yükle (`.p8` + Key ID + Team ID)
4. Kaydet

### 1.4 Auth / Phone kontrol

1. Authentication → Sign-in method → **Phone** = Enabled  
2. Authentication → Sign-in method → **Email/Password** = Enabled  
3. Project settings → Your apps:
   - Android `com.eduly.app` (SHA’lar ekli — ajan yaptı)
   - iOS `com.eduly.mobile`

---

## 2) Google Play Console — Internal testing

### 2.1 Hesap & uygulama

1. https://play.google.com/console
2. Geliştirici hesabı yoksa oluştur (tek seferlik ücret + kimlik doğrulama).
3. **Create app**
   - App name: **Eduly**
   - Default language: **Türkçe (Turkey)**
   - App or game: App
   - Free / Paid: Free
4. Declarations’ı onayla.

### 2.2 Store listing

**Dashboard → Grow → Store presence → Main store listing**

| Alan | Değer |
|------|--------|
| App name | Eduly |
| Short description | Öğretmen ve veli için ödev & deneme takip platformu. |
| Full description | `STORE_LISTING.md` içindeki uzun açıklama |
| App icon | `mobile/store/play/icon_512.png` |
| Feature graphic | `mobile/store/play/feature_graphic_1024x500.png` |
| Phone screenshots | En az 2 adet — `mobile/assets/images/screenshots/` veya cihazdan yeni çek |
| Category | Education |
| Privacy policy | https://eduly-server.web.app/privacy.html |
| Support email | destek@eduly.app (veya gerçek destek mailin) |

> Not: Mevcut screenshot’lar küçük/taslak olabilir. Review için gerçek cihaz ekran görüntüsü önerilir (öğretmen home + veli ödev + giriş).

### 2.3 App content (zorunlu formlar)

**Policy → App content**

1. **Privacy policy** → privacy URL’yi yapıştır → Save  
2. **Data safety**
   - **Import from CSV** → `mobile/store/eduly_data_safety.csv`
   - Formu gözden geçir → **Submit**
3. **Content ratings** → anketi doldur (Education; reklam yok; kullanıcı etkileşimi var)  
4. **Target audience**
   - Uygulama öğretmen + veli için; çocuklar doğrudan kullanıcı değilse 18+ veya “not designed for children” seçimini bilinçli yap
   - Öğrenci verisi işleniyorsa Families / COPPA sorularını dikkatle oku
5. **Ads** → No  
6. **News app / COVID / Data deletion** vb. kalan formları tamamla  
   - Data deletion: https://eduly-server.web.app/privacy.html

### 2.4 AAB yükle (Internal testing)

1. **Test and release → Testing → Internal testing → Create new release**
2. Google Play App Signing’i kabul et (varsayılan)
3. Upload:
   ```
   mobile/build/app/outputs/bundle/release/app-release.aab
   ```
4. Release name: `1.0.1 (4)`  
5. Release notes (TR): `mobile/store/play/release-notes-tr-1.0.1.txt`
6. **Save → Review → Start rollout to Internal testing**

### 2.5 Tester ekle

1. Internal testing → **Testers** → e-posta listesi oluştur  
2. CSV yükle: `mobile/store/eduly_yakin_cevre_testers.csv`  
   (veya kendi e-postanı ekle)  
3. **Copy link** → testers’a gönder  
4. Tester’lar linki açıp Play’den uygulamayı kursun

### 2.6 Fiziksel Android smoke (sen)

Cihazda sırayla:

1. Öğretmen kayıt / giriş (e-posta)  
2. Sınıf + öğrenci + davet kodu  
3. Veli telefon OTP  
4. Ödev oluştur → veli görür  
5. Mesaj / bildirim (uygulama kapalıyken FCM)  
6. Hesap silme yolu

Sonuçları `SMOKE_E2E.md` tablosuna işaretle.

---

## 3) App Store Connect — TestFlight

### 3.1 Apple Developer + App kaydı

1. https://appstoreconnect.apple.com → **My Apps** → **+** → New App  
2. Platform: iOS  
3. Name: **Eduly**  
4. Bundle ID: **com.eduly.mobile** (Developer’da Identifier olarak kayıtlı olmalı)  
5. SKU: `eduly-ios-001`  
6. User Access: Full Access

### 3.2 IPA yükle (Transporter)

IPA yolu:

```
mobile/build/ios/ipa/Eduly.ipa
```

Yeniden üretmek için:

```bash
cd mobile
./scripts/build_testflight_ipa.sh
```

Yükleme:

1. Mac’te **Transporter** uygulamasını aç (App Store’dan)  
2. Apple ID (team `77462Y5U57` erişimi olan) ile giriş  
3. IPA’yı sürükle → **Deliver**  
4. App Store Connect → TestFlight → build’in işlemesini bekle (5–30 dk)  
5. “Missing Compliance” çıkarsa: Encryption = **No** (`ITSAppUsesNonExemptEncryption=false` zaten plist’te)

### 3.3 TestFlight testçiler

1. TestFlight → Internal Testing → kendi Apple ID’ni ekle  
2. External Testing (isteğe bağlı): e-posta ile davet; ilk external build **Beta App Review** ister  
3. Cihazda TestFlight’tan Eduly’yi kur

### 3.4 Fiziksel iPhone smoke (sen)

1. Veli OTP (gerçek SMS — Blaze + APNs şart)  
2. Öğretmen e-posta  
3. FCM (arka plan / kapalı uygulama)  
4. Davet linki: `https://eduly-server.web.app/join?code=OT-A7K9M2`

### 3.5 App Store listing (Production’a çıkmadan)

**App Store → App Information / Prepare for Submission**

| Alan | Değer |
|------|--------|
| Category | Education |
| Privacy Policy URL | https://eduly-server.web.app/privacy.html |
| Support URL | https://eduly-server.web.app/support.html |
| Marketing URL | (opsiyonel) |
| App Privacy | `STORE_LISTING.md` tablosuna göre: ad, e-posta, telefon, kullanıcı ID, mesajlar, cihaz ID (FCM), crash logs |
| Screenshots | 6.7" ve 6.1" zorunlu setler |
| Age Rating | Anketi doldur |
| Review notes | Test öğretmen hesabı + veli test numarası (Firebase test phone) ver |

---

## 4) Soft launch kapısı (açık mağazadan önce)

1. Internal (Play) + TestFlight (iOS) en az 3–7 gün  
2. Crashlytics: https://console.firebase.google.com/project/eduly-server/crashlytics  
   - Release build’den en az 1 non-fatal / session görünmeli  
3. `SMOKE_E2E.md` P0 = 0  
4. Sonra:
   - Play: Closed testing → Production (staged %10–20)  
   - App Store: Submit for Review → Phased Release

**App Check enforce** bu aşamada zorunlu değil (`SOFT_LAUNCH.md` / Faz 8).

Kurallar ve fonksiyonlar repoda güncellendi; canlıya ayrıca basılmalı:

```bash
firebase deploy --only firestore:rules,functions,storage
```

`sendTeacherMessage` deploy edilmeden öğretmen duyurusu istemciden yazılamaz. Storage kuralı kovayı kapatır.

---

## 5) Sık yapılan hatalar

| Hata | Sonuç |
|------|--------|
| Upload SHA Firebase’de yok | Release APK/AAB’de Phone Auth / reCAPTCHA fail |
| APNs yok | iOS FCM + bazen Phone Auth sorunları |
| Keystore yedeksiz | Güncelleme imkânsızlaşır |
| versionCode artmadan yeni AAB | Play reddeder |
| Privacy URL 404 | Store listing / review reddi |
| Data Safety yanlış (fotoğraf topluyoruz demek) | Policy riski — AI tarayıcı kapalı, foto beyan etme |

Sonraki sürüm:

```bash
# pubspec: 1.0.1+3
cd mobile
flutter build appbundle --release
./scripts/build_testflight_ipa.sh
```

---

## Tamamlananlar (ajan — 2026-09-22)

- [x] Firebase Android upload **SHA-1 + SHA-256** eklendi (`com.eduly.app`)
- [x] Keystore yedeği: `~/Documents/Eduly-Release-Secrets/`
- [x] Play icon 512 + feature graphic 1024×500 üretildi (`mobile/store/play/`)
- [x] App Store 1024 icon üretildi (`mobile/store/appstore/`)
- [x] Data Safety CSV hazır (`mobile/store/eduly_data_safety.csv`)
- [x] Tester CSV hazır (`mobile/store/eduly_yakin_cevre_testers.csv`)
- [x] iOS team `77462Y5U57` + production push entitlements + TestFlight script
- [x] Release AAB / IPA yolları hazır (yeniden build bu oturumda çalıştırıldı veya mevcut)
- [x] Hosting yasal sayfalar canlı

## Senin hâlâ yapman gerekenler (özet)

1. APNs `.p8` → Firebase Cloud Messaging  
2. Play Console: listing + Data Safety import + Internal testing AAB  
3. Transporter ile IPA → TestFlight  
4. Android + iPhone fiziksel smoke  
5. Soft launch sonrası Production / App Review  
