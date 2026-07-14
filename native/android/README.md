# Native Android (Kotlin) — Phase 4

Scaffold only: same Supabase catalog / live APIs as iOS. **No second CMS.**

## Layout

```
native/android/
  README.md
  app/src/main/java/com/barfest/app/
    MainActivity.kt   # Compose tab shell
    CatalogApi.kt     # REST reader for catalog_venues / listings
```

## Next steps (when prioritizing Android)

1. Create a Gradle Android Studio project (Application ID `com.barfest.app`) and copy these sources under `app/src/main/java`.
2. Add MapLibre Native or Google Maps; pins from `CatalogApi.venues()`.
3. Port venue live-location engine (foreground + background) mirroring iOS `VenueLiveLocationEngine`.
4. Wire Chat / Deals / Activities / Games screens the same as Swift (RPCs already platform-agnostic).

## Content

Editors only use the Vercel admin CMS → Supabase. Android and iOS both pull JSON at runtime.
