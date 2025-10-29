import { useState, useEffect } from "react";
import { Button } from "@/components/ui/Button";
import { Select } from "@/components/ui/Select";
import { Label } from "@/components/ui/Label";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/Card";
import { CheckInFormData } from "@/types/checkin";
import { OHIO_STATE_VENUES, CAMPUS_AREAS } from "@/data/venues";
import {
  generateStartTimeOptions,
  generateDurationOptions,
  calculateEndTime,
  formatTimeDisplay,
} from "@/lib/timeUtils";
import { checkInService } from "@/lib/supabaseClient";
import { addUserCheckInId } from "@/lib/userCheckIns";

interface CheckInFormProps {
  onSubmit: (checkIn: CheckInFormData) => void;
  onSuccess?: () => void; // Optional callback after successful Supabase save
}

export default function CheckInForm({ onSubmit, onSuccess }: CheckInFormProps) {
  const [venue, setVenue] = useState("");
  const [startTime, setStartTime] = useState("");
  const [durationMinutes, setDurationMinutes] = useState("");
  const [endTime, setEndTime] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState("");

  const startTimeOptions = generateStartTimeOptions();
  const durationOptions = generateDurationOptions(startTime);

  // Calculate end time whenever start time or duration changes
  useEffect(() => {
    if (startTime && durationMinutes) {
      const calculatedEndTime = calculateEndTime(
        startTime,
        parseInt(durationMinutes)
      );
      setEndTime(calculatedEndTime);
    } else {
      setEndTime("");
    }
  }, [startTime, durationMinutes]);

  // Reset duration when start time changes
  useEffect(() => {
    setDurationMinutes("");
    setEndTime("");
  }, [startTime]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitError("");

    if (!venue || !startTime || !durationMinutes) {
      setSubmitError("Please fill in all fields");
      return;
    }

    setIsSubmitting(true);

    try {
      // Calculate end time
      const calculatedEndTime = calculateEndTime(
        startTime,
        parseInt(durationMinutes)
      );

      // Save to Supabase
      const result = await checkInService.insertCheckIn({
        venue,
        start_time: startTime,
        end_time: calculatedEndTime,
      });

      // Track this check-in as created by this user
      if (result && result.id) {
        addUserCheckInId(result.id);
      }

      // Also call the local onSubmit for immediate UI update
      onSubmit({
        venue,
        startTime,
        durationMinutes: parseInt(durationMinutes),
      });

      // Call success callback to reload data
      if (onSuccess) {
        onSuccess();
      }

      // Reset form
      setVenue("");
      setStartTime("");
      setDurationMinutes("");
      setEndTime("");
    } catch (error) {
      console.error("Error saving check-in:", error);
      setSubmitError("Failed to save check-in. Please try again.");
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Card className="mx-auto w-full max-w-md">
      <CardHeader>
        <CardTitle>Plan Your Night</CardTitle>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="venue">Venue</Label>
            <Select
              id="venue"
              value={venue}
              onChange={(e) => setVenue(e.target.value)}
              required
            >
              <option value="">Select a venue...</option>
              {CAMPUS_AREAS.map((area) => (
                <optgroup key={area} label={area}>
                  {OHIO_STATE_VENUES.filter((venue) => venue.area === area).map(
                    (venueOption) => (
                      <option key={venueOption.name} value={venueOption.name}>
                        {venueOption.name}
                      </option>
                    )
                  )}
                </optgroup>
              ))}
            </Select>
          </div>

          <div className="space-y-2">
            <Label htmlFor="startTime">Start Time</Label>
            <Select
              id="startTime"
              value={startTime}
              onChange={(e) => setStartTime(e.target.value)}
              required
            >
              <option value="">Select start time...</option>
              {startTimeOptions.map((time) => (
                <option key={time} value={time}>
                  {formatTimeDisplay(time)}
                </option>
              ))}
            </Select>
          </div>

          <div className="space-y-2">
            <Label htmlFor="duration">Duration</Label>
            <Select
              id="duration"
              value={durationMinutes}
              onChange={(e) => setDurationMinutes(e.target.value)}
              disabled={!startTime}
              required
            >
              <option value="">
                {startTime
                  ? "Select duration..."
                  : "Select start time first..."}
              </option>
              {durationOptions.map((option) => (
                <option key={option.value} value={option.value}>
                  {option.label}
                  {option.endTime && ` - ${formatTimeDisplay(option.endTime)}`}
                </option>
              ))}
            </Select>
          </div>

          {endTime && (
            <div className="rounded-lg bg-muted p-3">
              <p className="text-sm text-muted-foreground">
                <strong>End Time:</strong> {formatTimeDisplay(endTime)}
              </p>
            </div>
          )}

          {submitError && (
            <div className="rounded-lg border border-red-200 bg-red-50 p-3">
              <p className="text-sm text-red-600">{submitError}</p>
            </div>
          )}

          <Button type="submit" className="w-full" disabled={isSubmitting}>
            {isSubmitting ? "Saving..." : "Submit Check-in"}
          </Button>
        </form>
      </CardContent>
    </Card>
  );
}
