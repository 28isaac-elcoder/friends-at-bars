# Native SwiftUI Bar Fest (iOS)

Replaces the Capacitor WebView product UI on iPhone. Catalog (venues / deals / games) comes from Supabase; live check-ins, chat, and `live_locations` reuse existing RPCs/tables.

## Open in Xcode

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).
2. Set `SUPABASE_URL` / `SUPABASE_ANON_KEY` in `project.yml` (or Xcode build settings).
3. From this folder:

```bash
cd native/ios/BarFest
xcodegen generate
open BarFest.xcodeproj
```

4. Set your Development Team, run on a device/simulator.

### Location

`BarFest/Location/` is the absorbed `BarFestNativeLiveLocation` CoreLocation engine (venue radius 100m, heartbeat upserts to `live_locations`). Chat posting still requires a fresh `live_locations` row for the anonymous Keychain user id.

## Version / build numbers

Edit in [`project.yml`](project.yml) under `targets.BarFest.settings.base`:

| Key | Meaning |
|-----|---------|
| `MARKETING_VERSION` | User-facing version (e.g. `1.0.0`) |
| `CURRENT_PROJECT_VERSION` | Build number Apple requires to increase each upload |

`Info.plist` reads `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)`. Same pattern as Cap `ios/App/App.xcodeproj` (`CURRENT_PROJECT_VERSION` / `MARKETING_VERSION` in the pbxproj).

## TestFlight (Codemagic)

See root `codemagic.yaml` workflow `native-ios-workflow`:

- Project: `native/ios/BarFest/BarFest.xcodeproj`
- Scheme: `BarFest`
- Bundle id: `com.barfest.app` (same as Capacitor during beta, or change while dual-shipping)

Generate the Xcode project in CI before archive:

```bash
cd native/ios/BarFest && xcodegen generate
```

## Tabs

| Tab | Source |
|-----|--------|
| Activities | `live_locations` counts + `checkins` |
| Deals | `catalog_listings` |
| Chat | `chat_posts` + RPCs + native composer (16pt+) |
| Map | `MKMapView` / SwiftUI `Map` + `catalog_venues` |
| Games | Ride the Bus / Switch Search (words from `catalog_game_content`) |

## Content updates without App Store

Edit via Vercel admin CMS → Supabase. Pull-to-refresh in app.
