# Faz 7 — Mağaza & Hosting Paketi

Metinler: [STORE_LISTING.md](STORE_LISTING.md). Teknik: [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md).

## Sıra

1. Internal / closed testing (Play) + TestFlight (iOS) — açık mağazadan önce.
2. Listing: ad, kısa/uzun açıklama, ekran görüntüleri (`mobile/assets/images/screenshots/`).
3. Data Safety / App Privacy tablosu (STORE_LISTING).
4. Gizlilik / destek URL: `https://eduly-server.web.app/privacy.html` vb.
5. Final Hosting deploy (web-panel release build).
6. Versiyon: mobil `1.0.0+N` ([mobile/pubspec.yaml](mobile/pubspec.yaml)).

## Rollback

- Hosting: `firebase hosting:clone SOURCE_SITE:CHANNEL TARGET_SITE:live` veya önceki release’i Console’dan rollback.
- Play: staged rollout % → durdur / previous bundle.
- App Store: Phased release durdur.

## Kapı (7.V)

- [ ] Internal testing canlı veya review’a gönderildi — [PRODUCTION_RUNBOOK.md](PRODUCTION_RUNBOOK.md)
- [x] Keystore yedek (repo dışı: `~/Documents/Eduly-Release-Secrets/`)
- [ ] APNs `.p8` yedek + Firebase’e yükleme (sen)
- [x] Rollback notu bu dosyada
