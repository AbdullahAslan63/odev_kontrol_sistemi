# Faz 3 — Firebase Ops Deploy Runbook

Proje: `eduly-server`. Bu adımlar Console + CLI gerektirir; kod tarafı hazır.

## Console (manuel)

1. [Authentication](https://console.firebase.google.com/project/eduly-server/authentication) → Email/Password **Enable**
2. Aynı ekran → Phone **Enable**
3. Android app: paket `com.eduly.app` → `google-services.json`
4. Project settings → Android SHA-1 / SHA-256 (debug + upload keystore)
5. iOS app: bundle `com.eduly.mobile` → `GoogleService-Info.plist` + APNs Authentication Key (Phone Auth + FCM)
6. Admin seed: [ADMIN_SEED.md](ADMIN_SEED.md)

## Deploy sırası (repo kökü)

```bash
# 0) Functions derle
cd functions && npm ci && npm run build && cd ..

# 1) Rules + indexes
firebase deploy --only firestore:rules,firestore:indexes --project eduly-server

# 2) Functions
firebase deploy --only functions --project eduly-server

# 3) Hosting (önce web build)
cd web-panel && flutter pub get && flutter build web --release && cd ..
firebase deploy --only hosting --project eduly-server
```

## Kapı (3.V)

- [ ] `https://eduly-server.web.app` + `/privacy.html` `/terms.html` `/support.html` → 200
- [ ] Admin panel login (`role=admin`)
- [ ] `sendBroadcast` admin OK / non-admin denied
- [ ] Öğretmen e-posta + veli OTP en az bir kez
- [ ] `getTeacherAuthPreview` yalnızca `{exists, isTeacher}` döner (isim yok)

## Deploy notu (CI / ajan)

Bu ortamdan `firebase deploy --only functions` üretim etkilediği için onay gerektirir.
Yetkili hesapla repo kökünden [OPS_DEPLOY.md](OPS_DEPLOY.md) sırasını çalıştırın.
Rules deploy denemesi IAM 403 verdiyse hesaba `roles/serviceusage.serviceUsageConsumer` (veya Editor) verin.
