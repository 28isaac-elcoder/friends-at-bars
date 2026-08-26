-- =============================================================================
-- Venue wait-time reports (user-reported line waits)
-- Buckets: 5, 10, 15, 30, 45+ minutes
-- Run in the Supabase SQL editor (safe to re-run).
-- =============================================================================

CREATE TABLE IF NOT EXISTS venue_wait_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id TEXT NOT NULL,
  venue_name TEXT NOT NULL,
  wait_minutes SMALLINT NOT NULL CHECK (wait_minutes IN (5, 10, 15, 30, 45)),
  geography_id UUID REFERENCES catalog_geographies(id),
  is_mock BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (author_id, venue_name)
);

CREATE INDEX IF NOT EXISTS idx_venue_wait_reports_venue_updated
  ON venue_wait_reports (venue_name, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_venue_wait_reports_geography_updated
  ON venue_wait_reports (geography_id, updated_at DESC);

ALTER TABLE venue_wait_reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS venue_wait_reports_select ON venue_wait_reports;
CREATE POLICY venue_wait_reports_select ON venue_wait_reports
  FOR SELECT TO anon, authenticated
  USING (true);

-- Writes go through SECURITY DEFINER RPC only.

-- Reuse haversine from chat_geography if present; define fallback.
CREATE OR REPLACE FUNCTION haversine_miles(
  lat1 DOUBLE PRECISION,
  lon1 DOUBLE PRECISION,
  lat2 DOUBLE PRECISION,
  lon2 DOUBLE PRECISION
)
RETURNS DOUBLE PRECISION
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT 3958.7613 * 2 * ASIN(SQRT(
    POWER(SIN(RADIANS(lat2 - lat1) / 2), 2)
    + COS(RADIANS(lat1)) * COS(RADIANS(lat2))
      * POWER(SIN(RADIANS(lon2 - lon1) / 2), 2)
  ));
$$;

DROP FUNCTION IF EXISTS submit_venue_wait_report(TEXT, TEXT, SMALLINT, DOUBLE PRECISION, DOUBLE PRECISION, BOOLEAN);

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
  location_ok BOOLEAN;
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

  SELECT geography_id, latitude, longitude, radius_m
  INTO v_geography, v_lat, v_lon, v_radius_m
  FROM catalog_venues
  WHERE name = venue_trimmed;

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
      location_ok := haversine_miles(v_lat, v_lon, p_latitude, p_longitude)
        <= (v_radius_m / 1609.344);
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

GRANT SELECT ON venue_wait_reports TO anon, authenticated;
