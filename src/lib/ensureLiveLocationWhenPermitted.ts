import { Capacitor } from "@capacitor/core";
import { liveLocLog } from "@/lib/liveLocationDebug";
import {
  getLocationTrackingEnabled,
  isNativePlatform,
  locationService,
  openNativeAppLocationSettings,
} from "@/lib/locationService";

export type LiveLocationToggleRef = {
  requestEnable: () => Promise<void>;
  restorePersistedTrackingIfNeeded?: () => Promise<void>;
};

/**
 * When OS location is granted, turn on in-app live tracking (localStorage + native/JS engine)
 * so map pin, Supabase `live_locations`, and Activities live counts stay in sync.
 */
export async function syncLiveLocationWithPermission(
  toggle: LiveLocationToggleRef | null | undefined
): Promise<{ granted: boolean; tracking: boolean }> {
  const granted = await locationService.checkPermissions();
  if (!granted || !toggle) {
    return { granted, tracking: getLocationTrackingEnabled() };
  }

  if (!getLocationTrackingEnabled()) {
    liveLocLog("syncLiveLocationWithPermission → requestEnable");
    await toggle.requestEnable();
  } else {
    await toggle.restorePersistedTrackingIfNeeded?.();
  }

  return {
    granted: true,
    tracking: getLocationTrackingEnabled(),
  };
}

function usesNativeSettingsShortcut(): boolean {
  if (!isNativePlatform) return false;
  const p = Capacitor.getPlatform();
  return p === "ios" || p === "android";
}

/**
 * Request OS location permission: opens app Settings on native iOS/Android when needed,
 * or triggers the browser permission prompt on web.
 */
export async function promptForOsLocationPermission(): Promise<{
  granted: boolean;
  openedSettings: boolean;
  settingsError: string | null;
}> {
  let granted = await locationService.checkPermissions();
  if (granted) {
    return { granted: true, openedSettings: false, settingsError: null };
  }

  if (usesNativeSettingsShortcut()) {
    liveLocLog("promptForOsLocationPermission → open native Settings");
    const settingsResult = await openNativeAppLocationSettings();
    if (!settingsResult.ok) {
      liveLocLog(
        "promptForOsLocationPermission Settings open failed",
        { detail: settingsResult.displayText },
        "warn"
      );
      return {
        granted: false,
        openedSettings: false,
        settingsError:
          settingsResult.displayText ?? "Failed to open Settings",
      };
    }
    granted = await locationService.checkPermissions();
    return {
      granted,
      openedSettings: true,
      settingsError: null,
    };
  }

  granted = await locationService.requestPermissions();
  return {
    granted,
    openedSettings: false,
    settingsError: null,
  };
}

/**
 * User tapped "enable location": open Settings on native if needed, then start live tracking
 * once permission is granted (including after returning from Settings).
 */
export async function promptForLocationAndSyncLive(
  toggle: LiveLocationToggleRef | null | undefined
): Promise<{
  granted: boolean;
  tracking: boolean;
  openedSettings: boolean;
}> {
  let granted = await locationService.checkPermissions();
  if (granted) {
    const synced = await syncLiveLocationWithPermission(toggle);
    return { ...synced, openedSettings: false };
  }

  if (usesNativeSettingsShortcut()) {
    liveLocLog("promptForLocationAndSyncLive → open native Settings");
    const settingsResult = await openNativeAppLocationSettings();
    if (!settingsResult.ok) {
      liveLocLog(
        "promptForLocationAndSyncLive Settings open failed",
        { detail: settingsResult.displayText },
        "warn"
      );
      return {
        granted: false,
        tracking: false,
        openedSettings: false,
      };
    }
    granted = await locationService.checkPermissions();
    if (granted) {
      const synced = await syncLiveLocationWithPermission(toggle);
      return { ...synced, openedSettings: true };
    }
    return { granted: false, tracking: false, openedSettings: true };
  }

  await toggle?.requestEnable();
  granted = await locationService.checkPermissions();
  const tracking = getLocationTrackingEnabled();
  return { granted, tracking, openedSettings: false };
}
