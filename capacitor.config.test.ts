import { CapacitorConfig } from '@capacitor/cli';

/** Staging / Bar Fest Test — WebView loads bar-fest-test.vercel.app (Test branch). */
const config: CapacitorConfig = {
  appId: 'com.barfest.app.test',
  appName: 'Bar Fest Test',
  webDir: 'dist',
  server: {
    url: 'https://bar-fest-test.vercel.app',
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
