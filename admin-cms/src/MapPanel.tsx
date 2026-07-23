import { useCallback, useEffect, useRef, useState } from "react";
import { CatalogVenue, supabase } from "./supabase";
import { loadMapKit } from "./mapkitLoader";

/** OSU North Campus default — matches main app MapKit region. */
const DEFAULT_CENTER = { lat: 39.9917, lon: -83.0067 };
const DEFAULT_SPAN = { lat: 0.06, lon: 0.06 };

const VENUE_COLOR = "#2563eb";
const TEST_VENUE_COLOR = "#16a34a";
const PLACE_PIN_COLOR = "#dc2626";

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
};

function formatCoord(n: number) {
  return n.toFixed(6);
}

export function MapPanel({ onStartVenue }: MapPanelProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<mapkit.Map | null>(null);
  const placePinRef = useRef<mapkit.MarkerAnnotation | null>(null);
  const placingModeRef = useRef(false);

  const [error, setError] = useState<string | null>(null);
  const [status, setStatus] = useState("Loading map…");
  const [placingMode, setPlacingMode] = useState(false);
  const [pinCoords, setPinCoords] = useState<MapCoords | null>(null);
  const [copied, setCopied] = useState(false);

  placingModeRef.current = placingMode;

  const loadVenues = useCallback(async (): Promise<CatalogVenue[]> => {
    const { data, error: err } = await supabase
      .from("catalog_venues")
      .select("*")
      .eq("is_active", true)
      .order("sort_order", { ascending: true });
    if (err) throw err;
    return (data ?? []) as CatalogVenue[];
  }, []);

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
          title: "Drop pin",
          color: PLACE_PIN_COLOR,
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
        if (destroyed) {
          mapWarn("destroyed before venues applied");
          return;
        }

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
  }, [loadVenues, syncPinFromAnnotation]);

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

  function togglePlacingMode() {
    setPlacingMode((v) => {
      const next = !v;
      mapLog("Place pin toggled", {
        placingMode: next,
        hasExistingPin: !!placePinRef.current,
        mapReady: !!mapRef.current,
      });
      return next;
    });
  }

  return (
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
            className={placingMode ? "active" : ""}
            onClick={togglePlacingMode}
            disabled={!!error}
            title={
              placingMode
                ? "Tap the map to set pin location"
                : pinCoords
                  ? "Move pin — then tap the map"
                  : "Place pin — then tap the map"
            }
          >
            {pinCoords ? "Move" : "Place"}
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
              <button
                type="button"
                onClick={() => {
                  mapLog("Start venue from pin", pinCoords);
                  onStartVenue?.(pinCoords);
                }}
                disabled={!onStartVenue}
                title="Start venue from pin"
              >
                Start
              </button>
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
