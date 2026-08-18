import { useCallback, useEffect, useMemo, useState } from "react";
import {
  CatalogArea,
  CatalogGeography,
  CatalogListing,
  CatalogVenue,
  supabase,
} from "./supabase";
import { ConfirmDeleteDialog } from "./ConfirmDeleteDialog";

const DAY_LABELS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
const TYPE_OPTIONS = ["Drink Special", "Food Special", "Event"];

type Draft = Omit<CatalogListing, "id">;

function blank(venueName = "", geographyId: string | null = null): Draft {
  return {
    venue_name: venueName,
    geography_id: geographyId,
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
function listingGeographyId(
  row: CatalogListing,
  venues: CatalogVenue[]
): string | null {
  if (row.geography_id) return row.geography_id;
  return venues.find((v) => v.name === row.venue_name)?.geography_id ?? null;
}

function rowsInGeography(
  rows: CatalogListing[],
  geographyId: string,
  venues: CatalogVenue[]
): CatalogListing[] {
  return rows.filter(
    (r) => listingGeographyId(r, venues) === geographyId
  );
}

function prioritizedSorted(
  rows: CatalogListing[],
  geographyId: string,
  venues: CatalogVenue[]
): CatalogListing[] {
  return rowsInGeography(rows, geographyId, venues)
    .filter((r) => r.priority > 0)
    .sort(
      (a, b) =>
        a.priority - b.priority || a.venue_name.localeCompare(b.venue_name)
    );
}

function nextPriorityValue(
  rows: CatalogListing[],
  geographyId: string,
  venues: CatalogVenue[]
): number {
  const max = rowsInGeography(rows, geographyId, venues).reduce(
    (m, r) => (r.priority > m ? r.priority : m),
    0
  );
  return max + 1;
}

function venuesForGeography(
  venues: CatalogVenue[],
  geographyId: string
): CatalogVenue[] {
  return venues.filter((v) => v.geography_id === geographyId);
}

function areaNamesForGeography(
  areas: CatalogArea[],
  geographyId: string,
  rows: CatalogListing[],
  venues: CatalogVenue[]
): string[] {
  const names = new Set(
    areas
      .filter((a) => a.geography_id === geographyId)
      .map((a) => a.long_name)
  );
  for (const r of rows) {
    if (listingGeographyId(r, venues) === geographyId && r.area) {
      names.add(r.area);
    }
  }
  return [...names].sort();
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
  geographies,
  venues,
  allVenues,
  areaOptions,
  maxPriority,
  onPatch,
  onRemove,
  onTogglePriority,
  onMovePriority,
}: {
  row: CatalogListing;
  geographies: CatalogGeography[];
  venues: CatalogVenue[];
  allVenues: CatalogVenue[];
  areaOptions: string[];
  maxPriority: number;
  onPatch: PatchFn;
  onRemove: (id: string) => void;
  onTogglePriority: (id: string, enabled: boolean) => void;
  onMovePriority: (id: string, direction: "up" | "down") => void;
}) {
  const isPrioritized = row.priority > 0;
  const rowGeoId =
    listingGeographyId(row, allVenues) ?? geographies[0]?.id ?? "";

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
        Geography
        <select
          value={rowGeoId}
          onChange={(e) => {
            const geoId = e.target.value;
            const geoVenues = venuesForGeography(allVenues, geoId);
            const venueName = geoVenues.some((v) => v.name === row.venue_name)
              ? row.venue_name
              : (geoVenues[0]?.name ?? row.venue_name);
            const area =
              geoVenues.find((v) => v.name === venueName)?.area ?? row.area;
            onPatch(row.id, {
              geography_id: geoId,
              venue_name: venueName,
              area,
            });
          }}
        >
          {geographies.map((g) => (
            <option key={g.id} value={g.id}>
              {g.name}
            </option>
          ))}
        </select>
      </label>
      <label>
        Venue
        <select
          value={row.venue_name}
          onChange={(e) => {
            const name = e.target.value;
            const v = allVenues.find((x) => x.name === name);
            onPatch(row.id, {
              venue_name: name,
              geography_id: v?.geography_id ?? row.geography_id,
              area: v?.area ?? row.area,
            });
          }}
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
  const [geographies, setGeographies] = useState<CatalogGeography[]>([]);
  const [filterGeographyId, setFilterGeographyId] = useState<string>("");
  const [draft, setDraft] = useState<Draft>(blank());
  const [draftPriorityOn, setDraftPriorityOn] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [filterArea, setFilterArea] = useState<string>("");
  const [filterDay, setFilterDay] = useState<string>("");
  const [priorityMode, setPriorityMode] = useState(false);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<CatalogListing | null>(null);

  const load = useCallback(async () => {
    const [listingsRes, venuesRes, areasRes, geographiesRes] = await Promise.all([
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
      supabase
        .from("catalog_geographies")
        .select("*")
        .order("sort_order", { ascending: true }),
    ]);
    if (listingsRes.error) setError(listingsRes.error.message);
    else {
      setError(null);
      setRows((listingsRes.data ?? []) as CatalogListing[]);
    }
    const v = (venuesRes.data ?? []) as CatalogVenue[];
    if (!venuesRes.error) setVenues(v);
    if (!areasRes.error) {
      setAreas((areasRes.data ?? []) as CatalogArea[]);
    }
    const g = (geographiesRes.data ?? []) as CatalogGeography[];
    if (!geographiesRes.error) {
      setGeographies(g);
      setFilterGeographyId((prev) => {
        if (prev) return prev;
        const def = g.find((x) => x.is_default) ?? g[0];
        return def?.id ?? "";
      });
    }
    setDraft((d) => {
      if (d.geography_id) return d;
      const def = g.find((x) => x.is_default) ?? g[0];
      const geoId = def?.id ?? null;
      const firstVenue = geoId
        ? v.find((ven) => ven.geography_id === geoId)
        : v[0];
      return blank(firstVenue?.name ?? "", geoId);
    });
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const areaNames = useMemo(() => {
    if (!filterGeographyId) return [];
    return areaNamesForGeography(areas, filterGeographyId, rows, venues);
  }, [areas, filterGeographyId, rows, venues]);

  const draftGeographyId = draft.geography_id ?? filterGeographyId;

  const draftVenues = useMemo(
    () => (draftGeographyId ? venuesForGeography(venues, draftGeographyId) : venues),
    [venues, draftGeographyId]
  );

  function areasForVenue(venueName: string): string[] {
    const v = venues.find((x) => x.name === venueName);
    if (!v?.geography_id) return areaNames;
    return areaNamesForGeography(areas, v.geography_id, rows, venues);
  }

  const visible = useMemo(() => {
    let list = rows;
    if (filterGeographyId) {
      list = list.filter(
        (r) => listingGeographyId(r, venues) === filterGeographyId
      );
    }
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
  }, [rows, filterGeographyId, filterArea, filterDay, priorityMode, venues]);

  function maxPriorityForRow(row: CatalogListing): number {
    const geoId = listingGeographyId(row, venues);
    if (!geoId) return 0;
    return rowsInGeography(rows, geoId, venues).reduce(
      (m, r) => (r.priority > m ? r.priority : m),
      0
    );
  }

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
    const geoId = draft.geography_id ?? filterGeographyId;
    const priority =
      draftPriorityOn && geoId ? nextPriorityValue(rows, geoId, venues) : 0;
    const payload = {
      ...draft,
      geography_id: geoId || null,
      priority,
      listing_kind: kindFromLabels(draft.type_labels),
    };
    const { error: err } = await supabase.from("catalog_listings").insert(payload);
    setBusy(false);
    if (err) {
      setError(err.message);
      return;
    }
    const firstVenue = geoId
      ? venuesForGeography(venues, geoId)[0]
      : venues[0];
    setDraft(blank(firstVenue?.name ?? "", geoId || null));
    setDraftPriorityOn(false);
    setMsg("Row added");
    await load();
  }

  async function patchRow(id: string, patch: Partial<Draft>) {
    const fullPatch = { ...patch };
    if (patch.venue_name !== undefined) {
      const v = venues.find((x) => x.name === patch.venue_name);
      if (v?.geography_id) fullPatch.geography_id = v.geography_id;
    }
    await applyPatches([{ id, patch: fullPatch }]);
  }

  async function togglePriority(id: string, enabled: boolean) {
    const row = rows.find((r) => r.id === id);
    if (!row) return;
    const geoId = listingGeographyId(row, venues);
    if (!geoId) return;
    if (enabled) {
      if (row.priority > 0) return;
      await applyPatches([
        { id, patch: { priority: nextPriorityValue(rows, geoId, venues) } },
      ]);
      return;
    }
    if (row.priority <= 0) return;
    const remaining = prioritizedSorted(
      rows.filter((r) => r.id !== id),
      geoId,
      venues
    );
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
    const geoId = listingGeographyId(row, venues);
    if (!geoId) return;
    const targetRank = direction === "up" ? row.priority - 1 : row.priority + 1;
    if (targetRank < 1) return;
    const scoped = rowsInGeography(rows, geoId, venues);
    const other = scoped.find((r) => r.priority === targetRank);
    if (!other) return;
    await applyPatches([
      { id: row.id, patch: { priority: targetRank } },
      { id: other.id, patch: { priority: row.priority } },
    ]);
  }

  async function confirmDeleteListing() {
    if (!deleteTarget) return;
    const id = deleteTarget.id;
    const row = deleteTarget;
    setError(null);
    const { error: err } = await supabase
      .from("catalog_listings")
      .delete()
      .eq("id", id);
    if (err) {
      setError(err.message);
      return;
    }
    setDeleteTarget(null);
    const geoId = listingGeographyId(row, venues);
    if (row.priority > 0 && geoId) {
      const remaining = prioritizedSorted(
        rows.filter((r) => r.id !== id),
        geoId,
        venues
      );
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

  function listingDeleteLabel(row: CatalogListing): string {
    if (row.title.trim()) return row.title.trim();
    return row.venue_name;
  }

  return (
    <div className="listings-panel">
      <h2>Deals &amp; Events</h2>
      <p className="muted listings-help-desktop">
        Spreadsheet columns: venue, title, time, details, area, types, days
        (0=Sun…6=Sat), priority (1 = highest; 0 = none), active.
      </p>
      <p className="muted listings-help-mobile">
        Edit each deal as a card. Filter by geography, area, or day, then tap
        fields to update. Priority mode shows featured deals for the selected
        geography only.
      </p>

      <div className="listings-toolbar">
        <label>
          Geography{" "}
          <select
            value={filterGeographyId}
            onChange={(e) => {
              const geoId = e.target.value;
              setFilterGeographyId(geoId);
              setFilterArea("");
              const geoVenues = venuesForGeography(venues, geoId);
              const firstVenue = geoVenues[0];
              const scopedAreas = areaNamesForGeography(
                areas,
                geoId,
                rows,
                venues
              );
              setDraft({
                ...draft,
                geography_id: geoId,
                venue_name: firstVenue?.name ?? "",
                area: firstVenue?.area ?? scopedAreas[0] ?? draft.area,
              });
            }}
          >
            {geographies.map((g) => (
              <option key={g.id} value={g.id}>
                {g.name}
              </option>
            ))}
          </select>
        </label>
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
          Geography
          <select
            value={draftGeographyId}
            onChange={(e) => {
              const geoId = e.target.value;
              const geoVenues = venuesForGeography(venues, geoId);
              const firstVenue = geoVenues[0];
              const areaOptions = areaNamesForGeography(
                areas,
                geoId,
                rows,
                venues
              );
              setDraft({
                ...draft,
                geography_id: geoId,
                venue_name: firstVenue?.name ?? "",
                area: firstVenue?.area ?? areaOptions[0] ?? draft.area,
              });
            }}
            required
          >
            {geographies.map((g) => (
              <option key={g.id} value={g.id}>
                {g.name}
              </option>
            ))}
          </select>
        </label>
        <label>
          Venue
          <select
            value={draft.venue_name}
            onChange={(e) => {
              const name = e.target.value;
              const v = venues.find((ven) => ven.name === name);
              setDraft({
                ...draft,
                venue_name: name,
                geography_id: v?.geography_id ?? draft.geography_id,
                area: v?.area ?? draft.area,
              });
            }}
            required
          >
            {draftVenues.map((v) => (
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
          {draftPriorityOn && draftGeographyId
            ? ` (will be #${nextPriorityValue(rows, draftGeographyId, venues)})`
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
              <th>Geography</th>
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
            {visible.map((r) => {
              const rowGeoId =
                listingGeographyId(r, venues) ?? geographies[0]?.id ?? "";
              const rowVenues = rowGeoId
                ? venuesForGeography(venues, rowGeoId)
                : venues;
              const rowMaxPriority = maxPriorityForRow(r);
              return (
              <tr key={r.id}>
                <td>
                  <select
                    value={rowGeoId}
                    onChange={(e) => {
                      const geoId = e.target.value;
                      const geoVenues = venuesForGeography(venues, geoId);
                      const venueName = geoVenues.some(
                        (v) => v.name === r.venue_name
                      )
                        ? r.venue_name
                        : (geoVenues[0]?.name ?? r.venue_name);
                      const v = venues.find((x) => x.name === venueName);
                      void patchRow(r.id, {
                        geography_id: geoId,
                        venue_name: venueName,
                        area: v?.area ?? r.area,
                      });
                    }}
                  >
                    {geographies.map((g) => (
                      <option key={g.id} value={g.id}>
                        {g.name}
                      </option>
                    ))}
                  </select>
                </td>
                <td>
                  <select
                    value={r.venue_name}
                    onChange={(e) => {
                      const name = e.target.value;
                      const v = venues.find((x) => x.name === name);
                      void patchRow(r.id, {
                        venue_name: name,
                        geography_id: v?.geography_id ?? r.geography_id,
                        area: v?.area ?? r.area,
                      });
                    }}
                  >
                    {rowVenues.map((v) => (
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
                        canMoveDown={r.priority < rowMaxPriority}
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
                    onClick={() => setDeleteTarget(r)}
                  >
                    Del
                  </button>
                </td>
              </tr>
            );
            })}
          </tbody>
        </table>
      </div>

      {/* Mobile stacked cards */}
      <ul className="listings-cards">
        {visible.length === 0 ? (
          <li className="muted">No listings for this filter.</li>
        ) : (
          visible.map((r) => {
            const rowGeoId =
              listingGeographyId(r, venues) ?? geographies[0]?.id ?? "";
            const rowVenues = rowGeoId
              ? venuesForGeography(venues, rowGeoId)
              : venues;
            return (
            <ListingCard
              key={r.id}
              row={r}
              geographies={geographies}
              venues={rowVenues}
              allVenues={venues}
              areaOptions={areasForVenue(r.venue_name)}
              maxPriority={maxPriorityForRow(r)}
              onPatch={(id, patch) => void patchRow(id, patch)}
              onRemove={(id) => {
                const row = rows.find((r) => r.id === id);
                if (row) setDeleteTarget(row);
              }}
              onTogglePriority={(id, enabled) => void togglePriority(id, enabled)}
              onMovePriority={(id, dir) => void movePriority(id, dir)}
            />
            );
          })
        )}
      </ul>

      {deleteTarget && (
        <ConfirmDeleteDialog
          title="Delete deal?"
          titleId="listing-delete-title"
          message={
            <>
              Are you sure you want to delete{" "}
              <strong>{listingDeleteLabel(deleteTarget)}</strong>
              {deleteTarget.title.trim() ? (
                <>
                  {" "}
                  at <strong>{deleteTarget.venue_name}</strong>
                </>
              ) : null}
              ? This cannot be undone.
            </>
          }
          confirmLabel="Delete deal"
          onCancel={() => setDeleteTarget(null)}
          onConfirm={() => void confirmDeleteListing()}
        />
      )}
    </div>
  );
}
