/** Venue footprint helpers — NW → NE → SE → SW corners around a center pin. */

export type LatLng = { lat: number; lng: number };

export const DEFAULT_FOOTPRINT_HALF_M = 10;

export function offsetPoint(
  lat: number,
  lng: number,
  northM: number,
  eastM: number
): LatLng {
  const cosLat = Math.max(Math.cos((lat * Math.PI) / 180), 0.01);
  return {
    lat: lat + northM / 111320,
    lng: lng + eastM / (111320 * cosLat),
  };
}

/** Default square: halfM toward NW / NE / SE / SW from center. */
export function defaultVenueFootprint(
  lat: number,
  lng: number,
  halfM = DEFAULT_FOOTPRINT_HALF_M
): LatLng[] {
  return [
    offsetPoint(lat, lng, halfM, -halfM), // NW
    offsetPoint(lat, lng, halfM, halfM), // NE
    offsetPoint(lat, lng, -halfM, halfM), // SE
    offsetPoint(lat, lng, -halfM, -halfM), // SW
  ];
}

export function normalizeFootprint(
  footprint: LatLng[] | null | undefined,
  centerLat: number,
  centerLng: number
): LatLng[] {
  if (footprint && footprint.length >= 4) {
    return footprint.slice(0, 4).map((p) => ({
      lat: Number(p.lat),
      lng: Number(p.lng),
    }));
  }
  return defaultVenueFootprint(centerLat, centerLng);
}

export const FOOTPRINT_CORNER_LABELS = ["NW", "NE", "SE", "SW"] as const;
