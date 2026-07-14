import { createClient } from "@supabase/supabase-js";

const url = import.meta.env.VITE_SUPABASE_URL as string;
const key = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY as string;

if (!url || !key) {
  console.warn(
    "Set VITE_SUPABASE_URL and VITE_SUPABASE_PUBLISHABLE_KEY in .env.local"
  );
}

export const supabase = createClient(
  url || "https://your-project.supabase.co",
  key || "your-key"
);

export type CatalogVenue = {
  id: string;
  name: string;
  area: string;
  latitude: number;
  longitude: number;
  radius_m: number;
  is_test: boolean;
  is_active: boolean;
  sort_order: number;
};

export type CatalogListing = {
  id: string;
  venue_name: string;
  title: string;
  time_label: string;
  details: string;
  area: string;
  listing_kind: "deal" | "event" | "food";
  type_labels: string[];
  days_of_week: number[];
  priority: number;
  is_active: boolean;
};
