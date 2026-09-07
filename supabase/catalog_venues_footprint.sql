-- =============================================================================
-- Venue footprints: center pin + 4-corner polygon for presence / wait gates
-- Run in Supabase SQL Editor after catalog_setup.sql / catalog_geographies.sql.
-- =============================================================================

-- Ordered corners: NW, NE, SE, SW as [{ "lat": …, "lng": … }, …]
ALTER TABLE catalog_venues
  ADD COLUMN IF NOT EXISTS footprint jsonb;

COMMENT ON COLUMN catalog_venues.footprint IS
  'Four corner polygon (NW,NE,SE,SW) as [{"lat":n,"lng":n},…]. Map pin uses latitude/longitude center.';

COMMENT ON COLUMN catalog_venues.radius_m IS
  'Legacy circular radius; presence uses footprint. Kept for older clients / fallback.';

-- Offset meters → lat/lng deltas (equirectangular; fine at venue scale).
CREATE OR REPLACE FUNCTION venue_offset_point(
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION,
  p_north_m DOUBLE PRECISION,
  p_east_m DOUBLE PRECISION
)
RETURNS jsonb
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT jsonb_build_object(
    'lat', p_lat + (p_north_m / 111320.0),
    'lng', p_lng + (p_east_m / (111320.0 * GREATEST(cos(radians(p_lat)), 0.01)))
  );
$$;

-- Default square: 10 m toward NW / NE / SE / SW from center.
CREATE OR REPLACE FUNCTION default_venue_footprint(
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION,
  p_half_m DOUBLE PRECISION DEFAULT 10
)
RETURNS jsonb
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT jsonb_build_array(
    venue_offset_point(p_lat, p_lng,  p_half_m, -p_half_m), -- NW
    venue_offset_point(p_lat, p_lng,  p_half_m,  p_half_m), -- NE
    venue_offset_point(p_lat, p_lng, -p_half_m,  p_half_m), -- SE
    venue_offset_point(p_lat, p_lng, -p_half_m, -p_half_m)  -- SW
  );
$$;

-- Backfill missing footprints from existing center pins.
UPDATE catalog_venues
SET footprint = default_venue_footprint(latitude, longitude, 10)
WHERE footprint IS NULL
   OR jsonb_typeof(footprint) <> 'array'
   OR jsonb_array_length(footprint) < 4;

ALTER TABLE catalog_venues
  ALTER COLUMN footprint SET DEFAULT NULL;

-- Keep footprint filled on insert/update when omitted.
CREATE OR REPLACE FUNCTION catalog_venues_ensure_footprint()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.footprint IS NULL
     OR jsonb_typeof(NEW.footprint) <> 'array'
     OR jsonb_array_length(NEW.footprint) < 4 THEN
    NEW.footprint := default_venue_footprint(NEW.latitude, NEW.longitude, 10);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_catalog_venues_ensure_footprint ON catalog_venues;
CREATE TRIGGER trg_catalog_venues_ensure_footprint
BEFORE INSERT OR UPDATE OF latitude, longitude, footprint ON catalog_venues
FOR EACH ROW
EXECUTE FUNCTION catalog_venues_ensure_footprint();

-- Ray-cast point-in-polygon (footprint ring).
CREATE OR REPLACE FUNCTION point_in_venue_footprint(
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION,
  p_footprint jsonb
)
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  n INT;
  i INT;
  j INT;
  xi DOUBLE PRECISION;
  yi DOUBLE PRECISION;
  xj DOUBLE PRECISION;
  yj DOUBLE PRECISION;
  inside BOOLEAN := false;
BEGIN
  IF p_footprint IS NULL OR jsonb_typeof(p_footprint) <> 'array' THEN
    RETURN false;
  END IF;
  n := jsonb_array_length(p_footprint);
  IF n < 3 THEN
    RETURN false;
  END IF;

  j := n - 1;
  FOR i IN 0 .. n - 1 LOOP
    yi := (p_footprint -> i ->> 'lat')::DOUBLE PRECISION;
    xi := (p_footprint -> i ->> 'lng')::DOUBLE PRECISION;
    yj := (p_footprint -> j ->> 'lat')::DOUBLE PRECISION;
    xj := (p_footprint -> j ->> 'lng')::DOUBLE PRECISION;
    IF ((yi > p_lat) <> (yj > p_lat))
       AND (p_lng < (xj - xi) * (p_lat - yi) / NULLIF(yj - yi, 0) + xi) THEN
      inside := NOT inside;
    END IF;
    j := i;
  END LOOP;
  RETURN inside;
END;
$$;

-- Meters from point to closest point on footprint edges (0 if inside).
CREATE OR REPLACE FUNCTION distance_m_to_venue_footprint(
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION,
  p_footprint jsonb
)
RETURNS DOUBLE PRECISION
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  n INT;
  i INT;
  j INT;
  min_d DOUBLE PRECISION := 1e18;
  lat1 DOUBLE PRECISION;
  lng1 DOUBLE PRECISION;
  lat2 DOUBLE PRECISION;
  lng2 DOUBLE PRECISION;
  -- Local meters frame around p
  ax DOUBLE PRECISION;
  ay DOUBLE PRECISION;
  bx DOUBLE PRECISION;
  b_y DOUBLE PRECISION;
  t DOUBLE PRECISION;
  px DOUBLE PRECISION;
  py DOUBLE PRECISION;
  dx DOUBLE PRECISION;
  dy DOUBLE PRECISION;
  cos_lat DOUBLE PRECISION;
BEGIN
  IF p_footprint IS NULL OR jsonb_typeof(p_footprint) <> 'array' THEN
    RETURN NULL;
  END IF;
  IF point_in_venue_footprint(p_lat, p_lng, p_footprint) THEN
    RETURN 0;
  END IF;

  n := jsonb_array_length(p_footprint);
  IF n < 2 THEN
    RETURN NULL;
  END IF;

  cos_lat := GREATEST(cos(radians(p_lat)), 0.01);

  j := n - 1;
  FOR i IN 0 .. n - 1 LOOP
    lat1 := (p_footprint -> j ->> 'lat')::DOUBLE PRECISION;
    lng1 := (p_footprint -> j ->> 'lng')::DOUBLE PRECISION;
    lat2 := (p_footprint -> i ->> 'lat')::DOUBLE PRECISION;
    lng2 := (p_footprint -> i ->> 'lng')::DOUBLE PRECISION;

    ax := (lng1 - p_lng) * 111320.0 * cos_lat;
    ay := (lat1 - p_lat) * 111320.0;
    bx := (lng2 - p_lng) * 111320.0 * cos_lat;
    b_y := (lat2 - p_lat) * 111320.0;
    dx := bx - ax;
    dy := b_y - ay;
    IF dx = 0 AND dy = 0 THEN
      t := 0;
    ELSE
      t := GREATEST(0, LEAST(1, (-ax * dx + -ay * dy) / (dx * dx + dy * dy)));
    END IF;
    px := ax + t * dx;
    py := ay + t * dy;
    min_d := LEAST(min_d, sqrt(px * px + py * py));
    j := i;
  END LOOP;

  RETURN min_d;
END;
$$;

-- Wait report gate: active live_locations OR inside footprint OR within 15 m of edge.
CREATE OR REPLACE FUNCTION submit_venue_wait_report(
  p_author_id TEXT,
  p_venue_name TEXT,
  p_wait_minutes SMALLINT,
  p_latitude DOUBLE PRECISION DEFAULT NULL,
  p_longitude DOUBLE PRECISION DEFAULT NULL,
  p_is_mock BOOLEAN DEFAULT false
)
RETURNS venue_wait_reports
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  venue_trimmed TEXT;
  v_geography UUID;
  v_lat DOUBLE PRECISION;
  v_lon DOUBLE PRECISION;
  v_radius_m DOUBLE PRECISION;
  v_footprint jsonb;
  location_ok BOOLEAN;
  edge_m DOUBLE PRECISION;
  new_row venue_wait_reports;
BEGIN
  IF p_author_id IS NULL OR length(trim(p_author_id)) = 0 THEN
    RAISE EXCEPTION 'author_id required';
  END IF;

  venue_trimmed := trim(p_venue_name);
  IF venue_trimmed IS NULL OR length(venue_trimmed) = 0 THEN
    RAISE EXCEPTION 'venue_name required';
  END IF;

  IF p_wait_minutes IS NULL OR p_wait_minutes NOT IN (5, 10, 15, 30, 45) THEN
    RAISE EXCEPTION 'wait_minutes must be 5, 10, 15, 30, or 45';
  END IF;

  SELECT geography_id, latitude, longitude, radius_m, footprint
    INTO v_geography, v_lat, v_lon, v_radius_m, v_footprint
  FROM catalog_venues
  WHERE name = venue_trimmed;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Venue not found';
  END IF;

  IF v_geography IS NULL THEN
    RAISE EXCEPTION 'Venue not found';
  END IF;

  IF NOT coalesce(p_is_mock, false) THEN
    IF p_latitude IS NULL OR p_longitude IS NULL THEN
      RAISE EXCEPTION 'Location required to report wait time';
    END IF;

    SELECT EXISTS (
      SELECT 1
      FROM live_locations
      WHERE user_id = p_author_id
        AND venue_name = venue_trimmed
        AND is_active = true
        AND last_updated > NOW() - INTERVAL '18 minutes'
    )
    INTO location_ok;

    IF NOT location_ok THEN
      IF v_footprint IS NOT NULL AND jsonb_array_length(v_footprint) >= 4 THEN
        edge_m := distance_m_to_venue_footprint(p_latitude, p_longitude, v_footprint);
        location_ok := edge_m IS NOT NULL AND edge_m <= 15;
      ELSE
        location_ok := haversine_miles(v_lat, v_lon, p_latitude, p_longitude)
          <= (coalesce(v_radius_m, 100) / 1609.344);
      END IF;
    END IF;

    IF NOT location_ok THEN
      RAISE EXCEPTION 'Must be at the bar to report wait time';
    END IF;
  END IF;

  INSERT INTO venue_wait_reports (
    author_id,
    venue_name,
    wait_minutes,
    geography_id,
    is_mock,
    created_at,
    updated_at
  )
  VALUES (
    p_author_id,
    venue_trimmed,
    p_wait_minutes,
    v_geography,
    coalesce(p_is_mock, false),
    NOW(),
    NOW()
  )
  ON CONFLICT (author_id, venue_name)
  DO UPDATE SET
    wait_minutes = EXCLUDED.wait_minutes,
    geography_id = EXCLUDED.geography_id,
    is_mock = EXCLUDED.is_mock,
    updated_at = NOW()
  RETURNING * INTO new_row;

  RETURN new_row;
END;
$$;

GRANT EXECUTE ON FUNCTION submit_venue_wait_report(TEXT, TEXT, SMALLINT, DOUBLE PRECISION, DOUBLE PRECISION, BOOLEAN)
  TO anon, authenticated;

GRANT EXECUTE ON FUNCTION default_venue_footprint(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION)
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION point_in_venue_footprint(DOUBLE PRECISION, DOUBLE PRECISION, jsonb)
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION distance_m_to_venue_footprint(DOUBLE PRECISION, DOUBLE PRECISION, jsonb)
  TO anon, authenticated;
