-- Add is_test to geographies (mirrors catalog_venues test flag semantics).
-- Run in Supabase SQL Editor after catalog_geographies.sql.

ALTER TABLE catalog_geographies
  ADD COLUMN IF NOT EXISTS is_test BOOLEAN NOT NULL DEFAULT false;
