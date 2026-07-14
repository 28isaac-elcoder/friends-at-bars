# Native SwiftUI Bar Fest (iOS)

Replaces the Capacitor WebView product UI on iPhone. Catalog (venues / deals / games) comes from Supabase; live check-ins, chat, and `live_locations` reuse existing RPCs/tables.

## Open in Xcode

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).
2. Set `VITE_SUPABASE_URL` / `VITE_SUPABASE_PUBLISHABLE_KEY` (Codemagic env injects into Info.plist).
3. From this folder:

```bash
cd native/ios/BarFest
xcodegen generate
open BarFest.xcodeproj
```

4. Set your Development Team, run on a device/simulator.

### Location

`BarFest/Location/` is the absorbed `BarFestNativeLiveLocation` CoreLocation engine (venue radius 100m, heartbeat upserts to `live_locations`). Chat posting still requires a fresh `live_locations` row for the anonymous Keychain user id.

## App icon

`BarFest/Assets.xcassets/AppIcon.appiconset` (generated from Cap’s 1024 app icon). Wired via `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` and `CFBundleIconName` in Info.plist.

## Version / build numbers (hardcoded)

Edit **both** places before each TestFlight upload (must stay in sync):

1. [`BarFest/Info.plist`](BarFest/Info.plist) — `CFBundleShortVersionString` / `CFBundleVersion`
2. Root [`codemagic.yaml`](../../../codemagic.yaml) — `native-ios-workflow` vars `NATIVE_MARKETING_VERSION` / `NATIVE_BUILD_NUMBER`

After `xcodegen`, CI runs `git checkout` on Info.plist and re-applies those hardcodes so XcodeGen cannot reset the build to `1`.

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
