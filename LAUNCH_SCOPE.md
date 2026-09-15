# Eduly — Lansman Kapsam Kilidi (Faz 0)

Son güncelleme: 2026-09-15. Won’t-ship bilerek dışarıda; App Check enforce Faz 8.

## Must-ship

| Yüzey | Özellik |
|-------|---------|
| Mobil öğretmen | E-posta auth, sınıf, öğrenci, davet kodu, ödev, sınav (manuel), mesaj, FCM |
| Mobil veli | Telefon OTP, davet/`/join`, ödev/sınav/mesaj görüntüleme, FCM |
| Web admin | Login (`role=admin`), dashboard, öğretmen/öğrenci listeleri, aktivite, broadcast |
| Altyapı | Firestore rules+indexes, Functions (`sendBroadcast`, `getTeacherAuthPreview`), Hosting + yasal sayfalar |

## Won’t-ship (lansman)

- AI sınav tarayıcı
- Postgres / `backend/` sync
- App Check **enforce** (monitor Faz 8’de)

## WIP sınıflandırması (uncommitted → lansman kodu)

| Paket | Dosyalar | Karar |
|-------|----------|--------|
| Auth / SMS / splash | `auth_repository_impl`, parent/teacher auth flows, `sms_service`, `splash`, `main`, `router` | Must — stabilize + merge |
| Sınıf / öğrenci / ödev | classes/students/homeworks repos + screens | Must |
| Öğretmen home / sınav | `teacher_home_screen`, exam providers/screens | Must |
| FCM | `fcm_service` | Must |
| iOS native | AppDelegate, SceneDelegate, Info.plist, pbxproj, entitlements, xcconfig | Must (push/OTP) |
| Firestore | `firestore.rules`, `firestore.indexes.json` | Must — Faz 1 sertleştirme sonrası |
| Analiz lint / lock | `analysis_options`, `pubspec.lock` | Must |
| SwiftPM xcshareddata | untracked `swiftpm/` | Commit edilebilir (Xcode); secrets yok |

## Sürüm hedefi

- Mobil: `0.1.0+1` → mağaza gönderiminde `1.0.0+1` ([mobile/pubspec.yaml](mobile/pubspec.yaml))
- Web panel: mevcut `0.2.0` yeterli; Hosting ile birlikte yayın

## Kapı (0.V)

- [x] Must / won’t kilitli
- [x] WIP paketleri sınıflı
- Commit: kullanıcı isteğine bağlı; kod değişiklikleri bu planda uygulanır
