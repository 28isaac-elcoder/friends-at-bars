import { useCallback, useEffect, useRef, useState } from "react";
import { CatalogGeography, CatalogVenue, supabase } from "./supabase";
import { loadMapKit } from "./mapkitLoader";

/** OSU North Campus default — matches main app MapKit region. */
const DEFAULT_CENTER = { lat: 39.9917, lon: -83.0067 };
const DEFAULT_SPAN = { lat: 0.06, lon: 0.06 };

const VENUE_COLOR = "#2563eb";
const TEST_VENUE_COLOR = "#16a34a";
const PLACE_PIN_COLOR = "#dc2626";
const GEO_PIN_COLOR = "#7c3aed";
const GEO_CIRCLE_COLOR = "#7c3aed";

const MILES_TO_METERS = 1609.344;

const LOG_PREFIX = "[CMS Map]";

function mapLog(...args: unknown[]) {
  console.log(LOG_PREFIX, ...args);
}

function mapWarn(...args: unknown[]) {
  console.warn(LOG_PREFIX, ...args);
}

export type MapCoords = { latitude: number; longitude: number };

type MapPanelProps = {
  onStartVenue?: (coords: MapCoords) => void;
  onStartGeography?: (coords: MapCoords) => void;
};

type PlaceKind = "venue" | "geography";

function formatCoord(n: number) {
  return n.toFixed(6);
}

export function MapPanel({ onStartVenue, onStartGeography }: MapPanelProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<mapkit.Map | null>(null);
  const placePinRef = useRef<mapkit.MarkerAnnotation | null>(null);
  const placingModeRef = useRef(false);
  const placeKindRef = useRef<PlaceKind>("venue");
  const geoOverlaysRef = useRef<mapkit.CircleOverlay[]>([]);

  const [error, setError] = useState<string | null>(null);
  const [status, setStatus] = useState("Loading map…");
  const [placingMode, setPlacingMode] = useState(false);
  const [placeKind, setPlaceKind] = useState<PlaceKind>("venue");
  const [pinCoords, setPinCoords] = useState<MapCoords | null>(null);
  const [copied, setCopied] = useState(false);
  const [showGeoBounds, setShowGeoBounds] = useState(false);
  const [geographies, setGeographies] = useState<CatalogGeography[]>([]);

  placingModeRef.current = placingMode;
  placeKindRef.current = placeKind;

  const loadVenues = useCallback(async (): Promise<CatalogVenue[]> => {
    const { data, error: err } = await supabase
      .from("catalog_venues")
      .select("*")
      .eq("is_active", true)
      .order("sort_order", { ascending: true });
    if (err) throw err;
    return (data ?? []) as CatalogVenue[];
  }, []);

  const loadGeographies = useCallback(async (): Promise<CatalogGeography[]> => {
    const { data, error: err } = await supabase
      .from("catalog_geographies")
      .select("*")
      .eq("is_active", true)
      .order("sort_order", { ascending: true });
    if (err) {
      mapWarn("geographies load failed (run catalog_geographies.sql?)", err);
      return [];
    }
    return (data ?? []) as CatalogGeography[];
  }, []);

  const syncGeoOverlays = useCallback(
    (geos: CatalogGeography[], visible: boolean) => {
      const map = mapRef.current;
      if (!map) return;
      for (const overlay of geoOverlaysRef.current) {
        try {
          map.removeOverlay(overlay);
        } catch {
          // ignore
        }
      }
      geoOverlaysRef.current = [];
      if (!visible) return;
      for (const geo of geos) {
        const overlay = new mapkit.CircleOverlay(
          new mapkit.Coordinate(geo.latitude, geo.longitude),
          geo.radius_miles * MILES_TO_METERS,
          {
            style: new mapkit.Style({
              strokeColor: GEO_CIRCLE_COLOR,
              strokeOpacity: 0.9,
              lineWidth: 2,
              fillColor: GEO_CIRCLE_COLOR,
              fillOpacity: 0.12,
            }),
          }
        );
        map.addOverlay(overlay);
        geoOverlaysRef.current.push(overlay);
      }
    },
    []
  );

  const syncPinFromAnnotation = useCallback((ann: mapkit.MarkerAnnotation) => {
    const c = ann.coordinate;
    const next = { latitude: c.latitude, longitude: c.longitude };
    mapLog("syncPinFromAnnotation", next);
    setPinCoords(next);
  }, []);

  const placeOrMovePinRef = useRef<(lat: number, lon: number) => void>(
    () => undefined
  );

  placeOrMovePinRef.current = (latitude: number, longitude: number) => {
    mapLog("placeOrMovePin called", { latitude, longitude });
    const map = mapRef.current;
    if (!map) {
      mapWarn("placeOrMovePin aborted: mapRef is null");
      return;
    }

    const existing = placePinRef.current;
    if (existing) {
      mapLog("moving existing place pin");
      existing.coordinate = new mapkit.Coordinate(latitude, longitude);
      syncPinFromAnnotation(existing);
      setPlacingMode(false);
      mapLog("placingMode → false after move");
      return;
    }

    try {
      const marker = new mapkit.MarkerAnnotation(
        new mapkit.Coordinate(latitude, longitude),
        {
          title: placeKindRef.current === "geography" ? "Geography center" : "Drop pin",
          color:
            placeKindRef.current === "geography" ? GEO_PIN_COLOR : PLACE_PIN_COLOR,
          draggable: true,
        }
      );
      marker.data = { kind: "place-pin" };
      marker.addEventListener("drag-end", () => {
        mapLog("place pin drag-end");
        syncPinFromAnnotation(marker);
      });
      map.addAnnotation(marker);
      placePinRef.current = marker;
      mapLog("added new place pin annotation", {
        annotationCount: map.annotations?.length,
      });
      syncPinFromAnnotation(marker);
      setPlacingMode(false);
      mapLog("placingMode → false after create");
    } catch (e) {
      mapWarn("failed to create/add place pin", e);
    }
  };

  const removePlacePin = useCallback(() => {
    mapLog("removePlacePin clicked");
    const map = mapRef.current;
    const pin = placePinRef.current;
    if (map && pin) {
      try {
        map.removeAnnotation(pin);
        mapLog("removed place pin annotation");
      } catch (e) {
        mapWarn("removeAnnotation failed", e);
      }
    } else {
      mapWarn("removePlacePin: nothing to remove", {
        hasMap: !!map,
        hasPin: !!pin,
      });
    }
    placePinRef.current = null;
    setPinCoords(null);
    setCopied(false);
  }, []);

  useEffect(() => {
    const el = containerRef.current;
    mapLog("map init effect start", { hasContainer: !!el });
    if (!el) return;

    let destroyed = false;
    let onSingleTap: ((event: mapkit.MapEvent) => void) | null = null;

    (async () => {
      try {
        mapLog("loadMapKit…");
        await loadMapKit();
        mapLog("loadMapKit ok");
        if (destroyed || !el) {
          mapWarn("aborted after loadMapKit", { destroyed, hasEl: !!el });
          return;
        }

        const map = new mapkit.Map(el, {
          region: new mapkit.CoordinateRegion(
            new mapkit.Coordinate(DEFAULT_CENTER.lat, DEFAULT_CENTER.lon),
            new mapkit.CoordinateSpan(DEFAULT_SPAN.lat, DEFAULT_SPAN.lon)
          ),
        });
        mapRef.current = map;
        mapLog("mapkit.Map created", {
          hasConvert: typeof map.convertPointOnPageToCoordinate === "function",
          hasAddEventListener: typeof map.addEventListener === "function",
        });

        onSingleTap = (event) => {
          const placing = placingModeRef.current;
          const keys =
            event && typeof event === "object"
              ? Object.keys(event as object)
              : [];
          const point = event.pointOnPage;
          mapLog("single-tap", {
            placingMode: placing,
            eventKeys: keys,
            hasCoordinate: !!event.coordinate,
            pointOnPage: point
              ? { x: point.x, y: point.y }
              : null,
            rawCoordinate: event.coordinate
              ? {
                  latitude: event.coordinate.latitude,
                  longitude: event.coordinate.longitude,
                }
              : null,
          });

          if (!placing) {
            mapLog("single-tap ignored (placingMode off)");
            return;
          }

          let latitude: number | null = null;
          let longitude: number | null = null;

          if (
            point &&
            typeof map.convertPointOnPageToCoordinate === "function"
          ) {
            try {
              const converted = map.convertPointOnPageToCoordinate(point);
              latitude = converted.latitude;
              longitude = converted.longitude;
              mapLog("converted pointOnPage → coordinate", {
                latitude,
                longitude,
              });
            } catch (e) {
              mapWarn("convertPointOnPageToCoordinate failed", e);
            }
          } else if (event.coordinate) {
            latitude = event.coordinate.latitude;
            longitude = event.coordinate.longitude;
            mapLog("using event.coordinate fallback", {
              latitude,
              longitude,
            });
          }

          if (latitude == null || longitude == null) {
            mapWarn(
              "single-tap in placing mode but could not resolve coordinates",
              { point, hasConvert: typeof map.convertPointOnPageToCoordinate }
            );
            return;
          }

          placeOrMovePinRef.current(latitude, longitude);
        };
        map.addEventListener("single-tap", onSingleTap);
        mapLog("registered single-tap listener");

        const venues = await loadVenues();
        const geos = await loadGeographies();
        if (destroyed) {
          mapWarn("destroyed before venues applied");
          return;
        }

        setGeographies(geos);

        for (const venue of venues) {
          const marker = new mapkit.MarkerAnnotation(
            new mapkit.Coordinate(venue.latitude, venue.longitude),
            {
              title: venue.name,
              subtitle: venue.area,
              color: venue.is_test ? TEST_VENUE_COLOR : VENUE_COLOR,
            }
          );
          marker.data = { kind: "venue", id: venue.id };
          map.addAnnotation(marker);
        }

        mapLog("venue annotations added", { count: venues.length });
        setStatus(
          venues.length
            ? `${venues.length} active venue${venues.length === 1 ? "" : "s"}`
            : "No active venues"
        );
        setError(null);
        if (showGeoBounds) syncGeoOverlays(geos, true);
      } catch (e) {
        const message =
          e instanceof Error ? e.message : "MapKit JS failed to load";
        mapWarn("map init failed", e);
        setError(message);
        setStatus("");
      }
    })();

    return () => {
      mapLog("map init effect cleanup");
      destroyed = true;
      const map = mapRef.current;
      if (map && onSingleTap) {
        try {
          map.removeEventListener("single-tap", onSingleTap);
        } catch {
          // ignore
        }
      }
      placePinRef.current = null;
      mapRef.current = null;
      if (map) {
        try {
          map.destroy();
        } catch {
          // ignore
        }
      }
    };
  }, [loadVenues, loadGeographies, syncGeoOverlays, syncPinFromAnnotation]);

  useEffect(() => {
    syncGeoOverlays(geographies, showGeoBounds);
  }, [geographies, showGeoBounds, syncGeoOverlays]);

  const coordsText = pinCoords
    ? `${formatCoord(pinCoords.latitude)}, ${formatCoord(pinCoords.longitude)}`
    : "";

  async function copyCoords() {
    if (!coordsText) return;
    try {
      await navigator.clipboard.writeText(coordsText);
      setCopied(true);
      window.setTimeout(() => setCopied(false), 1500);
      mapLog("copied coords", coordsText);
    } catch (e) {
      mapWarn("clipboard write failed", e);
      const input = document.getElementById(
        "map-pin-coords"
      ) as HTMLInputElement | null;
      input?.select();
    }
  }

    <div className="map-panel-root">
      <div className="map-toolbar">
        {(error || status) && (
          <div className={`map-banner-inline ${error ? "error" : "muted"}`}>
            {error ? (
              <>
                {error}
                {error.includes("VITE_MAPKIT_TOKEN") && (
                  <>
                    {" "}
                    Set <code>VITE_MAPKIT_TOKEN</code> in{" "}
                    <code>admin-cms/.env.local</code> (and Vercel).
                  </>
                )}
              </>
            ) : (
              status
            )}
          </div>
        )}

        <div className="map-toolbar-actions">
          <button
            type="button"
            className={placingMode && placeKind === "venue" ? "active" : ""}
            onClick={() => {
              setPlaceKind("venue");
              setPlacingMode((v) => !(v && placeKind === "venue"));
            }}
            disabled={!!error}
            title="Place a bar pin"
          >
            {pinCoords && placeKind === "venue" ? "Move bar" : "Place bar"}
          </button>
          <button
            type="button"
            className={placingMode && placeKind === "geography" ? "active" : ""}
            onClick={() => {
              setPlaceKind("geography");
              setPlacingMode((v) => !(v && placeKind === "geography"));
            }}
            disabled={!!error}
            title="Place a geography center"
          >
            {pinCoords && placeKind === "geography"
              ? "Move geography"
              : "Place geography"}
          </button>
          <button
            type="button"
            className={showGeoBounds ? "active" : ""}
            onClick={() => setShowGeoBounds((v) => !v)}
            disabled={!!error}
            title="Show geography radius circles"
          >
            Geographies
          </button>
          {pinCoords && (
            <>
              <button
                type="button"
                className="danger"
                onClick={removePlacePin}
                title="Remove pin"
              >
                Remove
              </button>
              {placeKind === "geography" ? (
                <button
                  type="button"
                  onClick={() => onStartGeography?.(pinCoords)}
                  disabled={!onStartGeography}
                  title="Start geography from pin"
                >
                  Start geography
                </button>
              ) : (
                <button
                  type="button"
                  onClick={() => onStartVenue?.(pinCoords)}
                  disabled={!onStartVenue}
                  title="Start venue from pin"
                >
                  Start venue
                </button>
              )}
            </>
          )}
        </div>

        {pinCoords && (
          <label className="map-coords-field">
            Lat, lng
            <div className="map-coords-row">
              <input
                id="map-pin-coords"
                type="text"
                readOnly
                value={coordsText}
                onFocus={(e) => e.target.select()}
              />
              <button type="button" onClick={() => void copyCoords()}>
                {copied ? "Copied" : "Copy"}
              </button>
            </div>
          </label>
        )}
      </div>

      <div ref={containerRef} className="map-fill" />
    </div>
  );
}
