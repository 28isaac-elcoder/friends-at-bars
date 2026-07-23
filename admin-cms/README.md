# Bar Fest Admin CMS

Editors-only Vite app for catalog CRUD against Supabase.

## Local

```bash
cp .env.example .env.local
# fill VITE_SUPABASE_URL + VITE_SUPABASE_PUBLISHABLE_KEY + VITE_MAPKIT_TOKEN
npm install
npm run dev
```

Create an Auth user in Supabase Dashboard for editors. RLS requires `authenticated` for writes.

`VITE_MAPKIT_TOKEN` is the same MapKit JS JWT as the main app. Allowlist `http://localhost:5174` (and your Vercel CMS URL) on the token in Apple Developer.

## Deploy (Vercel)

1. New Vercel project → root `admin-cms`
2. Set env vars `VITE_SUPABASE_URL`, `VITE_SUPABASE_PUBLISHABLE_KEY`, `VITE_MAPKIT_TOKEN`
3. Build: `npm run build`, output `dist`

See [docs/CATALOG_CMS.md](../docs/CATALOG_CMS.md).
