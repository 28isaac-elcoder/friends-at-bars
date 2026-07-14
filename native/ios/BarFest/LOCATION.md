# Live location in the native Swift app (Phase 3)

The Capacitor plugin sources under `packages/capacitor-barfest-native-live-location/ios/...` are **copied into** `native/ios/BarFest/BarFest/Location/`:

- `VenueLiveLocationEngine.swift` — CoreLocation, 100m haversine, heartbeat upserts
- `SupabaseLiveLocationAPI.swift` — PostgREST `live_locations` upsert / deactivate
- `VenueModels.swift`

`LocationBridge` in `BarFestApp.swift` configures the engine with catalog venues + Keychain `AnonymousIdentity.userId()`.

## Chat / ranked gates

Server RPCs (e.g. `create_chat_post`) require a **fresh** `live_locations` row:

- `user_id` = anonymous identity
- `venue_name` matches
- `is_active` + `last_updated` within the RPC window (chat: 10 minutes)

The Swift chat composer only enables send when `AppModel.lastVenueName` is set from the engine. Sending still calls `create_chat_post` with that venue name so anti-spoof checks pass.

**Ranked / Games** that gate on being at a venue should use the same `lastVenueName` (or `VenueLiveLocationEngine.shared.currentState().lastVenue`) — same data the web app got from the Capacitor plugin.

## Permissions

Info.plist includes Always + When In Use usage strings and `UIBackgroundModes: location`.
