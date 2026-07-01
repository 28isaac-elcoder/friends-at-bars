import { MapPinned } from "lucide-react";
import { Capacitor } from "@capacitor/core";
import MapLocationPermissionPrompt from "@/components/MapLocationPermissionPrompt";

export type RankedGateOverlay = "none" | "permission" | "not-at-bar";

type RankedGateProps = {
  overlay: RankedGateOverlay;
  onClose: () => void;
  onAllowLocation: () => void | Promise<void>;
  locationBusy?: boolean;
  showWebLocationHelp?: boolean;
  nativeSettingsError?: string | null;
};

export function RankedGate({
  overlay,
  onClose,
  onAllowLocation,
  locationBusy = false,
  showWebLocationHelp = false,
  nativeSettingsError = null,
}: RankedGateProps) {
  if (overlay === "none") return null;

  const nativeSettingsShortcut =
    Capacitor.isNativePlatform() &&
    (Capacitor.getPlatform() === "ios" || Capacitor.getPlatform() === "android");

  if (overlay === "permission") {
    return (
      <MapLocationPermissionPrompt
        open
        variant="ranked"
        onAllow={onAllowLocation}
        onSecondary={onClose}
        secondaryLabel="Back"
        busy={locationBusy}
        coverNav
        nativeSettingsNote={nativeSettingsShortcut}
        showWebLocationHelp={showWebLocationHelp}
        nativeSettingsError={nativeSettingsError}
      />
    );
  }

  return (
    <div
      className="fixed inset-0 z-[200] flex flex-col bg-zinc-950 text-white"
      style={{ paddingTop: "var(--safe-area-inset-top)" }}
      role="dialog"
      aria-modal="true"
      aria-labelledby="ranked-not-at-bar-title"
    >
      <div className="flex min-h-0 flex-1 flex-col items-center justify-center px-6 text-center">
        <h1
          id="ranked-not-at-bar-title"
          className="text-2xl font-bold tracking-tight sm:text-3xl"
        >
          Not at a bar
        </h1>
        <p className="mt-3 max-w-sm text-pretty text-base leading-relaxed text-zinc-400">
          Ranked runs can only be started when you are at a participating venue.
          Move closer to the bar and try again.
        </p>
        <div
          className="mt-10 flex h-36 w-36 items-center justify-center rounded-3xl bg-zinc-900/80 ring-1 ring-white/10"
          aria-hidden
        >
          <MapPinned className="h-20 w-20 text-rose-400/90" strokeWidth={1.25} />
        </div>
      </div>
      <div className="px-6 pb-[var(--safe-area-inset-bottom)]">
        <button
          type="button"
          onClick={onClose}
          className="w-full rounded-2xl border border-zinc-600 bg-zinc-800 py-3.5 text-center text-base font-semibold text-white shadow-md transition hover:bg-zinc-700 active:scale-[0.99]"
        >
          Back to Menu
        </button>
      </div>
    </div>
  );
}
