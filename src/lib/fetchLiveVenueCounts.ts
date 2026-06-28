import type { VenueCounts } from "@/types/checkin";
import { liveLocationService, logSupabaseNetworkOnce } from "@/lib/supabaseClient";
import { testDataService } from "@/lib/testDataService";
import { liveLocLog } from "@/lib/liveLocationDebug";
import { isVenueVisible } from "@/data/venues";

/** Drop counts for venues hidden in this build (e.g. Test Locations in production). */
function filterVisibleCounts(counts: VenueCounts): VenueCounts {
  const filtered: VenueCounts = {};
  for (const [venueName, count] of Object.entries(counts)) {
    if (isVenueVisible(venueName)) filtered[venueName] = count;
  }
  return filtered;
}

export async function fetchLiveVenueCountsForDisplay(
  useTestData: boolean
): Promise<VenueCounts> {
  if (useTestData) {
    liveLocLog("fetchLiveVenueCountsForDisplay → mock data", {});
    return filterVisibleCounts(await testDataService.fetchLiveVenueCounts());
  }
  try {
    const counts = await liveLocationService.fetchVenueCounts();
    liveLocLog("fetchLiveVenueCountsForDisplay → Supabase ok", { counts });
    return filterVisibleCounts(counts);
  } catch (err) {
    logSupabaseNetworkOnce(err);
    liveLocLog("fetchLiveVenueCountsForDisplay → Supabase error", {
      message: err instanceof Error ? err.message : String(err),
    });
    return {};
  }
}
