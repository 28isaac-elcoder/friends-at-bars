import { Venue } from "@/types/checkin";
import { isDevTestModeUiEnabled } from "@/config/devTestMode";

export const OHIO_STATE_VENUES: Venue[] = [
  // North Campus
  {
    name: "Out-R-Inn",
    area: "North Campus",
    coordinates: [40.0051, -83.00845],
  }, // 40°00'18"N 83°00'30"W
  { name: "Horseshoe", area: "North Campus", coordinates: [40.0064, -83.0095] }, // 40°00'22"N 83°00'34"W
  { name: "Library", area: "North Campus", coordinates: [40.0066, -83.0095] }, // 40°00'23"N 83°00'34"W
  { name: "Three's", area: "North Campus", coordinates: [40.0072, -83.0097] }, // 40°00'25"N 83°00'34"W
  { name: "Five's", area: "North Campus", coordinates: [40.0106, -83.0105] }, // 40°00'38"N 83°00'37"W
  {
    name: "Varsity Club",
    area: "North Campus",
    coordinates: [40.0065, -83.017003],
  },
  {
    name: "Fourth Street Taproom",
    area: "North Campus",
    coordinates: [40.00029, -82.99842],
  },

  // South Campus
  {
    name: "Ethyl & Tank",
    area: "South Campus",
    coordinates: [39.9975, -83.0069], // 39°59'51"N 83°00'25"W
  },
  { name: "Midway", area: "South Campus", coordinates: [39.9975, -83.00735] }, // 39°59'51"N 83°00'26"W
  {
    name: "Big Bar / Sky Bar",
    area: "South Campus",
    coordinates: [39.9972, -83.0073], // 39°59'50"N 83°00'26"W
  },
  {
    name: "Ugly Tuna 2",
    area: "South Campus",
    coordinates: [39.9953, -83.0018], // 39°59'43"N 83°00'06"W
  },
  { name: "Euporia", area: "South Campus", coordinates: [39.99416, -83.0062] }, // 39°59'38"N 83°00'22"W
  { name: "Leo's", area: "South Campus", coordinates: [39.9956, -83.00654] }, // 39°59'44"N 83°00'23"W

  // Short North
  { name: "Standard", area: "Short North", coordinates: [39.9848, -83.0048] }, // 39°59'05"N 83°00'17"W
  { name: "Brother's", area: "Short North", coordinates: [39.97163, -83.0051] }, // 39°58'18"N 83°00'18"W
  {
    name: "Gaswerks",
    area: "Short North",
    coordinates: [39.971993, -83.005109],
  },
  {
    name: "Astra Rooftop",
    area: "Short North",
    coordinates: [39.972723, -83.004937],
  },
  {
    name: "Short North Tavern",
    area: "Short North",
    coordinates: [39.97615, -83.00315],
  },
  { name: "TownHall", area: "Short North", coordinates: [39.9788, -83.0035] }, // 39°58'43"N 83°00'12"W
  {
    name: "Good Night John Boy",
    area: "Short North",
    coordinates: [39.98103, -83.00403], // 39°58'51"N 83°00'14"W
  },
  {
    name: "Pint House",
    area: "Short North",
    coordinates: [39.9782, -83.00347],
  }, // 39°58'42"N 83°00'12"W
  {
    name: "Draft Kings",
    area: "Short North",
    coordinates: [39.9794, -83.00375],
  }, // 39°58'46"N 83°00'13"W
  {
    name: "The Go Go",
    area: "Short North",
    coordinates: [39.98314, -82.9994],
  }, // 39°58'59"N 82°59'57"W
  {
    name: "Axis",
    area: "Short North",
    coordinates: [39.97805, -83.00443],
  }, // 39°58'40"N 83°00'15"W
  {
    name: "Galla Park",
    area: "Short North",
    coordinates: [39.98065, -83.00397],
  }, // 39°58'50"N 83°00'14"W

  // Grandview / Breweries
  {
    name: "Yogi's",
    area: "Grandview / Breweries",
    coordinates: [39.987346, -83.031681],
  },
  {
    name: "Land Grant",
    area: "Grandview / Breweries",
    coordinates: [39.9577, -83.01148],
  },
  {
    name: "Highbank Distillery",
    area: "Grandview / Breweries",
    coordinates: [39.974, -83.0313],
  },
  {
    name: "Nocterra Brewing Co.",
    area: "Grandview / Breweries",
    coordinates: [39.95, -83.0071],
  },
  {
    name: "Barley Brewing Co.",
    area: "Grandview / Breweries",
    coordinates: [39.97192, -83.0022],
  },
  {
    name: "Budd Dairy",
    area: "Grandview / Breweries",
    coordinates: [39.985168, -82.9989],
  },
  {
    name: "Seventh Son Brewing",
    area: "Grandview / Breweries",
    coordinates: [39.985322, -82.99969],
  },

  // Test Locations
  {
    name: "Test Location 1",
    area: "Test Locations",
    coordinates: [39.98385, -83.006739], // 39°59'01.86"N 83°00'24.26"W (Google Earth)
  },
];

export const CAMPUS_AREAS = [
  "North Campus",
  "South Campus",
  "Short North",
  "Grandview / Breweries",
  "Test Locations",
] as const;

/**
 * Areas that only appear in test builds. They are shown and used only when
 * the dev test mode UI is enabled (ENABLE_DEV_TEST_MODE_UI in config/devTestMode).
 */
export const TEST_AREAS: readonly string[] = ["Test Locations"];

function isTestArea(area: string | undefined): boolean {
  return area !== undefined && TEST_AREAS.includes(area);
}

/**
 * Venues that are visible and usable in the current build.
 * - Dev test mode enabled  → all venues (including Test Locations).
 * - Dev test mode disabled → Test Locations hidden/excluded.
 */
export const VISIBLE_VENUES: Venue[] = isDevTestModeUiEnabled()
  ? OHIO_STATE_VENUES
  : OHIO_STATE_VENUES.filter((v) => !isTestArea(v.area));

/** Areas to display, excluding Test Locations unless dev test mode is enabled. */
export const VISIBLE_CAMPUS_AREAS: readonly string[] = isDevTestModeUiEnabled()
  ? CAMPUS_AREAS
  : CAMPUS_AREAS.filter((a) => !isTestArea(a));

const VISIBLE_VENUE_NAMES = new Set(VISIBLE_VENUES.map((v) => v.name));

/** True if a venue (by name) should be shown/used in the current build. */
export function isVenueVisible(venueName: string): boolean {
  return VISIBLE_VENUE_NAMES.has(venueName);
}
