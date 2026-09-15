# Faz 8 — Soft Launch & App Check

## Metrikler (3–7 gün)

| Metrik | Kaynak | Hedef |
|--------|--------|-------|
| Crash-free users | Crashlytics | ≥ 99% |
| Auth hata oranı | Auth / Analytics | Düşük spike yok |
| Functions error | Cloud Functions logs | `sendBroadcast` / preview OK |
| Firestore okuma | Usage | Bütçe içinde |
| SMS maliyeti | Phone Auth | Beklenen kohort |

## App Check

1. Console → App Check: Play Integrity (Android), DeviceCheck (iOS), reCAPTCHA Enterprise (Web).
2. **Monitor** modunda 3–7 gün.
3. Client: `firebase_app_check` init (sonraki patch).
4. Functions: `consumeAppCheckToken: true` (preview + broadcast).
5. Enforce kademeli; OTP/smoke kırılırsa geri al.

## Kohort

Küçük öğretmen + veli grubu; hotpatch süreci: `abdullah-aslan` → PR → hızlı release.

## Kapı (8.V)

- [ ] 3–7 gün P0 yok
- [ ] Crash-free hedef
- [ ] App Check enforce veya bilinçli erteleme gerekçesi
- [ ] Açık mağaza kararı
