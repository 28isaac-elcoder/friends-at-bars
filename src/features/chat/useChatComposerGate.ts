import { useCallback, useEffect, useState } from "react";
import {
  locationService,
  subscribeNativeAppResume,
} from "@/lib/locationService";
import { useLocationTrackingOutlet } from "@/contexts/locationTrackingContext";
import { promptForOsLocationPermission } from "@/lib/ensureLiveLocationWhenPermitted";

export type ChatComposerGate =
  | "loading"
  | "need-location"
  | "not-at-bar"
  | "ready";

export function useChatComposerGate() {
  const { locationToggleRef, mapUserLocation } = useLocationTrackingOutlet();
  const [gate, setGate] = useState<ChatComposerGate>("loading");
  const [venueName, setVenueName] = useState<string | null>(null);
  const [checking, setChecking] = useState(false);

  const refresh = useCallback(async () => {
    setChecking(true);
    try {
      const permitted = await locationService.checkPermissions();
      if (!permitted) {
        setGate("need-location");
        setVenueName(null);
        return;
      }

      let lat = mapUserLocation?.latitude;
      let lon = mapUserLocation?.longitude;

      // Prefer a fresh GPS read when possible
      const loc = await locationService.getCurrentLocation();
      if (loc) {
        lat = loc.latitude;
        lon = loc.longitude;
      }

      if (lat == null || lon == null) {
        setGate("need-location");
        setVenueName(null);
        return;
      }

      const venue = locationService.getVenueNameIfAtVenue(lat, lon);
      if (!venue) {
        setGate("not-at-bar");
        setVenueName(null);
        return;
      }

      setVenueName(venue);
      setGate("ready");
    } finally {
      setChecking(false);
    }
  }, [mapUserLocation]);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  useEffect(() => {
    return subscribeNativeAppResume(() => {
      void refresh();
    });
  }, [refresh]);

  const requestLocation = useCallback(async () => {
    setChecking(true);
    try {
      await promptForOsLocationPermission();
      await locationToggleRef.current?.requestEnable();
      await refresh();
    } finally {
      setChecking(false);
    }
  }, [locationToggleRef, refresh]);

  return {
    gate,
    venueName,
    checking,
    refresh,
    requestLocation,
  };
}
