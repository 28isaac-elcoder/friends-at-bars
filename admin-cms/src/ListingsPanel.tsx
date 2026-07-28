import { useCallback, useEffect, useMemo, useState } from "react";
import { CatalogListing, CatalogVenue, supabase } from "./supabase";

const AREAS = [
  "North Campus",
  "South Campus",
  "Short North",
  "Grandview / Breweries",
  "Test Locations",
];
const DAY_LABELS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
const TYPE_OPTIONS = ["Drink Special", "Food Special", "Event"];

type Draft = Omit<CatalogListing, "id">;

function blank(venueName = ""): Draft {
  return {
    venue_name: venueName,
    title: "",
    time_label: "",
    details: "",
    area: "North Campus",
    listing_kind: "deal",
    type_labels: ["Drink Special"],
    days_of_week: [4],
    priority: 0,
    is_active: true,
  };
}

function kindFromLabels(labels: string[]): Draft["listing_kind"] {
  const hasE = labels.includes("Event");
  const hasD = labels.includes("Drink Special");
  const hasF = labels.includes("Food Special");
  if (hasE && !hasD && !hasF) return "event";
  if (hasF && !hasD && !hasE) return "food";
  return "deal";
}

function toggleDay(days: number[], day: number): number[] {
  return days.includes(day)
    ? days.filter((d) => d !== day)
    : [...days, day].sort((a, b) => a - b);
}

function toggleType(labels: string[], label: string): string[] {
  return labels.includes(label)
    ? labels.filter((l) => l !== label)
    : [...labels, label];
}

type PatchFn = (id: string, patch: Partial<Draft>) => void;

/** Stacked editable card — primary mobile editing surface for Deals/Events. */
function ListingCard({
  row,
  venues,
  onPatch,
  onRemove,
}: {
  row: CatalogListing;
  venues: CatalogVenue[];
  onPatch: PatchFn;
  onRemove: (id: string) => void;
}) {
  return (
    <li className="listing-card">
      <label>
        Venue
        <select
          value={row.venue_name}
          onChange={(e) => onPatch(row.id, { venue_name: e.target.value })}
        >
          {venues.map((v) => (
            <option key={v.id} value={v.name}>
              {v.name}
            </option>
          ))}
        </select>
      </label>
      <label>
        Title
        <input
          defaultValue={row.title}
          onBlur={(e) => {
            if (e.target.value !== row.title)
              onPatch(row.id, { title: e.target.value });
          }}
        />
      </label>
      <label>
        Time
        <input
          defaultValue={row.time_label}
          onBlur={(e) => {
            if (e.target.value !== row.time_label)
              onPatch(row.id, { time_label: e.target.value });
          }}
        />
      </label>
      <label>
        Details
        <textarea
          defaultValue={row.details}
          rows={3}
          onBlur={(e) => {
            if (e.target.value !== row.details)
              onPatch(row.id, { details: e.target.value });
          }}
        />
      </label>
      <label>
        Area
        <select
          value={row.area}
          onChange={(e) => onPatch(row.id, { area: e.target.value })}
        >
          {AREAS.map((a) => (
            <option key={a} value={a}>
              {a}
            </option>
          ))}
        </select>
      </label>
      <fieldset className="listing-card-fieldset">
        <legend>Types</legend>
        <div className="row-actions">
          {TYPE_OPTIONS.map((t) => (
            <label key={t} className="inline-check">
              <input
                type="checkbox"
                checked={row.type_labels.includes(t)}
                onChange={() => {
                  const next = toggleType(row.type_labels, t);
                  onPatch(row.id, {
                    type_labels: next,
                    listing_kind: kindFromLabels(next),
                  });
                }}
              />
              {t}
            </label>
          ))}
        </div>
      </fieldset>
      <fieldset className="listing-card-fieldset">
        <legend>Days</legend>
        <div className="row-actions">
          {DAY_LABELS.map((label, day) => (
            <label key={label} className="inline-check">
              <input
                type="checkbox"
                checked={row.days_of_week.includes(day)}
                onChange={() =>
                  onPatch(row.id, {
                    days_of_week: toggleDay(row.days_of_week, day),
                  })
                }
              />
              {label}
            </label>
          ))}
        </div>
      </fieldset>
      <div className="listing-card-meta">
        <label>
          Priority
          <input
            type="number"
            defaultValue={row.priority}
            onBlur={(e) => {
              const n = Number(e.target.value);
              if (n !== row.priority) onPatch(row.id, { priority: n });
            }}
          />
        </label>
        <label className="inline-check listing-card-active">
          <input
            type="checkbox"
            checked={row.is_active}
            onChange={(e) => onPatch(row.id, { is_active: e.target.checked })}
          />
          Active
        </label>
        <button
          type="button"
          className="danger"
          onClick={() => onRemove(row.id)}
        >
          Delete
        </button>
      </div>
    </li>
  );
}

export function ListingsPanel() {
  const [rows, setRows] = useState<CatalogListing[]>([]);
  const [venues, setVenues] = useState<CatalogVenue[]>([]);
  const [draft, setDraft] = useState<Draft>(blank());
  const [error, setError] = useState<string | null>(null);
  const [filterArea, setFilterArea] = useState<string>("");
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);

  const load = useCallback(async () => {
    const [listingsRes, venuesRes] = await Promise.all([
      supabase
        .from("catalog_listings")
        .select("*")
        .order("area", { ascending: true })
        .order("venue_name", { ascending: true }),
      supabase
        .from("catalog_venues")
        .select("*")
        .order("name", { ascending: true }),
    ]);
    if (listingsRes.error) setError(listingsRes.error.message);
    else {
      setError(null);
      setRows((listingsRes.data ?? []) as CatalogListing[]);
    }
    if (!venuesRes.error) {
      const v = (venuesRes.data ?? []) as CatalogVenue[];
      setVenues(v);
      setDraft((d) => (d.venue_name ? d : blank(v[0]?.name ?? "")));
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const visible = useMemo(() => {
    if (!filterArea) return rows;
    return rows.filter((r) => r.area === filterArea);
  }, [rows, filterArea]);

  async function createRow(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    setMsg(null);
    const payload = {
      ...draft,
      listing_kind: kindFromLabels(draft.type_labels),
    };
    const { error: err } = await supabase.from("catalog_listings").insert(payload);
    setBusy(false);
    if (err) {
      setError(err.message);
      return;
    }
    setDraft(blank(draft.venue_name));
    setMsg("Row added");
    await load();
  }

  async function patchRow(id: string, patch: Partial<Draft>) {
    setError(null);
    const { error: err } = await supabase
      .from("catalog_listings")
      .update(patch)
      .eq("id", id);
    if (err) setError(err.message);
    else await load();
  }

  async function removeRow(id: string) {
    if (!confirm("Delete this listing?")) return;
    const { error: err } = await supabase
      .from("catalog_listings")
      .delete()
      .eq("id", id);
    if (err) setError(err.message);
    else await load();
  }

  return (
    <div className="listings-panel">
      <h2>Deals &amp; Events</h2>
      <p className="muted listings-help-desktop">
        Spreadsheet columns: venue, title, time, details, area, types, days
        (0=Sun…6=Sat), priority, active.
      </p>
      <p className="muted listings-help-mobile">
        Edit each deal as a card. Filter by area, then tap fields to update.
      </p>

      <div className="listings-toolbar row-actions">
        <label>
          Filter area{" "}
          <select
            value={filterArea}
            onChange={(e) => setFilterArea(e.target.value)}
          >
            <option value="">All areas</option>
            {AREAS.map((a) => (
              <option key={a} value={a}>
                {a}
              </option>
            ))}
          </select>
        </label>
        <span className="muted">{visible.length} rows</span>
      </div>

      <form className="grid" onSubmit={createRow}>
        <label>
          Venue
          <select
            value={draft.venue_name}
            onChange={(e) => {
              const name = e.target.value;
              const area = venues.find((v) => v.name === name)?.area ?? draft.area;
              setDraft({ ...draft, venue_name: name, area });
            }}
            required
          >
            {venues.map((v) => (
              <option key={v.id} value={v.name}>
                {v.name}
              </option>
            ))}
          </select>
        </label>
        <label>
          Area
          <select
            value={draft.area}
            onChange={(e) => setDraft({ ...draft, area: e.target.value })}
          >
            {AREAS.map((a) => (
              <option key={a} value={a}>
                {a}
              </option>
            ))}
          </select>
        </label>
        <label>
          Title
          <input
            value={draft.title}
            onChange={(e) => setDraft({ ...draft, title: e.target.value })}
            placeholder="Optional"
          />
        </label>
        <label>
          Time
          <input
            value={draft.time_label}
            onChange={(e) => setDraft({ ...draft, time_label: e.target.value })}
            placeholder="e.g. 8pm-Close"
          />
        </label>
        <label className="full">
          Details
          <textarea
            rows={2}
            value={draft.details}
            onChange={(e) => setDraft({ ...draft, details: e.target.value })}
          />
        </label>
        <label>
          Priority
          <input
            type="number"
            value={draft.priority}
            onChange={(e) =>
              setDraft({ ...draft, priority: Number(e.target.value) })
            }
          />
        </label>
        <label>
          Types
          <div className="row-actions">
            {TYPE_OPTIONS.map((t) => (
              <label key={t} className="inline-check">
                <input
                  type="checkbox"
                  checked={draft.type_labels.includes(t)}
                  onChange={() =>
                    setDraft({
                      ...draft,
                      type_labels: toggleType(draft.type_labels, t),
                    })
                  }
                />
                {t}
              </label>
            ))}
          </div>
        </label>
        <label className="full">
          Days
          <div className="row-actions">
            {DAY_LABELS.map((label, day) => (
              <label key={label} className="inline-check">
                <input
                  type="checkbox"
                  checked={draft.days_of_week.includes(day)}
                  onChange={() =>
                    setDraft({
                      ...draft,
                      days_of_week: toggleDay(draft.days_of_week, day),
                    })
                  }
                />
                {label}
              </label>
            ))}
          </div>
        </label>
        <label className="full">
          <button type="submit" disabled={busy}>
            {busy ? "Adding…" : "Add listing row"}
          </button>
        </label>
      </form>

      {error && <p className="error">{error}</p>}
      {msg && <p className="muted">{msg}</p>}

      {/* Desktop spreadsheet */}
      <div className="listings-table-wrap table-scroll">
        <table>
          <thead>
            <tr>
              <th>Venue</th>
              <th>Title</th>
              <th>Time</th>
              <th>Details</th>
              <th>Area</th>
              <th>Types</th>
              <th>Days</th>
              <th>Pri</th>
              <th>On</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {visible.map((r) => (
              <tr key={r.id}>
                <td>
                  <select
                    value={r.venue_name}
                    onChange={(e) =>
                      void patchRow(r.id, { venue_name: e.target.value })
                    }
                  >
                    {venues.map((v) => (
                      <option key={v.id} value={v.name}>
                        {v.name}
                      </option>
                    ))}
                  </select>
                </td>
                <td>
                  <input
                    defaultValue={r.title}
                    onBlur={(e) => {
                      if (e.target.value !== r.title)
                        void patchRow(r.id, { title: e.target.value });
                    }}
                  />
                </td>
                <td>
                  <input
                    defaultValue={r.time_label}
                    className="col-time"
                    onBlur={(e) => {
                      if (e.target.value !== r.time_label)
                        void patchRow(r.id, { time_label: e.target.value });
                    }}
                  />
                </td>
                <td>
                  <textarea
                    defaultValue={r.details}
                    rows={2}
                    className="col-details"
                    onBlur={(e) => {
                      if (e.target.value !== r.details)
                        void patchRow(r.id, { details: e.target.value });
                    }}
                  />
                </td>
                <td>
                  <select
                    value={r.area}
                    onChange={(e) =>
                      void patchRow(r.id, { area: e.target.value })
                    }
                  >
                    {AREAS.map((a) => (
                      <option key={a} value={a}>
                        {a}
                      </option>
                    ))}
                  </select>
                </td>
                <td>
                  <div className="row-actions">
                    {TYPE_OPTIONS.map((t) => (
                      <label
                        key={t}
                        className="inline-check"
                        style={{ fontSize: "0.75rem" }}
                      >
                        <input
                          type="checkbox"
                          checked={r.type_labels.includes(t)}
                          onChange={() => {
                            const next = toggleType(r.type_labels, t);
                            void patchRow(r.id, {
                              type_labels: next,
                              listing_kind: kindFromLabels(next),
                            });
                          }}
                        />
                        {t.slice(0, 5)}
                      </label>
                    ))}
                  </div>
                </td>
                <td>
                  <div className="row-actions">
                    {DAY_LABELS.map((label, day) => (
                      <label
                        key={label}
                        className="inline-check"
                        style={{ fontSize: "0.7rem" }}
                      >
                        <input
                          type="checkbox"
                          checked={r.days_of_week.includes(day)}
                          onChange={() =>
                            void patchRow(r.id, {
                              days_of_week: toggleDay(r.days_of_week, day),
                            })
                          }
                        />
                        {label[0]}
                      </label>
                    ))}
                  </div>
                </td>
                <td>
                  <input
                    type="number"
                    defaultValue={r.priority}
                    className="col-pri"
                    onBlur={(e) => {
                      const n = Number(e.target.value);
                      if (n !== r.priority)
                        void patchRow(r.id, { priority: n });
                    }}
                  />
                </td>
                <td>
                  <input
                    type="checkbox"
                    checked={r.is_active}
                    onChange={(e) =>
                      void patchRow(r.id, { is_active: e.target.checked })
                    }
                  />
                </td>
                <td>
                  <button
                    type="button"
                    className="danger"
                    onClick={() => void removeRow(r.id)}
                  >
                    Del
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Mobile stacked cards */}
      <ul className="listings-cards">
        {visible.length === 0 ? (
          <li className="muted">No listings for this filter.</li>
        ) : (
          visible.map((r) => (
            <ListingCard
              key={r.id}
              row={r}
              venues={venues}
              onPatch={(id, patch) => void patchRow(id, patch)}
              onRemove={(id) => void removeRow(id)}
            />
          ))
        )}
      </ul>
    </div>
  );
}
