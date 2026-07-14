import { CapacitorConfig } from '@capacitor/cli';

/**
 * Capacitor WebView config (legacy consumer path).
 * iOS product UI is moving to native/ios/BarFest (Swift). Prefer that binary for TestFlight;
 * see docs/NATIVE_HYBRID.md. Keep this file for Android Cap / transitional Cap iOS only.
 */
const config: CapacitorConfig = {
  appId: 'com.barfest.app',
  appName: 'Bar Fest',
  webDir: 'dist',
  server: {
    /** Load WebView from Vercel so JS origin matches MapKit JS domain + OTA web updates. Comment out for offline/local-bundle testing. */
    url: 'https://friends-at-bars-two.vercel.app',
    androidScheme: 'https',
    iosScheme: 'https',
  },
  android: {
    useLegacyBridge: true,
    buildOptions: {
      keystorePath: undefined,
      keystoreAlias: undefined,
    },
  },
  ios: {
    scheme: 'https',
    contentInset: 'automatic',
  },
  plugins: {
    StatusBar: {
      style: 'light',
      backgroundColor: '#000000',
      androidBackgroundColor: '#000000',
      iosStyle: 'light',
    },
  },
};

export default config;
