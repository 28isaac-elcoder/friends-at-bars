# Native hybrid + Capacitor deprecation policy

## Product UI (iOS)

| Channel | Role |
|---------|------|
| **Swift app** (`native/ios/BarFest`) | Consumer product — tabs, MKMapView, chat composer, location |
| **Capacitor `ios/App`** | **Deprecated** as the iOS consumer UI. Keep only while migrating TestFlight users; stop pointing Cap `server.url` at the Vercel SPA for production once Swift TestFlight is live |
| **Vercel consumer SPA** | Optional marketing / web fallback — not the phone UI |
| **Vercel admin CMS** (`admin-cms/`) | Editors only |

## CMS vs App Store release policy

| Change type | How it ships |
|-------------|----------------|
| Venue name, pin, radius, active/test | Admin CMS → `catalog_venues` — **no store review** |
| Deals / events / food copy | Admin CMS → `catalog_listings` |
| Switch Search word packs | Admin CMS → `catalog_game_content` |
| Feature flags / content version | `catalog_app_config` |
| New tabs, map UX, keyboard, native bugs, location engine | **TestFlight / App Store** (Swift binary) |
| Live presence, chat, check-ins, ranked | Existing Supabase live tables/RPCs (not CMS catalog) |

Native UI chrome is **not** OTA. Only **content** updates without a store build.

## Android

Deferred Kotlin shell under `native/android/` uses the **same** Supabase APIs. No parallel CMS.

## Migration checklist

1. Run `supabase/catalog_setup.sql` + `catalog_seed.sql`
2. Deploy `admin-cms` to Vercel; create Auth editor user
3. Generate & archive Swift app; TestFlight via `native-ios-workflow` in `codemagic.yaml`
4. Freeze Cap iOS feature work; remove Cap iOS from production TestFlight
5. Document support path: content issues → CMS; crashes/UX → native release

See also [CATALOG_CMS.md](./CATALOG_CMS.md) and [native/ios/BarFest/README.md](../native/ios/BarFest/README.md).
