import { useState } from "react";
import Map, { Marker, Popup } from "react-map-gl/maplibre";
import maplibregl from "maplibre-gl";
import "maplibre-gl/dist/maplibre-gl.css";
import { CheckIn } from "@/types/checkin";
import { OHIO_STATE_VENUES } from "@/data/venues";
import { formatTimeDisplay } from "@/lib/timeUtils";

interface MapViewProps {
  checkIns: CheckIn[];
}

interface PopupInfo {
  venue: {
    name: string;
    area: string;
    coordinates: [number, number];
  };
  checkIns: CheckIn[];
}

export default function MapView({ checkIns }: MapViewProps) {
  const [popupInfo, setPopupInfo] = useState<PopupInfo | null>(null);

  // Get venues with check-in activity
  const getVenueActivity = (venueName: string) => {
    return checkIns.filter((checkIn) => checkIn.venue === venueName);
  };

  // Create custom marker element with Apple Maps styling
  const createMarkerElement = (isActive: boolean, activityCount: number) => {
    const size = isActive ? 36 : 24;
    const color = isActive ? "#FF6B35" : "#007AFF"; // Apple orange for active, Apple blue for default

    return (
      <div
        className="custom-marker"
        style={{
          width: `${size}px`,
          height: `${size}px`,
          backgroundColor: color,
          borderRadius: "50%",
          border: "4px solid white",
          boxShadow: "0 4px 12px rgba(0,0,0,0.15), 0 2px 6px rgba(0,0,0,0.1)",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          color: "white",
          fontWeight: "700",
          fontSize: isActive ? "14px" : "12px",
          cursor: "pointer",
          transition: "all 0.3s cubic-bezier(0.4, 0, 0.2, 1)",
          zIndex: isActive ? 1000 : 100,
          position: "relative",
        }}
        onMouseEnter={(e) => {
          e.currentTarget.style.transform = "scale(1.15)";
          e.currentTarget.style.boxShadow =
            "0 6px 16px rgba(0,0,0,0.2), 0 3px 8px rgba(0,0,0,0.15)";
        }}
        onMouseLeave={(e) => {
          e.currentTarget.style.transform = "scale(1)";
          e.currentTarget.style.boxShadow =
            "0 4px 12px rgba(0,0,0,0.15), 0 2px 6px rgba(0,0,0,0.1)";
        }}
      >
        {isActive && activityCount > 0 ? activityCount : ""}
      </div>
    );
  };

  // Handle marker click
  const handleMarkerClick = (venue: (typeof OHIO_STATE_VENUES)[0]) => {
    const venueActivity = getVenueActivity(venue.name);
    setPopupInfo({
      venue,
      checkIns: venueActivity,
    });
  };

  return (
    <div className="h-96 w-full overflow-hidden rounded-xl border border-gray-200 shadow-lg">
      <Map
        mapLib={maplibregl}
        initialViewState={{
          longitude: -83.0067,
          latitude: 39.9917,
          zoom: 14,
        }}
        style={{ width: "100%", height: "100%" }}
        mapStyle="https://basemaps.cartocdn.com/gl/positron-gl-style/style.json"
        attributionControl={false}
      >
        {/* Custom attribution */}
        <div className="absolute bottom-2 right-2 rounded bg-white/80 px-2 py-1 text-xs text-gray-600">
          ©{" "}
          <a
            href="https://carto.com/"
            target="_blank"
            rel="noopener noreferrer"
          >
            CartoDB
          </a>
          , ©{" "}
          <a
            href="https://www.openstreetmap.org/copyright"
            target="_blank"
            rel="noopener noreferrer"
          >
            OpenStreetMap
          </a>{" "}
          contributors
        </div>

        {/* Venue markers */}
        {OHIO_STATE_VENUES.map((venue) => {
          const venueActivity = getVenueActivity(venue.name);
          const isActive = venueActivity.length > 0;
          const activityCount = venueActivity.length;

          return (
            <Marker
              key={venue.name}
              longitude={venue.coordinates[1]}
              latitude={venue.coordinates[0]}
              onClick={() => handleMarkerClick(venue)}
            >
              {createMarkerElement(isActive, activityCount)}
            </Marker>
          );
        })}

        {/* Popup */}
        {popupInfo && (
          <Popup
            longitude={popupInfo.venue.coordinates[1]}
            latitude={popupInfo.venue.coordinates[0]}
            onClose={() => setPopupInfo(null)}
            closeButton={true}
            closeOnClick={false}
            className="custom-popup"
          >
            <div className="min-w-[240px] p-5">
              <h3 className="mb-2 text-xl font-bold text-gray-900">
                {popupInfo.venue.name}
              </h3>
              <p className="mb-4 text-sm font-semibold uppercase tracking-wide text-gray-500">
                {popupInfo.venue.area}
              </p>

              {popupInfo.checkIns.length > 0 ? (
                <div>
                  <p className="mb-4 text-sm font-bold text-gray-800">
                    {popupInfo.checkIns.length} check-in
                    {popupInfo.checkIns.length > 1 ? "s" : ""}
                  </p>
                  <div className="space-y-3">
                    {popupInfo.checkIns.map((checkIn) => (
                      <div
                        key={checkIn.id}
                        className="rounded-xl border border-gray-200 bg-gray-50 p-4 text-xs shadow-sm"
                      >
                        <p className="mb-2 text-sm font-bold text-gray-800">
                          {formatTimeDisplay(checkIn.startTime)} -{" "}
                          {formatTimeDisplay(checkIn.endTime)}
                        </p>
                        <p className="font-medium text-gray-500">
                          Duration: {Math.floor(checkIn.durationMinutes / 60)}h{" "}
                          {checkIn.durationMinutes % 60}m
                        </p>
                      </div>
                    ))}
                  </div>
                </div>
              ) : (
                <p className="text-sm font-semibold text-gray-500">
                  No current check-ins
                </p>
              )}
            </div>
          </Popup>
        )}
      </Map>
    </div>
  );
}
