import { useCallback, useEffect, useMemo, useState } from "react";
import {
  CatalogArea,
  CatalogListing,
  CatalogVenue,
  supabase,
} from "./supabase";

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

/** Lower number = higher rank (1 is top). 0 = not prioritized. */
function prioritizedSorted(rows: CatalogListing[]): CatalogListing[] {
  return rows
    .filter((r) => r.priority > 0)
    .sort((a, b) => a.priority - b.priority || a.venue_name.localeCompare(b.venue_name));
}

function nextPriorityValue(rows: CatalogListing[]): number {
  const max = rows.reduce((m, r) => (r.priority > m ? r.priority : m), 0);
  return max + 1;
}

type PatchFn = (id: string, patch: Partial<Draft>) => void;

function PriorityRankControls({
  priority,
  onMoveUp,
  onMoveDown,
  canMoveUp,
  canMoveDown,
}: {
  priority: number;
  onMoveUp: () => void;
  onMoveDown: () => void;
  canMoveUp: boolean;
  canMoveDown: boolean;
}) {
  return (
    <div className="priority-rank-controls" title="Priority rank (1 = highest)">
      <button
        type="button"
        className="priority-rank-btn"
        disabled={!canMoveDown}
        onClick={onMoveDown}
        aria-label="Lower priority"
      >
        ↓
      </button>
      <span className="priority-rank-num">{priority}</span>
      <button
        type="button"
        className="priority-rank-btn"
        disabled={!canMoveUp}
        onClick={onMoveUp}
        aria-label="Raise priority"
      >
        ↑
      </button>
    </div>
  );
}

/** Stacked editable card — primary mobile editing surface for Deals/Events. */
function ListingCard({
  row,
  venues,
  areaOptions,
  maxPriority,
  onPatch,
  onRemove,
  onTogglePriority,
  onMovePriority,
}: {
  row: CatalogListing;
  venues: CatalogVenue[];
  areaOptions: string[];
  maxPriority: number;
  onPatch: PatchFn;
  onRemove: (id: string) => void;
  onTogglePriority: (id: string, enabled: boolean) => void;
  onMovePriority: (id: string, direction: "up" | "down") => void;
}) {
  const isPrioritized = row.priority > 0;

  return (
    <li className={`listing-card${isPrioritized ? " listing-card--priority" : ""}`}>
      {isPrioritized && (
        <PriorityRankControls
          priority={row.priority}
          canMoveUp={row.priority > 1}
          canMoveDown={row.priority < maxPriority}
          onMoveUp={() => onMovePriority(row.id, "up")}
          onMoveDown={() => onMovePriority(row.id, "down")}
        />
      )}
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
          {areaOptions.map((a) => (
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
        <label className="inline-check listing-card-priority-toggle">
          <input
            type="checkbox"
            checked={isPrioritized}
            onChange={(e) => onTogglePriority(row.id, e.target.checked)}
          />
          Priority
          {isPrioritized ? ` (#${row.priority})` : ""}
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
  const [areas, setAreas] = useState<CatalogArea[]>([]);
  const [draft, setDraft] = useState<Draft>(blank());
  const [draftPriorityOn, setDraftPriorityOn] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [filterArea, setFilterArea] = useState<string>("");
  const [filterDay, setFilterDay] = useState<string>("");
  const [priorityMode, setPriorityMode] = useState(false);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);

  const load = useCallback(async () => {
    const [listingsRes, venuesRes, areasRes] = await Promise.all([
      supabase
        .from("catalog_listings")
        .select("*")
        .order("area", { ascending: true })
        .order("venue_name", { ascending: true }),
      supabase
        .from("catalog_venues")
        .select("*")
        .order("name", { ascending: true }),
      supabase
        .from("catalog_areas")
        .select("*")
        .order("sort_order", { ascending: true }),
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
    if (!areasRes.error) {
      setAreas((areasRes.data ?? []) as CatalogArea[]);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const areaNames = useMemo(() => {
    const names = new Set(areas.map((a) => a.long_name));
    for (const r of rows) {
      if (r.area) names.add(r.area);
    }
    return [...names].sort();
  }, [areas, rows]);

  function areasForVenue(venueName: string): string[] {
    const v = venues.find((x) => x.name === venueName);
    if (!v?.geography_id) return areaNames;
    const scoped = areas
      .filter((a) => a.geography_id === v.geography_id)
      .map((a) => a.long_name);
    if (v.area && !scoped.includes(v.area)) scoped.push(v.area);
    return scoped.length ? scoped : areaNames;
  }

  const visible = useMemo(() => {
    let list = rows;
    if (filterArea) {
      list = list.filter((r) => r.area === filterArea);
    }
    if (filterDay !== "") {
      const day = Number(filterDay);
      list = list.filter(
        (r) => r.days_of_week.length === 0 || r.days_of_week.includes(day)
      );
    }
    if (priorityMode) {
      list = list.filter((r) => r.priority > 0);
    }
    return [...list].sort((a, b) => {
      const aP = a.priority > 0;
      const bP = b.priority > 0;
      if (aP && bP) {
        if (a.priority !== b.priority) return a.priority - b.priority;
      } else if (aP !== bP) {
        return aP ? -1 : 1;
      }
      if (a.area !== b.area) return a.area.localeCompare(b.area);
      return a.venue_name.localeCompare(b.venue_name);
    });
  }, [rows, filterArea, filterDay, priorityMode]);

  const maxPriority = useMemo(() => {
    return rows.reduce((m, r) => (r.priority > m ? r.priority : m), 0);
  }, [rows]);

  async function applyPatches(
    updates: { id: string; patch: Partial<Draft> }[]
  ) {
    setError(null);
    for (const { id, patch } of updates) {
      const { error: err } = await supabase
        .from("catalog_listings")
        .update(patch)
        .eq("id", id);
      if (err) {
        setError(err.message);
        return;
      }
    }
    await load();
  }

  async function createRow(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    setMsg(null);
    const priority = draftPriorityOn ? nextPriorityValue(rows) : 0;
    const payload = {
      ...draft,
      priority,
      listing_kind: kindFromLabels(draft.type_labels),
    };
    const { error: err } = await supabase.from("catalog_listings").insert(payload);
    setBusy(false);
    if (err) {
      setError(err.message);
      return;
    }
    setDraft(blank(draft.venue_name));
    setDraftPriorityOn(false);
    setMsg("Row added");
    await load();
  }

  async function patchRow(id: string, patch: Partial<Draft>) {
    await applyPatches([{ id, patch }]);
  }

  async function togglePriority(id: string, enabled: boolean) {
    const row = rows.find((r) => r.id === id);
    if (!row) return;
    if (enabled) {
      if (row.priority > 0) return;
      await applyPatches([{ id, patch: { priority: nextPriorityValue(rows) } }]);
      return;
    }
    if (row.priority <= 0) return;
    // Clear this deal and renumber remaining priorities 1…n with no gaps.
    const remaining = prioritizedSorted(rows.filter((r) => r.id !== id));
    const updates: { id: string; patch: Partial<Draft> }[] = [
      { id, patch: { priority: 0 } },
      ...remaining.map((r, i) => ({
        id: r.id,
        patch: { priority: i + 1 } as Partial<Draft>,
      })),
    ];
    await applyPatches(updates);
  }

  async function movePriority(id: string, direction: "up" | "down") {
    const row = rows.find((r) => r.id === id);
    if (!row || row.priority <= 0) return;
    const targetRank = direction === "up" ? row.priority - 1 : row.priority + 1;
    if (targetRank < 1) return;
    const other = rows.find((r) => r.priority === targetRank);
    if (!other) return;
    await applyPatches([
      { id: row.id, patch: { priority: targetRank } },
      { id: other.id, patch: { priority: row.priority } },
    ]);
  }

  async function removeRow(id: string) {
    if (!confirm("Delete this listing?")) return;
    const row = rows.find((r) => r.id === id);
    const { error: err } = await supabase
      .from("catalog_listings")
      .delete()
      .eq("id", id);
    if (err) {
      setError(err.message);
      return;
    }
    if (row && row.priority > 0) {
      const remaining = prioritizedSorted(rows.filter((r) => r.id !== id));
      await applyPatches(
        remaining.map((r, i) => ({
          id: r.id,
          patch: { priority: i + 1 },
        }))
      );
    } else {
      await load();
    }
  }

  return (
    <div className="listings-panel">
      <h2>Deals &amp; Events</h2>
      <p className="muted listings-help-desktop">
        Spreadsheet columns: venue, title, time, details, area, types, days
        (0=Sun…6=Sat), priority (1 = highest; 0 = none), active.
      </p>
      <p className="muted listings-help-mobile">
        Edit each deal as a card. Filter by area or day, then tap fields to
        update. Use Priority mode to reorder featured deals.
      </p>

      <div className="listings-toolbar">
        <label>
          Filter area{" "}
          <select
            value={filterArea}
            onChange={(e) => setFilterArea(e.target.value)}
          >
            <option value="">All areas</option>
            {areaNames.map((a) => (
              <option key={a} value={a}>
                {a}
              </option>
            ))}
          </select>
        </label>
        <label>
          Filter day{" "}
          <select
            value={filterDay}
            onChange={(e) => setFilterDay(e.target.value)}
          >
            <option value="">All days</option>
            {DAY_LABELS.map((label, day) => (
              <option key={label} value={String(day)}>
                {label}
              </option>
            ))}
          </select>
        </label>
        <button
          type="button"
          className={`priority-mode-btn${priorityMode ? " active" : ""}`}
          onClick={() => setPriorityMode((v) => !v)}
        >
          Priority mode
        </button>
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
            {areasForVenue(draft.venue_name).map((a) => (
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
        <label className="full inline-check draft-priority-toggle">
          <input
            type="checkbox"
            checked={draftPriorityOn}
            onChange={(e) => setDraftPriorityOn(e.target.checked)}
          />
          Priority
          {draftPriorityOn
            ? ` (will be #${nextPriorityValue(rows)})`
            : " (off)"}
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
        <div className="full">
          <button type="submit" className="btn-add-deal" disabled={busy}>
            {busy ? "Adding…" : "Add a Deal"}
          </button>
        </div>
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
              <th>Priority</th>
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
                    {areasForVenue(r.venue_name).map((a) => (
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
                  <div className="table-priority-cell">
                    <label className="inline-check">
                      <input
                        type="checkbox"
                        checked={r.priority > 0}
                        onChange={(e) =>
                          void togglePriority(r.id, e.target.checked)
                        }
                      />
                      On
                    </label>
                    {r.priority > 0 && (
                      <PriorityRankControls
                        priority={r.priority}
                        canMoveUp={r.priority > 1}
                        canMoveDown={r.priority < maxPriority}
                        onMoveUp={() => void movePriority(r.id, "up")}
                        onMoveDown={() => void movePriority(r.id, "down")}
                      />
                    )}
                  </div>
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
              areaOptions={areasForVenue(r.venue_name)}
              maxPriority={maxPriority}
              onPatch={(id, patch) => void patchRow(id, patch)}
              onRemove={(id) => void removeRow(id)}
              onTogglePriority={(id, enabled) => void togglePriority(id, enabled)}
              onMovePriority={(id, dir) => void movePriority(id, dir)}
            />
          ))
        )}
      </ul>
    </div>
  );
}
