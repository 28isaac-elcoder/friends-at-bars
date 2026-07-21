# Live location in the native Swift app (Phase 3)

The Capacitor plugin sources under `packages/capacitor-barfest-native-live-location/ios/...` are **copied into** `native/ios/BarFest/BarFest/Location/`:

- `VenueLiveLocationEngine.swift` — CoreLocation, 100m haversine, heartbeat upserts
- `SupabaseLiveLocationAPI.swift` — PostgREST `live_locations` upsert / deactivate
- `VenueModels.swift`

`LocationBridge` in `BarFestApp.swift` configures the engine with catalog venues + Keychain `AnonymousIdentity.userId()`.

## Timing (AppConfig)

| Constant | Value | Role |
|----------|-------|------|
| `liveLocationHeartbeatMs` | **15 min** | Re-upsert while staying at the same bar |
| `liveLocationCountMaxAgeSeconds` | **18 min** | Headcount filter on `last_updated` |
| `liveLocationChatFreshnessSeconds` | **18 min** | Matches `create_chat_post` RPC window |
| Local GPS poll | **10 s** | Enter/leave detection; leave deactivates immediately |

Live UI (Activities / Map / Chat location features) requires **Location Always** — When In Use alone does not unlock attendance.

## Chat / ranked gates

Server RPCs (e.g. `create_chat_post`) require a **fresh** `live_locations` row:

- `user_id` = anonymous identity
- `venue_name` matches
- `is_active` + `last_updated` within **18 minutes**

Run [`supabase/chat_live_location_freshness_18m.sql`](../../../supabase/chat_live_location_freshness_18m.sql) in Supabase if the live DB still uses the old 10‑minute window.

The Swift chat composer only enables send when `AppModel.lastVenueName` is set from the engine. Sending still calls `create_chat_post` with that venue name so anti-spoof checks pass.

**Ranked / Games** that gate on being at a venue should use the same `lastVenueName` (or `VenueLiveLocationEngine.shared.currentState().lastVenue`) — same data the web app got from the Capacitor plugin.

## Activities headcounts

Pull-to-refresh on Activities calls `AppModel.refreshHeadcounts` (catalog + `live_locations` counts) and writes diagnostics to the in-app Log screen (`category: location`).

## Permissions

Info.plist includes Always + When In Use usage strings and `UIBackgroundModes: location`.
