# Android and iOS release checklist

## Shared

- Production Supabase URL and publishable key are injected at build time.
- No service-role, Razorpay secret, FCM server credential or private Storage key is in the app bundle.
- Crash reporting and performance monitoring are configured per environment.
- Auth recovery, phone verification, account deletion and consent screens are tested.
- GPS, camera, photo-library and notification disclosures match actual behavior.
- Payment UI displays server-created order details and never marks success locally.
- Offline/reconnect flows refresh backend state after restart.

## Android

- Replace `com.example.civilconnect` with the approved application ID.
- Configure release signing in CI, never commit keystores.
- Configure FCM `google-services.json` through protected release storage.
- Test Android back behavior, location permission denial, camera/photo flows and Razorpay Checkout.
- Build and install the signed AAB on supported API levels.

## iOS

- Configure the production bundle identifier and signing team in CI.
- Configure APNs/FCM capabilities and provisioning profiles securely.
- Test location and photo permission strings, background behavior and deep links.
- Test Razorpay Checkout on a physical device using provider sandbox credentials.
- Archive and validate the signed IPA through the release pipeline.
