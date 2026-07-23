/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_SUPABASE_URL: string;
  readonly VITE_SUPABASE_PUBLISHABLE_KEY: string;
  /** Same MapKit JS JWT as the main Bar Fest app (Vercel + local). */
  readonly VITE_MAPKIT_TOKEN?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
