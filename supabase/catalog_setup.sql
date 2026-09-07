-- =============================================================================
-- Bar Fest catalog content (venues / deals / events / game_content / app_config)
-- Run in Supabase SQL Editor. Public READ of active rows; WRITE for authenticated admins.
-- =============================================================================

-- Venues (map pins + venue gates)
CREATE TABLE IF NOT EXISTS catalog_venues (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  area TEXT NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  radius_m INTEGER NOT NULL DEFAULT 100,
  -- Presence polygon (NW,NE,SE,SW). See catalog_venues_footprint.sql for helpers + backfill.
  footprint jsonb,
  is_test BOOLEAN NOT NULL DEFAULT false,
  is_active BOOLEAN NOT NULL DEFAULT true,
  sort_order INTEGER NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_catalog_venues_active
  ON catalog_venues (is_active, sort_order)
  WHERE is_active = true;

-- Deals & events (replaces dealsAndEvents.ts)
CREATE TABLE IF NOT EXISTS catalog_listings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  venue_name TEXT NOT NULL REFERENCES catalog_venues(name) ON UPDATE CASCADE,
  title TEXT NOT NULL DEFAULT '',
  time_label TEXT NOT NULL DEFAULT '',
  details TEXT NOT NULL DEFAULT '',
  area TEXT NOT NULL DEFAULT '',
  listing_kind TEXT NOT NULL CHECK (listing_kind IN ('deal', 'event', 'food')),
  type_labels TEXT[] NOT NULL DEFAULT '{}',
  days_of_week INTEGER[] NOT NULL DEFAULT '{}',
  priority INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_catalog_listings_active
  ON catalog_listings (is_active, venue_name)
  WHERE is_active = true;

-- Game content (Switch Search word packs, etc.)
CREATE TABLE IF NOT EXISTS catalog_game_content (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_key TEXT NOT NULL,
  pack_key TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}',
  is_active BOOLEAN NOT NULL DEFAULT true,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (game_key, pack_key)
);

-- App-wide config / content version for clients
CREATE TABLE IF NOT EXISTS catalog_app_config (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL DEFAULT '{}',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION catalog_touch_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_catalog_venues_updated ON catalog_venues;
CREATE TRIGGER trg_catalog_venues_updated
BEFORE UPDATE ON catalog_venues
FOR EACH ROW EXECUTE FUNCTION catalog_touch_updated_at();

DROP TRIGGER IF EXISTS trg_catalog_listings_updated ON catalog_listings;
CREATE TRIGGER trg_catalog_listings_updated
BEFORE UPDATE ON catalog_listings
FOR EACH ROW EXECUTE FUNCTION catalog_touch_updated_at();

DROP TRIGGER IF EXISTS trg_catalog_game_content_updated ON catalog_game_content;
CREATE TRIGGER trg_catalog_game_content_updated
BEFORE UPDATE ON catalog_game_content
FOR EACH ROW EXECUTE FUNCTION catalog_touch_updated_at();

DROP TRIGGER IF EXISTS trg_catalog_app_config_updated ON catalog_app_config;
CREATE TRIGGER trg_catalog_app_config_updated
BEFORE UPDATE ON catalog_app_config
FOR EACH ROW EXECUTE FUNCTION catalog_touch_updated_at();

-- Bump content version whenever catalog changes
CREATE OR REPLACE FUNCTION catalog_bump_content_version()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO catalog_app_config (key, value, updated_at)
  VALUES (
    'content_version',
    jsonb_build_object('version', extract(epoch from NOW())::bigint),
    NOW()
  )
  ON CONFLICT (key) DO UPDATE
  SET value = EXCLUDED.value, updated_at = NOW();
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_bump_version_venues ON catalog_venues;
CREATE TRIGGER trg_bump_version_venues
AFTER INSERT OR UPDATE OR DELETE ON catalog_venues
FOR EACH STATEMENT EXECUTE FUNCTION catalog_bump_content_version();

DROP TRIGGER IF EXISTS trg_bump_version_listings ON catalog_listings;
CREATE TRIGGER trg_bump_version_listings
AFTER INSERT OR UPDATE OR DELETE ON catalog_listings
FOR EACH STATEMENT EXECUTE FUNCTION catalog_bump_content_version();

DROP TRIGGER IF EXISTS trg_bump_version_game ON catalog_game_content;
CREATE TRIGGER trg_bump_version_game
AFTER INSERT OR UPDATE OR DELETE ON catalog_game_content
FOR EACH STATEMENT EXECUTE FUNCTION catalog_bump_content_version();

-- RLS
ALTER TABLE catalog_venues ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog_listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog_game_content ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog_app_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "catalog_venues_select_active" ON catalog_venues;
CREATE POLICY "catalog_venues_select_active"
  ON catalog_venues FOR SELECT
  USING (is_active = true OR auth.role() = 'authenticated');

DROP POLICY IF EXISTS "catalog_venues_admin_write" ON catalog_venues;
CREATE POLICY "catalog_venues_admin_write"
  ON catalog_venues FOR ALL
  USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "catalog_listings_select_active" ON catalog_listings;
CREATE POLICY "catalog_listings_select_active"
  ON catalog_listings FOR SELECT
  USING (is_active = true OR auth.role() = 'authenticated');

DROP POLICY IF EXISTS "catalog_listings_admin_write" ON catalog_listings;
CREATE POLICY "catalog_listings_admin_write"
  ON catalog_listings FOR ALL
  USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "catalog_game_select_active" ON catalog_game_content;
CREATE POLICY "catalog_game_select_active"
  ON catalog_game_content FOR SELECT
  USING (is_active = true OR auth.role() = 'authenticated');

DROP POLICY IF EXISTS "catalog_game_admin_write" ON catalog_game_content;
CREATE POLICY "catalog_game_admin_write"
  ON catalog_game_content FOR ALL
  USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "catalog_config_select" ON catalog_app_config;
CREATE POLICY "catalog_config_select"
  ON catalog_app_config FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "catalog_config_admin_write" ON catalog_app_config;
CREATE POLICY "catalog_config_admin_write"
  ON catalog_app_config FOR ALL
  USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');

GRANT SELECT ON catalog_venues, catalog_listings, catalog_game_content, catalog_app_config
  TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON catalog_venues, catalog_listings, catalog_game_content, catalog_app_config
  TO authenticated;

-- Initial content version
INSERT INTO catalog_app_config (key, value)
VALUES ('content_version', jsonb_build_object('version', 1))
ON CONFLICT (key) DO NOTHING;
