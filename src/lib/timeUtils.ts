// Time utility functions for check-in form

export const generateStartTimeOptions = (): string[] => {
  const options: string[] = [];
  const now = new Date();
  const currentHour = now.getHours();
  const currentMinute = now.getMinutes();

  // Default start time is 5:00 PM (17:00) unless it's already past 5 PM today
  let startHour = 17; // 5 PM
  let startMinute = 0;

  // If it's past 5 PM, start from the next half hour
  if (currentHour > 17 || (currentHour === 17 && currentMinute > 0)) {
    startHour = currentHour;
    startMinute = currentMinute <= 30 ? 30 : 0;
    if (currentMinute > 30) {
      startHour += 1;
    }
  }

  // Generate times from start time through 2:00 AM next day
  let hour = startHour;
  let minute = startMinute;

  while (hour < 26) {
    // 2 AM next day = 26 hours from midnight
    const displayHour = hour > 23 ? hour - 24 : hour;
    const timeString = `${hour.toString().padStart(2, "0")}:${minute.toString().padStart(2, "0")}`;
    options.push(timeString);

    // Increment by 30 minutes
    minute += 30;
    if (minute >= 60) {
      minute = 0;
      hour += 1;
    }
  }

  return options;
};

export const generateDurationOptions = (
  startTime?: string
): { value: string; label: string; endTime?: string }[] => {
  const options: { value: string; label: string; endTime?: string }[] = [];

  // 15-minute intervals up to 1 hour
  for (let minutes = 15; minutes <= 60; minutes += 15) {
    const hours = Math.floor(minutes / 60);
    const remainingMinutes = minutes % 60;

    let label = "";
    if (hours > 0) {
      label = `${hours} hour${hours > 1 ? "s" : ""}`;
      if (remainingMinutes > 0) {
        label += ` ${remainingMinutes} min`;
      }
    } else {
      label = `${minutes} min`;
    }

    // Calculate end time if start time is provided
    let endTime = undefined;
    if (startTime) {
      endTime = calculateEndTime(startTime, minutes);
    }

    options.push({
      value: minutes.toString(),
      label: label,
      endTime: endTime,
    });
  }

  // Then 1.5 hours, 2 hours, 2.5 hours, etc. up to 6 hours
  for (let hours = 1.5; hours <= 6; hours += 0.5) {
    const totalMinutes = Math.round(hours * 60);
    const wholeHours = Math.floor(hours);
    const isHalfHour = hours % 1 === 0.5;

    let label = "";
    if (isHalfHour) {
      label = `${wholeHours}.5 hours`;
    } else {
      label = `${wholeHours} hour${wholeHours > 1 ? "s" : ""}`;
    }

    // Calculate end time if start time is provided
    let endTime = undefined;
    if (startTime) {
      endTime = calculateEndTime(startTime, totalMinutes);
    }

    options.push({
      value: totalMinutes.toString(),
      label: label,
      endTime: endTime,
    });
  }

  return options;
};

export const calculateEndTime = (
  startTime: string,
  durationMinutes: number
): string => {
  const [startHour, startMinute] = startTime.split(":").map(Number);

  // Convert start time to total minutes from midnight
  let totalMinutes = startHour * 60 + startMinute;

  // Add duration
  totalMinutes += durationMinutes;

  // Handle day overflow (next day)
  const endHour = Math.floor(totalMinutes / 60) % 24;
  const endMinute = totalMinutes % 60;

  return `${endHour.toString().padStart(2, "0")}:${endMinute.toString().padStart(2, "0")}`;
};

export const formatTimeDisplay = (timeString: string): string => {
  const [hours, minutes] = timeString.split(":").map(Number);
  const hour = hours % 12 || 12;
  const ampm = hours >= 12 ? "PM" : "AM";
  return `${hour}:${minutes.toString().padStart(2, "0")} ${ampm}`;
};

// Extract time from Supabase timestamptz format
// Handles both full timestamps ("2024-01-01T10:30:00+00:00") and time strings ("10:30")
export const extractTimeFromTimestamp = (timestamp: string): string => {
  // If it's just a time string (HH:MM), return it as is
  if (timestamp.match(/^\d{2}:\d{2}$/)) {
    return timestamp;
  }

  // If it's a full timestamp, extract the time portion
  // Format: "2024-01-01T10:30:00+00:00" or "2024-01-01 10:30:00+00:00"
  const match = timestamp.match(/(\d{2}):(\d{2})/);
  if (match) {
    return `${match[1]}:${match[2]}`;
  }

  // Fallback: try parsing as Date and extracting time
  const date = new Date(timestamp);
  if (!isNaN(date.getTime())) {
    const hours = date.getHours().toString().padStart(2, "0");
    const minutes = date.getMinutes().toString().padStart(2, "0");
    return `${hours}:${minutes}`;
  }

  return timestamp; // Return original if we can't parse it
};

// Calculate time difference in minutes (handles overnight)
export const calculateTimeDifference = (
  startTime: string,
  endTime: string
): number => {
  const start = extractTimeFromTimestamp(startTime);
  const end = extractTimeFromTimestamp(endTime);

  const [startHours, startMinutes] = start.split(":").map(Number);
  const [endHours, endMinutes] = end.split(":").map(Number);

  let startTotalMinutes = startHours * 60 + startMinutes;
  let endTotalMinutes = endHours * 60 + endMinutes;

  // Handle overnight (end time is next day)
  if (endTotalMinutes < startTotalMinutes) {
    endTotalMinutes += 24 * 60; // Add 24 hours
  }

  return endTotalMinutes - startTotalMinutes;
};
