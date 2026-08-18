-- Link deals/listings to a geography (priority ranks are per geography in CMS).
-- Run in Supabase SQL Editor after catalog_geographies.sql.

ALTER TABLE catalog_listings
  ADD COLUMN IF NOT EXISTS geography_id UUID REFERENCES catalog_geographies(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_catalog_listings_geography
  ON catalog_listings (geography_id);

UPDATE catalog_listings l
SET geography_id = v.geography_id
FROM catalog_venues v
WHERE v.name = l.venue_name
  AND l.geography_id IS NULL
  AND v.geography_id IS NOT NULL;
