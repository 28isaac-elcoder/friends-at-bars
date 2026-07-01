import { useCallback, useEffect, useState } from "react";
import { Capacitor } from "@capacitor/core";
import { promptForOsLocationPermission } from "@/lib/ensureLiveLocationWhenPermitted";
import {
  locationService,
  subscribeNativeAppResume,
} from "@/lib/locationService";
import type { RankedGateOverlay } from "./RankedGate";
import {
  fetchLeaderboardToday,
  hasPlayedRankedToday,
  resolveVenueForRanked,
} from "./rankedService";
import type { RankedGameType, RankedLeaderboardEntry } from "./types";

export type RankedScreen = "none" | "leaderboard" | "checking";

type UseRankedEntryOptions = {
  gameType: RankedGameType;
  onStartPlay: (venueName: string) => void;
};

export function useRankedEntry({ gameType, onStartPlay }: UseRankedEntryOptions) {
  const userId = locationService.getUserId();
  const [screen, setScreen] = useState<RankedScreen>("none");
  const [gateOverlay, setGateOverlay] = useState<RankedGateOverlay>("none");
  const [leaderboardEntries, setLeaderboardEntries] = useState<
    RankedLeaderboardEntry[]
  >([]);
  const [leaderboardLoading, setLeaderboardLoading] = useState(false);
  const [locationBusy, setLocationBusy] = useState(false);
  const [showWebLocationHelp, setShowWebLocationHelp] = useState(false);
  const [nativeSettingsError, setNativeSettingsError] = useState<string | null>(
    null
  );
  const [rankedVenueName, setRankedVenueName] = useState<string | null>(null);

  const openLeaderboard = useCallback(async () => {
    setLeaderboardLoading(true);
    setScreen("leaderboard");
    const entries = await fetchLeaderboardToday(gameType);
    setLeaderboardEntries(entries);
    setLeaderboardLoading(false);
  }, [gameType]);

  const tryStartAtVenue = useCallback(async () => {
    const venue = await resolveVenueForRanked();
    if (!venue) {
      setGateOverlay("not-at-bar");
      return;
    }
    setRankedVenueName(venue);
    setGateOverlay("none");
    onStartPlay(venue);
  }, [onStartPlay]);

  const handleRankedClick = useCallback(async () => {
    setScreen("checking");
    const played = await hasPlayedRankedToday(gameType, userId);
    if (played) {
      await openLeaderboard();
      return;
    }

    const granted = await locationService.checkPermissions();
    if (!granted) {
      setScreen("none");
      setGateOverlay("permission");
      return;
    }

    setScreen("none");
    await tryStartAtVenue();
  }, [gameType, userId, openLeaderboard, tryStartAtVenue]);

  const handleAllowLocation = useCallback(async () => {
    setLocationBusy(true);
    setShowWebLocationHelp(false);
    setNativeSettingsError(null);
    try {
      const { granted, settingsError } = await promptForOsLocationPermission();
      if (settingsError) {
        setNativeSettingsError(settingsError);
        return;
      }
      if (!granted) {
        if (!Capacitor.isNativePlatform()) {
          setShowWebLocationHelp(true);
        }
        return;
      }
      setGateOverlay("none");
      await tryStartAtVenue();
    } finally {
      setLocationBusy(false);
    }
  }, [tryStartAtVenue]);

  useEffect(() => {
    if (gateOverlay !== "permission") return;

    const recheckAfterSettings = async () => {
      const granted = await locationService.checkPermissions();
      if (!granted) return;
      setShowWebLocationHelp(false);
      setNativeSettingsError(null);
      setGateOverlay("none");
      await tryStartAtVenue();
    };

    window.addEventListener("focus", recheckAfterSettings);
    const unsubResume = subscribeNativeAppResume(() => {
      void recheckAfterSettings();
    });
    return () => {
      window.removeEventListener("focus", recheckAfterSettings);
      unsubResume();
    };
  }, [gateOverlay, tryStartAtVenue]);

  const closeGate = useCallback(() => {
    setGateOverlay("none");
    setShowWebLocationHelp(false);
    setNativeSettingsError(null);
  }, []);

  const closeLeaderboard = useCallback(() => {
    setScreen("none");
  }, []);

  const showLeaderboardAfterSubmit = useCallback(async () => {
    await openLeaderboard();
  }, [openLeaderboard]);

  return {
    userId,
    screen,
    gateOverlay,
    leaderboardEntries,
    leaderboardLoading,
    locationBusy,
    showWebLocationHelp,
    nativeSettingsError,
    rankedVenueName,
    handleRankedClick,
    handleAllowLocation,
    closeGate,
    closeLeaderboard,
    showLeaderboardAfterSubmit,
    isChecking: screen === "checking",
  };
}
