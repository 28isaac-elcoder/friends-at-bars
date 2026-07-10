
/**
 * Deals & events from Columbus Bars Deals and Events v3.xlsx
 * Sheet bar names are mapped to canonical venue names in venues.ts.
 */

export type ListingTypeLabel = "Drink Special" | "Food Special" | "Event";

export interface BarListing {
  /** Empty when the sheet has no title — details carry the listing text. */
  title: string;
  time: string;
  details: string;
  barName: string;
  typeLabels: ListingTypeLabel[];
}

interface ScheduleFields {
  area: string;
  daysOfWeek: number[];
  priority?: number;
}

export type ScheduledListing = BarListing & ScheduleFields;
export type ActivitiesCarouselItem = BarListing & { priority: number };

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

export const WEEKLY_LISTINGS: ScheduledListing[] = [
  { title: "Mug Night", time: "8pm–Close", details: "$5 Out-R-Inn Mug ; $4 Mich Ultra or Hoop Tea ; $5 Stella, Mango Cart, Kona, Land Grant", barName: "Out-R-Inn", typeLabels: ["Drink Special"], area: "North Campus", daysOfWeek: [0] },
  { title: "Out-R-Thursday", time: "4pm–Close", details: "$2 Doubles and Well Night", barName: "Out-R-Inn", typeLabels: ["Drink Special"], area: "North Campus", daysOfWeek: [4], priority: 3 },
  { title: "Line Dancing", time: "8pm–Close", details: "", barName: "Horseshoe", typeLabels: ["Event"], area: "North Campus", daysOfWeek: [3] },
  { title: "", time: "9pm–Close", details: "$1 Wells", barName: "Three's", typeLabels: ["Drink Special"], area: "North Campus", daysOfWeek: [2], priority: 5 },
  { title: "Karaoke Wednesdays", time: "8pm–Close", details: "$2 Fireball ; $4 Doubles ; 5 for $20 Nutrl Bucket ; Karaoke (9pm)", barName: "Fourth Street Taproom", typeLabels: ["Drink Special", "Event"], area: "North Campus", daysOfWeek: [3] },
  { title: "50% Off", time: "Open–Close", details: "1/2 Off All Alcohol", barName: "Fourth Street Taproom", typeLabels: ["Drink Special"], area: "North Campus", daysOfWeek: [2] },
  { title: "", time: "Open–Close", details: "$3 Crown Shots ; $0.75 Wings", barName: "Fourth Street Taproom", typeLabels: ["Drink Special", "Food Special"], area: "North Campus", daysOfWeek: [4] },
  { title: "Mimosa Day", time: "11am–3pm", details: "$25 Mimosa Towers", barName: "Fourth Street Taproom", typeLabels: ["Drink Special"], area: "North Campus", daysOfWeek: [6, 0] },
  { title: "Happy Hour", time: "4pm–8pm", details: "$5 Drafts ; $8 Signature Cocktails ; 25% Off Appetizers", barName: "Fourth Street Taproom", typeLabels: ["Drink Special", "Food Special"], area: "North Campus", daysOfWeek: [2, 3, 4, 5, 6, 0] },
  { title: "Tini-Tuesday", time: "Unsure–Unsure", details: "$5 Martinis ; $3 Martini Shots", barName: "Ethyl & Tank", typeLabels: ["Drink Special"], area: "South Campus", daysOfWeek: [2] },
  { title: "", time: "10pm–Close", details: "$15 Beer Buckets ; $5 Spritz ; $3 Rumple Shots", barName: "Ethyl & Tank", typeLabels: ["Drink Special"], area: "South Campus", daysOfWeek: [5] },
  { title: "Madness", time: "8pm–Close", details: "$1 Bomb Shots ; $1 Wells", barName: "Midway", typeLabels: ["Drink Special"], area: "South Campus", daysOfWeek: [3], priority: 2 },
  { title: "Ugly Hour", time: "7pm–10pm", details: "$1 Wells ; $1 Bomb Shots", barName: "Ugly Tuna 2", typeLabels: ["Drink Special"], area: "South Campus", daysOfWeek: [1, 2, 3, 4, 5, 6] },
  { title: "Ugly Hour", time: "7pm–Close", details: "$1 Wells ; $1 Bomb Shots", barName: "Ugly Tuna 2", typeLabels: ["Drink Special"], area: "South Campus", daysOfWeek: [4], priority: 1 },
  { title: "BINGO Night", time: "8pm–Unsure", details: "", barName: "Leo's", typeLabels: ["Event"], area: "South Campus", daysOfWeek: [3] },
  { title: "Trivia Night", time: "8pm–Unsure", details: "", barName: "Leo's", typeLabels: ["Event"], area: "South Campus", daysOfWeek: [4], priority: 4 },
  { title: "Karaoke Night", time: "10pm–Close", details: "", barName: "Leo's", typeLabels: ["Event"], area: "South Campus", daysOfWeek: [5] },
  { title: "Ladies Night", time: "6pm–12:00 AM (Midnight)", details: "$2 Double Wells ; $2 Domestic Bottles ; $3 Lemon Drops ; $3 Green Teas ; $4 Boozy Lemonade ; $5 Smashburger", barName: "Standard", typeLabels: ["Drink Special", "Food Special"], area: "Short North", daysOfWeek: [4] },
  { title: "Beat the Bull", time: "Unsure–Close", details: "Ride the Bull (pause) and Win a Hat", barName: "Standard", typeLabels: ["Event"], area: "Short North", daysOfWeek: [4, 5, 6] },
  { title: "Power Hour", time: "6pm–8pm", details: "$1 Wells ; Free Pizza", barName: "Standard", typeLabels: ["Drink Special", "Food Special"], area: "Short North", daysOfWeek: [4, 5] },
  { title: "Extended Happy Hour", time: "6pm–10pm", details: "1/2 Off Pizza and Appetizers ; $3 Wells, Cans, & Drafts", barName: "Standard", typeLabels: ["Drink Special", "Food Special"], area: "Short North", daysOfWeek: [5] },
  { title: "Karaoke Night", time: "6pm–12:00 AM (Midnight)", details: "$2 Double Wells ; $2 Domestic Bottles ; $3 Lemon Drops ; $3 Prosecco ; $3 Green Tea ; $4 Boozy Lemonade ; $5 Smashburger", barName: "Standard", typeLabels: ["Drink Special", "Food Special", "Event"], area: "Short North", daysOfWeek: [4] },
  { title: "Happy Hour", time: "3pm–7pm", details: "$4 Short Domestic ; $5.50 Tall Domestic ; $3 Wells", barName: "Brother's", typeLabels: ["Drink Special"], area: "Short North", daysOfWeek: [1, 2, 3, 4, 5] },
  { title: "", time: "9pm–Close", details: "$2 Wells ; $3 Hot Shots ; $4 Drafts ; $5 Lemonade Iced Teas (small)", barName: "Brother's", typeLabels: ["Drink Special"], area: "Short North", daysOfWeek: [1] },
  { title: "", time: "9pm–Close", details: "$3 Wells ; $3 Burgers ; $4 Hot Shots ; $3.50 Domestic Bottles", barName: "Brother's", typeLabels: ["Drink Special", "Food Special"], area: "Short North", daysOfWeek: [2] },
  { title: "", time: "9pm–Close", details: "$0.40 Wings ; $2 Busch ; $3 Green Teas ; $4 Double Wells ; $5 Tall Domestic", barName: "Brother's", typeLabels: ["Drink Special", "Food Special"], area: "Short North", daysOfWeek: [3] },
  { title: "", time: "9pm–Close", details: "$2 Double Wells ; $3 Domestic Bottles ; $3 Bombs; $4 Lemonade Iced Teas (small)", barName: "Brother's", typeLabels: ["Drink Special"], area: "Short North", daysOfWeek: [4] },
  { title: "", time: "9pm–Close", details: "$3 Double Wells ; $4 Titos Mixers ; $4 Jameson Mixers; $8 Lemonade Iced Teas", barName: "Brother's", typeLabels: ["Drink Special"], area: "Short North", daysOfWeek: [5] },
  { title: "", time: "9pm–Close", details: "$4 Fireball ; $4 Bombs ; $6 Vegas Bombs; $7 Double Vodka Redbull", barName: "Brother's", typeLabels: ["Drink Special"], area: "Short North", daysOfWeek: [6] },
  { title: "Happy Hour", time: "3pm–7pm", details: "$3 wells ; $4 domestic ; $5 call mixers ; $5 craft drafts", barName: "Gaswerks", typeLabels: ["Drink Special"], area: "Short North", daysOfWeek: [1, 2, 3, 4, 5] },
  { title: "", time: "9pm–Close", details: "$1 cherry bombs ; $1 wells ; $2 domestic ; $4 quad wells", barName: "Gaswerks", typeLabels: ["Drink Special"], area: "Short North", daysOfWeek: [4] },
  { title: "", time: "9pm–Close", details: "$1 cherry bombs ; $1 jager bombs ; $4 domestic ; $4 green tea shots ; $5 surfsides ; $6 double vodka red bulls", barName: "Gaswerks", typeLabels: ["Drink Special"], area: "Short North", daysOfWeek: [5] },
  { title: "", time: "Open–Close", details: "$1 cherry bombs ; $1 jager bombs​ ; $5 bud light (tall) ; $5 lemon drops", barName: "Gaswerks", typeLabels: ["Drink Special"], area: "Short North", daysOfWeek: [6] },
  { title: "", time: "3pm–7pm", details: "$2.25 Bud light, Miller light, High Life, Coors Light, PBR, Yuengling, Strohs", barName: "Short North Tavern", typeLabels: ["Drink Special"], area: "Short North", daysOfWeek: [1, 2, 3, 4, 5, 6, 0] },
  { title: "Happy Hour", time: "3pm–6pm", details: "$3 Domestic Crafts ; $6 Imports & Craft Beers ; Half Off Pizza and Appetizers", barName: "Pint House", typeLabels: ["Drink Special", "Food Special"], area: "Short North", daysOfWeek: [3] },
  { title: "", time: "6pm–Close", details: "$0.75 Wings ; 5 for $15 Beer Buckets ; $5 Espresso Martini (All Day)", barName: "Pint House", typeLabels: ["Drink Special", "Food Special"], area: "Short North", daysOfWeek: [4] },
  { title: "", time: "7pm–Close", details: "$5 Burger and Fries ; $5 Mac & Cheese ; $5 Long Islands ; $3 Draft Beers", barName: "Pint House", typeLabels: ["Drink Special", "Food Special"], area: "Short North", daysOfWeek: [0] },
  { title: "BINGO night", time: "8pm–Unsure", details: "", barName: "The Go Go", typeLabels: ["Event"], area: "Short North", daysOfWeek: [3] },
  { title: "", time: "4pm–9pm", details: "$3 Mondays: $3 Fireball, Rumple, Green Tea, & White Tea Shots, Well drinks, 16oz Domestic Beers", barName: "Draft Kings", typeLabels: ["Drink Special"], area: "Short North", daysOfWeek: [1] },
  { title: "Ladies Night", time: "Unsure–Close", details: "2 for 1 Espresso Martinis ; $15 Mamitas Bucket", barName: "Galla Park", typeLabels: ["Drink Special"], area: "Short North", daysOfWeek: [4] },
  { title: "Happy Hour", time: "Open–Close", details: "$1 Wings ; $9 One Topping Pizza", barName: "Yogi's", typeLabels: ["Food Special"], area: "Grandview / Breweries", daysOfWeek: [1] },
  { title: "", time: "Open–Close", details: "$2 Tenders ; $2 Busch Light ; 1/2 Off Wine Bottles", barName: "Yogi's", typeLabels: ["Drink Special", "Food Special"], area: "Grandview / Breweries", daysOfWeek: [2] },
  { title: "", time: "Open–Close", details: "$10 Smashburger ; $5 Craft Drafts ; $5 Crown Royal Shots", barName: "Yogi's", typeLabels: ["Drink Special", "Food Special"], area: "Grandview / Breweries", daysOfWeek: [3] },
  { title: "", time: "Open–Close", details: "$10 Wrap & Fries ; $5 Espolon Blanco Shots ; $5 Suncruiser ; $15 Clase Azul", barName: "Yogi's", typeLabels: ["Drink Special", "Food Special"], area: "Grandview / Breweries", daysOfWeek: [4] },
  { title: "", time: "Open–Close", details: "$10 Sicilian & Fries ; $8 Espresso Martini ; $4 Green Tea & White Tea Shots", barName: "Yogi's", typeLabels: ["Drink Special", "Food Special"], area: "Grandview / Breweries", daysOfWeek: [5] },
  { title: "", time: "Open–Close", details: "$8 Dip Trio; $7 House Margarita ; $5 Three Olives Bombs", barName: "Yogi's", typeLabels: ["Drink Special", "Food Special"], area: "Grandview / Breweries", daysOfWeek: [6] },
  { title: "", time: "Open–Close", details: "$1 Wings ; $15 Garage Beer Buckets (5) ; $5 Blue Gatorade Shot", barName: "Yogi's", typeLabels: ["Drink Special", "Food Special"], area: "Grandview / Breweries", daysOfWeek: [0] },
];

export const ACTIVITIES_CAROUSEL_ITEMS: ActivitiesCarouselItem[] = [
  { title: "Ugly Hour", time: "7pm–Close", details: "$1 Wells ; $1 Bomb Shots", barName: "Ugly Tuna 2", typeLabels: ["Drink Special"], priority: 1 },
  { title: "Madness", time: "8pm–Close", details: "$1 Bomb Shots ; $1 Wells", barName: "Midway", typeLabels: ["Drink Special"], priority: 2 },
  { title: "Out-R-Thursday", time: "4pm–Close", details: "$2 Doubles and Well Night", barName: "Out-R-Inn", typeLabels: ["Drink Special"], priority: 3 },
  { title: "Trivia Night", time: "8pm–Unsure", details: "", barName: "Leo's", typeLabels: ["Event"], priority: 4 },
  { title: "", time: "9pm–Close", details: "$1 Wells", barName: "Three's", typeLabels: ["Drink Special"], priority: 5 },
];

export type ListingBadgeVariant = "amber" | "violet" | "red";

export function listingBadgeVariant(
  label: ListingTypeLabel,
  typeLabels: ListingTypeLabel[]
): ListingBadgeVariant {
  const hasEvent = typeLabels.includes("Event");
  const hasSpecial =
    typeLabels.includes("Drink Special") || typeLabels.includes("Food Special");
  if (label === "Event" && hasEvent && hasSpecial) return "red";
  if (label === "Event") return "violet";
  return "amber";
}

export function listingCardAccent(typeLabels: ListingTypeLabel[]): ListingBadgeVariant {
  const hasEvent = typeLabels.includes("Event");
  const hasSpecial =
    typeLabels.includes("Drink Special") || typeLabels.includes("Food Special");
  if (hasEvent && hasSpecial) return "red";
  if (hasEvent) return "violet";
  return "amber";
}

/** Omit detail text that duplicates the title. */
export function listingDetailText(title: string, details: string): string {
  const trimmedTitle = title.trim();
  const trimmedDetails = details.trim();
  if (!trimmedDetails) return "";
  if (!trimmedTitle) return trimmedDetails;
  if (trimmedDetails === trimmedTitle) return "";
  const firstSegment = trimmedDetails.split(";")[0]?.trim() ?? "";
  if (firstSegment === trimmedTitle) {
    return trimmedDetails.includes(";")
      ? trimmedDetails
          .split(";")
          .slice(1)
          .map((part) => part.trim())
          .filter(Boolean)
          .join("; ")
      : "";
  }
  return trimmedDetails;
}

function entryMatchesWeekday(entry: { daysOfWeek: number[] }, weekday: WeekdayIndex): boolean {
  return entry.daysOfWeek.includes(weekday);
}

export type ListingListItem = BarListing;

export function getListingsForAreaWeekday(
  area: string,
  weekday: WeekdayIndex
): ListingListItem[] {
  return WEEKLY_LISTINGS.filter(
    (entry) => entry.area === area && entryMatchesWeekday(entry, weekday)
  ).map(({ title, time, details, barName, typeLabels }) => ({
    title,
    time,
    details,
    barName,
    typeLabels,
  }));
}

export function countItemsForArea(area: string): number {
  let n = 0;
  for (let day = 0; day <= 6; day++) {
    n += getListingsForAreaWeekday(area, day as WeekdayIndex).length;
  }
  return n;
}

/** Activities carousel — priority items only, ascending priority (1…n, then loop). */
export function getActivitiesCarouselItems(_date?: string): ActivitiesCarouselItem[] {
  return [...ACTIVITIES_CAROUSEL_ITEMS].sort((a, b) => a.priority - b.priority);
}

