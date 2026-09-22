# Release & Mağaza Yayın Rehberi

Mobil uygulama kökü: **`mobile/`**. Tüm Flutter/Android/iOS komutları bu dizinden çalıştırılır.

Kod tarafı hazırlık (stabilize/kalite): sürüm `1.0.0+1`, Crashlytics (release), gizlilik sayfaları, CI workflow.
Lansman runbook’ları: [LAUNCH_SCOPE.md](LAUNCH_SCOPE.md), [OPS_DEPLOY.md](OPS_DEPLOY.md), [PLATFORM_RELEASE.md](PLATFORM_RELEASE.md), [SMOKE_E2E.md](SMOKE_E2E.md), [STORE_LAUNCH.md](STORE_LAUNCH.md), [SOFT_LAUNCH.md](SOFT_LAUNCH.md).

---

## 1. Android Keystore

```bash
cd mobile
keytool -genkey -v -keystore android/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

`mobile/android/key.properties`:

```properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=../upload-keystore.jks
```

Keystore ve `key.properties` commit edilmez.

---

## 2. Android App Bundle

```bash
cd mobile
flutter build appbundle --release
```

Çıktı: `mobile/build/app/outputs/bundle/release/app-release.aab`

---

## 3. iOS IPA (macOS + Xcode)

```bash
cd mobile
flutter build ipa --release
```

---

## 4. Admin Web + yasal sayfalar (Firebase Hosting)

```bash
cd web-panel
flutter build web --release
cd ..
firebase deploy --only hosting
```

Yasal sayfalar `web-panel/web/{privacy,terms,support}.html` → build çıktısına kopyalanır:
- https://eduly-server.web.app/privacy.html
- https://eduly-server.web.app/terms.html
- https://eduly-server.web.app/support.html

Ayrıntılar: [HANDOFF.md](HANDOFF.md) Faz B, [ADMIN_SEED.md](ADMIN_SEED.md), [STORE_LISTING.md](STORE_LISTING.md).

---

## 5. Firebase (yayın öncesi zorunlu)

```bash
firebase deploy --only firestore:rules,firestore:indexes,functions,hosting
```

- [x] Rules + indexes deploy
- [x] Functions (`sendBroadcast`) deploy
- [x] Hosting + privacy/terms canlı
- [ ] Local/canlı smoke ([HANDOFF.md](HANDOFF.md)) — fiziksel cihaz; bkz. [PRODUCTION_RUNBOOK.md](PRODUCTION_RUNBOOK.md)

---

## 6. Mağaza kontrol listesi

### Google Play
- [ ] Uygulama adı, kısa/uzun açıklama ([STORE_LISTING.md](STORE_LISTING.md))
- [ ] Ekran görüntüleri
- [ ] Gizlilik politikası URL
- [ ] Data Safety formu
- [ ] İçerik derecelendirmesi / hedef kitle (çocuk odaklı içerik: öğretmen-veli; COPPA dikkat)

### App Store
- [ ] Education kategorisi, yaş derecesi, App Privacy
- [ ] Destek URL + gizlilik URL
- [ ] Ekran görüntüleri (6.7" / 6.1" vb.)

### Teknik
- [x] Upload keystore yedeklendi (`~/Documents/Eduly-Release-Secrets/` + ikinci kopya sen)
- [x] `applicationId` (Android) = `com.eduly.app`; iOS bundle id = `com.eduly.mobile` (Play/App Store ve Firebase app kayıtlarıyla birebir aynı)
- [x] Upload SHA-1/SHA-256 Firebase’e eklendi (2026-09-22); debug SHA zaten vardı
- [ ] Crashlytics Console’da veri geliyor (release build)
- [ ] App Check (önerilir; Console’da etkinleştir — henüz istemci zorunlu değil)

Manuel mağaza adımları: [PRODUCTION_RUNBOOK.md](PRODUCTION_RUNBOOK.md).

---

## 7. Testler

```bash
cd mobile && flutter test
cd ../web-panel && flutter test
cd ../backend && ALLOW_TEST_OTP=true npm test
```

CI: `.github/workflows/ci.yml` (push/PR).

### Not: eski ödev dokümanları
Yeni ödevler `studentIds` alanıyla yazılır (veli okuma kuralları). Eski ödevlerde alan yoksa veli kartında başlık boş kalabilir — gerekirse ödevleri yeniden oluşturun veya bir kerelik backfill uygulayın.
