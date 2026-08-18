-- =============================================================================
-- Geographies + areas (run in Supabase SQL Editor after catalog_setup.sql)
-- Columbus is the default geography; existing venues are backfilled to it.
-- =============================================================================

CREATE TABLE IF NOT EXISTS catalog_geographies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  radius_miles DOUBLE PRECISION NOT NULL DEFAULT 35,
  is_default BOOLEAN NOT NULL DEFAULT false,
  is_active BOOLEAN NOT NULL DEFAULT true,
  is_test BOOLEAN NOT NULL DEFAULT false,
  sort_order INTEGER NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_catalog_geographies_one_default
  ON catalog_geographies (is_default)
  WHERE is_default = true;

CREATE TABLE IF NOT EXISTS catalog_areas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  geography_id UUID NOT NULL REFERENCES catalog_geographies(id) ON DELETE CASCADE,
  long_name TEXT NOT NULL,
  short_name TEXT NOT NULL,
  accent_hex TEXT NOT NULL DEFAULT '#387AEB',
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (geography_id, long_name)
);

ALTER TABLE catalog_venues
  ADD COLUMN IF NOT EXISTS geography_id UUID REFERENCES catalog_geographies(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_catalog_venues_geography
  ON catalog_venues (geography_id);

DROP TRIGGER IF EXISTS trg_catalog_geographies_updated ON catalog_geographies;
CREATE TRIGGER trg_catalog_geographies_updated
BEFORE UPDATE ON catalog_geographies
FOR EACH ROW EXECUTE FUNCTION catalog_touch_updated_at();

DROP TRIGGER IF EXISTS trg_catalog_areas_updated ON catalog_areas;
CREATE TRIGGER trg_catalog_areas_updated
BEFORE UPDATE ON catalog_areas
FOR EACH ROW EXECUTE FUNCTION catalog_touch_updated_at();

DROP TRIGGER IF EXISTS trg_bump_version_geographies ON catalog_geographies;
CREATE TRIGGER trg_bump_version_geographies
AFTER INSERT OR UPDATE OR DELETE ON catalog_geographies
FOR EACH STATEMENT EXECUTE FUNCTION catalog_bump_content_version();

DROP TRIGGER IF EXISTS trg_bump_version_areas ON catalog_areas;
CREATE TRIGGER trg_bump_version_areas
AFTER INSERT OR UPDATE OR DELETE ON catalog_areas
FOR EACH STATEMENT EXECUTE FUNCTION catalog_bump_content_version();

ALTER TABLE catalog_geographies ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog_areas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "catalog_geographies_select" ON catalog_geographies;
CREATE POLICY "catalog_geographies_select"
  ON catalog_geographies FOR SELECT
  USING (is_active = true OR auth.role() = 'authenticated');

DROP POLICY IF EXISTS "catalog_geographies_admin_write" ON catalog_geographies;
CREATE POLICY "catalog_geographies_admin_write"
  ON catalog_geographies FOR ALL
  USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "catalog_areas_select" ON catalog_areas;
CREATE POLICY "catalog_areas_select"
  ON catalog_areas FOR SELECT
  USING (is_active = true OR auth.role() = 'authenticated');

DROP POLICY IF EXISTS "catalog_areas_admin_write" ON catalog_areas;
CREATE POLICY "catalog_areas_admin_write"
  ON catalog_areas FOR ALL
  USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');

GRANT SELECT ON catalog_geographies, catalog_areas TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON catalog_geographies, catalog_areas TO authenticated;

-- Seed Columbus (idempotent by name)
INSERT INTO catalog_geographies (name, latitude, longitude, radius_miles, is_default, is_active, is_test, sort_order)
VALUES ('Columbus', 39.981997, -83.004427, 35, true, true, false, 0)
ON CONFLICT (name) DO UPDATE
SET
  latitude = EXCLUDED.latitude,
  longitude = EXCLUDED.longitude,
  radius_miles = EXCLUDED.radius_miles,
  is_default = true,
  is_active = true;

INSERT INTO catalog_areas (geography_id, long_name, short_name, accent_hex, sort_order, is_active)
SELECT g.id, a.long_name, a.short_name, a.accent_hex, a.sort_order, true
FROM catalog_geographies g
CROSS JOIN (
  VALUES
    ('North Campus', 'North Campus', '#387AEB', 0),
    ('South Campus', 'South Campus', '#EB3847', 1),
    ('Short North', 'Short North', '#2EC761', 2),
    ('Grandview / Breweries', 'Grand-Brew', '#B851F2', 3)
) AS a(long_name, short_name, accent_hex, sort_order)
WHERE g.name = 'Columbus'
ON CONFLICT (geography_id, long_name) DO UPDATE
SET
  short_name = EXCLUDED.short_name,
  accent_hex = EXCLUDED.accent_hex,
  sort_order = EXCLUDED.sort_order,
  is_active = true;

UPDATE catalog_venues v
SET geography_id = g.id
FROM catalog_geographies g
WHERE g.name = 'Columbus'
  AND v.geography_id IS NULL;
