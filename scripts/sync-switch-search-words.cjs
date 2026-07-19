const fs = require("fs");

const lib = JSON.parse(fs.readFileSync("src/data/wordLibrary.json", "utf8"));
const payload = {
  fourLetter: lib.fourLetter || [],
  fiveLetter: lib.fiveLetter || [],
  sixLetter: lib.sixLetter || [],
  sevenLetter: lib.sevenLetter || [],
};
const compact = JSON.stringify(payload);
const escaped = compact.replace(/'/g, "''");

const upsert = `-- Switch Search word pack (synced from src/data/wordLibrary.json)
-- Run in the Supabase SQL editor to update the admin CMS pack.

INSERT INTO catalog_game_content (game_key, pack_key, payload, is_active)
VALUES (
  'switch-search',
  'default',
  '${escaped}'::jsonb,
  true
)
ON CONFLICT (game_key, pack_key) DO UPDATE SET
  payload = EXCLUDED.payload,
  is_active = true;
`;

fs.writeFileSync("supabase/switch_search_word_pack.sql", upsert);

let seed = fs.readFileSync("supabase/catalog_seed.sql", "utf8");
const startMarker =
  "INSERT INTO catalog_game_content (game_key, pack_key, payload, is_active)";
const endMarker = "ON CONFLICT (game_key, pack_key) DO UPDATE SET";
const i = seed.indexOf(startMarker);
const j = seed.indexOf(endMarker, i);
if (i < 0 || j < 0) {
  console.error("catalog_seed.sql markers not found");
  process.exit(1);
}
const k = seed.indexOf(";", j);
const replacement =
  startMarker +
  "\nVALUES ('switch-search', 'default', '" +
  escaped +
  "'::jsonb, true)\n" +
  "ON CONFLICT (game_key, pack_key) DO UPDATE SET\n" +
  "  payload = EXCLUDED.payload,\n" +
  "  is_active = true";
seed = seed.slice(0, i) + replacement + seed.slice(k);
fs.writeFileSync("supabase/catalog_seed.sql", seed);

fs.copyFileSync(
  "src/data/wordLibrary.json",
  "native/ios/BarFest/BarFest/Resources/wordLibrary.json"
);

console.log(
  "synced buckets:",
  payload.fourLetter.length,
  payload.fiveLetter.length,
  payload.sixLetter.length,
  payload.sevenLetter.length
);
