import { CAMPUS_AREAS } from "@/data/venues";

/**
 * Deals & events configuration for Bar Fest.
 *
 * — Activities carousel: first three entries in `ACTIVITIES_CAROUSEL_DEALS` only.
 * — Deals & Events tab: weekly rows (Sun–Sat) by campus area, plus one-off specials.
 *
 * Scheduling fields (use one or combine):
 * - `daysOfWeek`: recurring weekly (0 = Sunday … 6 = Saturday)
 * - `dates`: specific calendar nights, e.g. St. Patrick's Day (`yyyy-MM-dd`)
 * - `specialLabel`: badge for one-off holidays / promotions (pair with `dates`)
 *
 * Omit `daysOfWeek` and `dates` on carousel deals so they show every night on Activities.
 */

export interface BarDeal {
  deal: string;
  time: string;
  conditions: string;
  barName: string;
}

export interface BarEvent {
  title: string;
  time: string;
  description: string;
  conditions: string;
  barName: string;
}

interface ScheduleFields {
  /** Campus area — must match `CAMPUS_AREAS` / venue `area` in `venues.ts` */
  area: string;
  /** Recurring weekday(s), 0 = Sunday … 6 = Saturday */
  daysOfWeek?: number[];
  /** Specific calendar date(s), local yyyy-MM-dd */
  dates?: string[];
  /** Shown as a badge for one-off specials (e.g. "St. Patrick's Day") */
  specialLabel?: string;
}

export type ScheduledDeal = BarDeal & ScheduleFields;
export type ScheduledEvent = BarEvent & ScheduleFields;

/** Shown on Activities only — rotating carousel (max 3). */
export const ACTIVITIES_CAROUSEL_DEALS: BarDeal[] = [
  {
    deal: "Bar Deal 1",
    time: "12pm-5pm",
    conditions: "placeholder condition",
    barName: "placeholder bar",
  },
  {
    deal: "Bar Deal 2",
    time: "12pm-5pm",
    conditions: "placeholder condition",
    barName: "placeholder bar",
  },
  {
    deal: "Bar Deal 3",
    time: "12pm-5pm",
    conditions: "placeholder condition",
    barName: "placeholder bar",
  },
];

export const WEEKDAY_LABELS = [
  "Sunday",
  "Monday",
  "Tuesday",
  "Wednesday",
  "Thursday",
  "Friday",
  "Saturday",
] as const;

export type WeekdayIndex = 0 | 1 | 2 | 3 | 4 | 5 | 6;

function buildWeeklyPlaceholders(): {
  deals: ScheduledDeal[];
  events: ScheduledEvent[];
} {
  const deals: ScheduledDeal[] = [];
  const events: ScheduledEvent[] = [];

  for (const area of CAMPUS_AREAS) {
    for (let day = 0; day <= 6; day++) {
      const dayName = WEEKDAY_LABELS[day as WeekdayIndex];
      for (let n = 1; n <= 2; n++) {
        deals.push({
          deal: `${dayName} Deal ${n}`,
          time: "12pm-5pm",
          conditions: "placeholder condition",
          barName: "placeholder bar",
          area,
          daysOfWeek: [day],
        });
        events.push({
          title: `${dayName} Event ${n}`,
          time: "8pm-11pm",
          description: "Placeholder event description",
          conditions: "placeholder condition",
          barName: "placeholder bar",
          area,
          daysOfWeek: [day],
        });
      }
    }
  }

  return { deals, events };
}

const weeklyPlaceholders = buildWeeklyPlaceholders();

/** One-off / holiday examples — appear on the weekday that date falls on, with a badge. */
export const SPECIAL_DEALS: ScheduledDeal[] = [
  {
    deal: "$3 green beers",
    time: "4pm-close",
    conditions: "21+",
    barName: "Out-R-Inn",
    area: "North Campus",
    dates: ["2026-03-17"],
    specialLabel: "St. Patrick's Day",
  },
  {
    deal: "St. Paddy's shot special",
    time: "6pm-10pm",
    conditions: "while supplies last",
    barName: "Horseshoe",
    area: "North Campus",
    dates: ["2026-03-17"],
    specialLabel: "St. Patrick's Day",
  },
];

export const SPECIAL_EVENTS: ScheduledEvent[] = [
  {
    title: "St. Patrick's Live DJ",
    time: "9pm-1am",
    description: "Green-themed party night",
    conditions: "cover may apply",
    barName: "Out-R-Inn",
    area: "North Campus",
    dates: ["2026-03-17"],
    specialLabel: "St. Patrick's Day",
  },
  {
    title: "Holiday Trivia",
    time: "7pm-9pm",
    description: "St. Patrick's themed trivia",
    conditions: "teams of up to 4",
    barName: "Ethyl & Tank",
    area: "South Campus",
    dates: ["2026-03-17"],
    specialLabel: "St. Patrick's Day",
  },
];

export const WEEKLY_DEALS: ScheduledDeal[] = [
  ...weeklyPlaceholders.deals,
  ...SPECIAL_DEALS,
];

export const WEEKLY_EVENTS: ScheduledEvent[] = [
  ...weeklyPlaceholders.events,
  ...SPECIAL_EVENTS,
];

function entryMatchesWeekday(
  entry: ScheduleFields,
  weekday: WeekdayIndex
): boolean {
  if (entry.daysOfWeek?.includes(weekday)) return true;
  if (entry.dates?.length) {
    return entry.dates.some(
      (d) => new Date(`${d}T12:00:00`).getDay() === weekday
    );
  }
  return false;
}

export type DealListItem = BarDeal & {
  specialLabel?: string;
  specialDates?: string[];
};

export type EventListItem = BarEvent & {
  specialLabel?: string;
  specialDates?: string[];
};

function toDealListItem(entry: ScheduledDeal): DealListItem {
  return {
    deal: entry.deal,
    time: entry.time,
    conditions: entry.conditions,
    barName: entry.barName,
    specialLabel: entry.specialLabel,
    specialDates: entry.dates,
  };
}

function toEventListItem(entry: ScheduledEvent): EventListItem {
  return {
    title: entry.title,
    time: entry.time,
    description: entry.description,
    conditions: entry.conditions,
    barName: entry.barName,
    specialLabel: entry.specialLabel,
    specialDates: entry.dates,
  };
}

/** Deals for one area + weekday (recurring + specials that fall on that weekday). */
export function getDealsForAreaWeekday(
  area: string,
  weekday: WeekdayIndex
): DealListItem[] {
  return WEEKLY_DEALS.filter(
    (entry) => entry.area === area && entryMatchesWeekday(entry, weekday)
  ).map(toDealListItem);
}

/** Events for one area + weekday. */
export function getEventsForAreaWeekday(
  area: string,
  weekday: WeekdayIndex
): EventListItem[] {
  return WEEKLY_EVENTS.filter(
    (entry) => entry.area === area && entryMatchesWeekday(entry, weekday)
  ).map(toEventListItem);
}

export function countItemsForArea(area: string): number {
  let n = 0;
  for (let day = 0; day <= 6; day++) {
    n += getDealsForAreaWeekday(area, day as WeekdayIndex).length;
    n += getEventsForAreaWeekday(area, day as WeekdayIndex).length;
  }
  return n;
}

function carouselEntryMatchesDate(_entry: BarDeal, _date: string): boolean {
  return true;
}

/** Activities carousel — always the three placeholder deals (unchanged behavior). */
export function getActivitiesCarouselDeals(_date: string): BarDeal[] {
  return ACTIVITIES_CAROUSEL_DEALS.filter((entry) =>
    carouselEntryMatchesDate(entry, _date)
  );
}
