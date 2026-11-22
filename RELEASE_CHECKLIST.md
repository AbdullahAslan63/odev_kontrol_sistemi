# 🚀 Eduly — Release & Mağaza Yayın Rehberi

Bu belge, **Eduly** uygulamasının **Google Play Store (`com.eduly.app`)** ve **Apple App Store (`com.eduly.mobile`)** yayın öncesi kontrol adımlarını özetler.

---

## ⚠️ Yayın Öncesi Zorunlu Konsol Adımları (Kod Dışı)

Kod tabanı temizlendikten sonra yalnızca konsollardan yapılabilecek 4 adım:

1. **Firebase Console (`eduly-server`):**
   - **Project Settings → Add app → Android** seçip paket adı olarak **`com.eduly.app`** ekleyin, oluşan **`google-services.json`** dosyasını indirip `android/app/google-services.json` üzerine kaydedin. *(Eski `odevtakipsistemi-b93b2` JSON'ı mutlaka değiştirilmelidir!)*
   - **Authentication → Sign-in method → Email/Password** sağlayıcısının **Etkin (Enabled)** olduğundan emin olun.
   - Bu repodaki güncel `firestore.rules` dosyasını `eduly-server` Firestore kurallarına yayınlayın (`firebase deploy --only firestore:rules`).

2. **Android Upload Keystore Üretimi (Tek Seferlik):**
   ```powershell
   keytool -genkey -v -keystore android/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
   - `android/key.properties.example` dosyasını `android/key.properties` olarak kopyalayıp kendi şifrelerinizi yazın.
   - `upload-keystore.jks` dosyasını mutlaka güvenli bir yerde yedekleyin (**asla Git'e commit etmeyin**).

3. **Temiz Mağaza Ekran Görüntüleri:**
   - Eski `assets/images/screenshots/asc/iphone67_*.png` görsellerinde Android/MIUI durum çubuğu ve eski "MatPusula" yazısı olduğu için bunları **gerçek iPhone simülatörü/cihazından alınan temiz Eduly ekran görüntüleriyle** değiştirin.
   - Google Play için ayrı temiz Android ekran görüntüleri yükleyin.

4. **Mağaza Konsol Formları:**
   - **Google Play Console (`com.eduly.app`):**
     - **Gizlilik Politikası URL:** `https://cdn.jsdelivr.net/gh/AbdullahAslan63/odev_kontrol_sistemi@main/docs/privacy.html`
     - **Hesap Silme URL:** Uygulama içi `Profil → Hesabımı Sil` + e-posta desteği (`josephpgzl156@gmail.com`)
     - **Data Safety:** Ad Soyad, E-posta Adresi, Kullanıcı Kimliği (Hesap/Uygulama İşlevi); Kilitlenme Günlükleri (Crashlytics).
     - **İnceleme Hesabı (App Access):** İnceleme ekibi için çalışan bir Öğretmen ve bir Veli demo hesabının e-posta/şifresini ekleyin.
   - **Apple App Store Connect (`com.eduly.mobile`):**
     - **Category:** Education / Eğitim
     - **Age Rating:** 4+
     - **App Privacy:** Name, Email Address, User ID (Linked), Crash Data (Not Linked) — `ios/Runner/PrivacyInfo.xcprivacy` ile birebir uyumlu.
     - **Privacy Policy URL:** `https://cdn.jsdelivr.net/gh/AbdullahAslan63/odev_kontrol_sistemi@main/docs/privacy.html`
     - **Support URL:** `https://cdn.jsdelivr.net/gh/AbdullahAslan63/odev_kontrol_sistemi@main/docs/support.html`
     - **Terms URL:** `https://cdn.jsdelivr.net/gh/AbdullahAslan63/odev_kontrol_sistemi@main/docs/terms.html`
     - **App Review Information:** İnceleme ekibinin test edebilmesi için geçerli bir **Öğretmen** hesabı, bir **Veli** hesabı ve gerekirse kullanılmamış bir **Davet Kodu** notu ekleyin.

---

## 📦 Derleme ve Otomatik Yayın Komutları

### Yerel Windows Android App Bundle (`.aab`)
İlk kurulumda (`google-services.json` yerleştirildikten sonra):
```powershell
powershell -ExecutionPolicy Bypass -File scripts/build_android_release.ps1 -InitKeystore
```
Sonraki derlemeler ve ön kontrol:
```powershell
powershell -ExecutionPolicy Bypass -File scripts/build_android_release.ps1 -PreflightOnly
powershell -ExecutionPolicy Bypass -File scripts/build_android_release.ps1
```
Çıktı: `build/app/outputs/bundle/release/app-release.aab`

### iOS TestFlight (`codemagic.yaml` — Mac mini M2, `v*` Tag Tetiklemeli)
```powershell
powershell -ExecutionPolicy Bypass -File scripts/trigger_ios_release.ps1
```
- `codemagic.yaml` içinde `ios-testflight` akışı yalnızca `v*` etiketi push edildiğinde çalışır (normal `main` push'larında aylık 500 dk M2 kotasını harcamaz).
- CocoaPods/Pub cache ve `pubspec.yaml` üzerinden dinamik sürüm senkronizasyonu aktiftir.
- Linux üzerinde `android-playstore` akışı ise M2 kotasından hiç harcamadan imzalı `.aab` üretir.

---

## 🧪 Doğrulama Komutları

```bash
flutter analyze
flutter test
```
