# Faz 4 — Platform Release Checklist

## Android

1. Keystore oluştur (bir kez; yedekle, commit etme):

```bash
cd mobile
keytool -genkey -v -keystore android/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

2. `mobile/android/key.properties` (gitignore’da):

```properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=../upload-keystore.jks
```

3. Release AAB (keystore yoksa Gradle hata verir — bilinçli):

```bash
cd mobile && flutter build appbundle --release
```

4. SHA-1/256’yı Firebase Android app’e ekle (`keytool -list -v -keystore ...`).

## iOS

1. Apple Developer: App ID `com.eduly.app` + Push Notifications.
2. `Runner.entitlements`: debug `aps-environment=development`; App Store için Xcode’da **production**.
3. Firebase Console → iOS app → APNs key.
4. IPA:

```bash
cd mobile && flutter build ipa --release
```

## Web admin

```bash
cd web-panel && flutter build web --release && cd ..
firebase deploy --only hosting --project eduly-server
```

Doğrula: `/privacy.html`, `/terms.html`, `/support.html`, SPA deep link `/teachers`.

## Crashlytics / FCM

- Release build’te Crashlytics açık (`main.dart` `!kDebugMode`).
- Android 13+: `POST_NOTIFICATIONS` manifesto + runtime `requestPermission`.
- Default FCM channel: `eduly_default`.

## Kapı (4.V)

- [ ] AAB release-signed
- [ ] IPA fiziksel cihazda OTP + FCM
- [ ] Hosting yasal sayfalar + admin deep link
