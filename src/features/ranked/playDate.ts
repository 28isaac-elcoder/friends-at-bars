const EASTERN_TZ = "America/New_York";

/** Calendar date for ranked daily reset (YYYY-MM-DD in US Eastern). */
export function getRankedPlayDateEastern(date: Date = new Date()): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: EASTERN_TZ,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(date);
}
