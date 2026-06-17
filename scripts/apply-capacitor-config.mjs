/**
 * Copies production or test Capacitor config to capacitor.config.ts before cap sync.
 * Usage: node scripts/apply-capacitor-config.mjs [production|test]
 */
import { copyFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';

const flavor = (process.argv[2] ?? 'production').toLowerCase();
const root = resolve(import.meta.dirname, '..');
const dest = resolve(root, 'capacitor.config.ts');

const sources = {
  production: resolve(root, 'capacitor.config.production.ts'),
  test: resolve(root, 'capacitor.config.test.ts'),
};

if (flavor !== 'production' && flavor !== 'test') {
  console.error('Usage: node scripts/apply-capacitor-config.mjs [production|test]');
  process.exit(1);
}

const source = sources[flavor];
if (!existsSync(source)) {
  console.error(`Missing ${source}`);
  process.exit(1);
}

copyFileSync(source, dest);
console.log(`Applied Capacitor config: ${flavor} → capacitor.config.ts`);
