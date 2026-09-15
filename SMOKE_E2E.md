# Faz 6 — Canlı Smoke / E2E Matrisi

Cihazlar: 1× Android fiziksel, 1× iOS fiziksel, Chrome (admin).

| # | Senaryo | Android | iOS | Web | Sonuç |
|---|---------|---------|-----|-----|-------|
| 1 | Öğretmen kayıt / giriş (e-posta) | | | — | |
| 2 | Sınıf + öğrenci + davet kodu | | | — | |
| 3 | Veli OTP kayıt + `/join?code=` | | | — | |
| 4 | Ödev oluştur → veli görür | | | — | |
| 5 | Sınav + grafik | | | — | |
| 6 | Öğretmen mesaj → veli inbox | | | — | |
| 7 | FCM (arka plan / kapalı) | | | — | |
| 8 | Admin login + listeler | — | — | | |
| 9 | Broadcast (FCM token’lı cihaz) | | | | |
| 10 | Hesap silme | | | — | |

## Otomatik kapı

```bash
cd mobile && flutter test
cd ../web-panel && flutter test
```

CI: `.github/workflows/ci.yml`

## Kapı (6.V)

- P0 = 0
- P1 triage’lı (blocker / sonraki patch)
- CI yeşil
