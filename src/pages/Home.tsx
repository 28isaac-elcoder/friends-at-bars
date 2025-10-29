import { useState, useEffect } from "react";
import CheckInForm from "@/components/CheckInForm";
import CheckInList from "@/components/CheckInList";
import MapView from "@/components/MapView";
import ConflictConfirmationDialog from "@/components/ConflictConfirmationDialog";
import { CheckIn, CheckInFormData, SupabaseCheckIn } from "@/types/checkin";
import {
  calculateEndTime,
  extractTimeFromTimestamp,
  calculateTimeDifference,
} from "@/lib/timeUtils";
import {
  findConflictingCheckIns,
  calculateAdjustments,
  adjustCheckInTimes,
} from "@/lib/conflictUtils";
import { checkInService } from "@/lib/supabaseClient";
import { OHIO_STATE_VENUES } from "@/data/venues";
import { getUserCheckInIds } from "@/lib/userCheckIns";

export default function Home() {
  const [checkIns, setCheckIns] = useState<CheckIn[]>([]); // All check-ins (for map)
  const [userCheckIns, setUserCheckIns] = useState<CheckIn[]>([]); // User's own check-ins (for list)
  const [pendingCheckIn, setPendingCheckIn] = useState<CheckIn | null>(null);
  const [conflictingCheckIns, setConflictingCheckIns] = useState<CheckIn[]>([]);
  const [adjustments, setAdjustments] = useState<
    { original: CheckIn; adjusted: CheckIn }[]
  >([]);
  const [showConflictDialog, setShowConflictDialog] = useState(false);

  // Function to load check-ins from Supabase
  const loadCheckIns = async () => {
    try {
      const supabaseData = await checkInService.fetchCheckIns();

      // Convert Supabase check-ins to local CheckIn format
      const convertedCheckIns: CheckIn[] = supabaseData.map(
        (supabaseCheckIn: SupabaseCheckIn) => {
          // Extract time strings from timestamps (handles both timestamp and HH:MM formats)
          const startTime = extractTimeFromTimestamp(
            supabaseCheckIn.start_time
          );
          const endTime = extractTimeFromTimestamp(supabaseCheckIn.end_time);

          // Calculate duration properly (handles overnight)
          const durationMinutes = calculateTimeDifference(startTime, endTime);

          const venue = OHIO_STATE_VENUES.find(
            (v) => v.name === supabaseCheckIn.venue
          );

          return {
            id: supabaseCheckIn.id,
            venue: supabaseCheckIn.venue,
            venueArea: venue?.area,
            startTime: startTime,
            endTime: endTime,
            durationMinutes,
            timestamp: new Date(supabaseCheckIn.created_at),
          };
        }
      );

      // Get user's check-in IDs from localStorage
      const userCheckInIds = getUserCheckInIds();

      // Set all check-ins (for map)
      setCheckIns(convertedCheckIns);

      // Filter to only user's check-ins (for list)
      const userOwnCheckIns = convertedCheckIns.filter((checkIn) =>
        userCheckInIds.includes(checkIn.id)
      );
      setUserCheckIns(userOwnCheckIns);
    } catch (error) {
      console.error("Error loading check-ins from Supabase:", error);
    }
  };

  // Fetch check-ins from Supabase on page load
  useEffect(() => {
    loadCheckIns();
  }, []);

  const handleCheckInSubmit = (newCheckInData: CheckInFormData) => {
    const endTime = calculateEndTime(
      newCheckInData.startTime,
      newCheckInData.durationMinutes
    );
    const newCheckIn: CheckIn = {
      ...newCheckInData,
      endTime,
      id: Date.now().toString(),
      timestamp: new Date(),
    };

    // Check for conflicts
    const conflicts = findConflictingCheckIns(newCheckIn, checkIns);

    if (conflicts.length > 0) {
      // Show confirmation dialog
      const calculatedAdjustments = calculateAdjustments(newCheckIn, conflicts);
      setPendingCheckIn(newCheckIn);
      setConflictingCheckIns(conflicts);
      setAdjustments(calculatedAdjustments);
      setShowConflictDialog(true);
    } else {
      // No conflicts, add directly
      setCheckIns((prev) => [newCheckIn, ...prev]);
    }
  };

  const handleConfirmConflict = () => {
    if (!pendingCheckIn) return;

    // Apply adjustments to conflicting check-ins
    const { adjustedCheckIns } = adjustCheckInTimes(
      pendingCheckIn,
      conflictingCheckIns
    );

    // Update check-ins: remove conflicting ones and add adjusted ones + new check-in
    setCheckIns((prev) => {
      const filteredCheckIns = prev.filter(
        (checkIn) =>
          !conflictingCheckIns.some((conflict) => conflict.id === checkIn.id)
      );
      return [pendingCheckIn, ...adjustedCheckIns, ...filteredCheckIns];
    });

    // Reset state
    setShowConflictDialog(false);
    setPendingCheckIn(null);
    setConflictingCheckIns([]);
    setAdjustments([]);
  };

  const handleCancelConflict = () => {
    // Reset state without making changes
    setShowConflictDialog(false);
    setPendingCheckIn(null);
    setConflictingCheckIns([]);
    setAdjustments([]);
  };

  return (
    <div className="min-h-screen bg-background">
      {/* Map Section */}
      <div className="mb-8">
        <MapView checkIns={checkIns} />
      </div>

      {/* Check-in Form */}
      <div className="mb-8">
        <CheckInForm onSubmit={handleCheckInSubmit} onSuccess={loadCheckIns} />
      </div>

      {/* Check-in List - Only user's own check-ins */}
      <div className="mb-8">
        <CheckInList checkIns={userCheckIns} />
      </div>

      {/* Conflict Confirmation Dialog */}
      {showConflictDialog && pendingCheckIn && (
        <ConflictConfirmationDialog
          newCheckIn={pendingCheckIn}
          conflictingCheckIns={conflictingCheckIns}
          adjustments={adjustments}
          onConfirm={handleConfirmConflict}
          onCancel={handleCancelConflict}
        />
      )}
    </div>
  );
}
