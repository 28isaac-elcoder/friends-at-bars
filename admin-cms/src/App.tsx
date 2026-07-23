import { useEffect, useState } from "react";
import type { Session } from "@supabase/supabase-js";
import { supabase } from "./supabase";
import { VenuesPanel } from "./VenuesPanel";
import { ListingsPanel } from "./ListingsPanel";
import { GameContentPanel } from "./GameContentPanel";
import { MapPanel, type MapCoords } from "./MapPanel";

type Tab = "venues" | "listings" | "games" | "map";

export default function App() {
  const [session, setSession] = useState<Session | null>(null);
  const [tab, setTab] = useState<Tab>("venues");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [venueSeed, setVenueSeed] = useState<MapCoords | null>(null);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => setSession(data.session));
    const { data: sub } = supabase.auth.onAuthStateChange((_e, s) =>
      setSession(s)
    );
    return () => sub.subscription.unsubscribe();
  }, []);

  async function signIn(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    const { error: err } = await supabase.auth.signInWithPassword({
      email,
      password,
    });
    setBusy(false);
    if (err) setError(err.message);
  }

  if (!session) {
    return (
      <div className="login panel">
        <h1>Bar Fest CMS</h1>
        <p className="muted">Sign in with a Supabase Auth editor account.</p>
        <form
          onSubmit={signIn}
          style={{ display: "grid", gap: "0.75rem", marginTop: "1rem" }}
        >
          <label>
            Email
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
            />
          </label>
          <label>
            Password
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
            />
          </label>
          {error && <p className="error">{error}</p>}
          <button type="submit" disabled={busy}>
            {busy ? "Signing in…" : "Sign in"}
          </button>
        </form>
      </div>
    );
  }

  const shellClass =
    tab === "map"
      ? "app-shell map-mode"
      : tab === "listings"
        ? "app-shell wide"
        : "app-shell";

  return (
    <div className={shellClass}>
      <header>
        <div>
          <h1>Bar Fest CMS</h1>
          <p className="muted">{session.user.email}</p>
        </div>
        <button type="button" onClick={() => supabase.auth.signOut()}>
          Sign out
        </button>
      </header>

      <div className="tabs">
        {(
          [
            ["venues", "Venues"],
            ["listings", "Deals / Events"],
            ["games", "Game content"],
            ["map", "Map"],
          ] as const
        ).map(([id, label]) => (
          <button
            key={id}
            type="button"
            className={tab === id ? "active" : ""}
            onClick={() => setTab(id)}
          >
            {label}
          </button>
        ))}
      </div>

      <div className={tab === "map" ? "panel map-panel" : "panel"}>
        {tab === "venues" && (
          <VenuesPanel
            seedCoords={venueSeed}
            onSeedConsumed={() => setVenueSeed(null)}
          />
        )}
        {tab === "listings" && <ListingsPanel />}
        {tab === "games" && <GameContentPanel />}
        {tab === "map" && (
          <MapPanel
            onStartVenue={(coords) => {
              setVenueSeed(coords);
              setTab("venues");
            }}
          />
        )}
      </div>
    </div>
  );
}
