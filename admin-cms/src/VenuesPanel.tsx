import { useCallback, useEffect, useState } from "react";
import { CatalogArea, CatalogGeography, CatalogVenue, supabase } from "./supabase";
import type { MapCoords } from "./MapPanel";
import { ConfirmDeleteDialog } from "./ConfirmDeleteDialog";
import {
  DEFAULT_FOOTPRINT_HALF_M,
  FOOTPRINT_CORNER_LABELS,
  defaultVenueFootprint,
  normalizeFootprint,
  type LatLng,
} from "./venueFootprint";

type VenueDraft = Omit<CatalogVenue, "id">;

const empty: VenueDraft = {
  name: "",
  area: "North Campus",
  geography_id: null,
  latitude: 40.0,
  longitude: -83.01,
  radius_m: 100,
  footprint: defaultVenueFootprint(40.0, -83.01),
  is_test: false,
  is_active: true,
  sort_order: 0,
};

type VenuesPanelProps = {
  seedCoords?: MapCoords | null;
  onSeedConsumed?: () => void;
};

function FootprintFields({
  draft,
  onChange,
}: {
  draft: VenueDraft;
  onChange: (draft: VenueDraft) => void;
}) {
  const corners = normalizeFootprint(
    draft.footprint,
    draft.latitude,
    draft.longitude
  );

  function setCorner(index: number, next: LatLng) {
    const updated = corners.map((c, i) => (i === index ? next : c));
    onChange({ ...draft, footprint: updated });
  }

  return (
    <div className="full footprint-fields">
      <div className="footprint-header">
        <strong>Footprint corners</strong>
        <span className="muted">
          NW → NE → SE → SW (presence = inside polygon; sticky ≤15 m)
        </span>
        <button
          type="button"
          onClick={() =>
            onChange({
              ...draft,
              footprint: defaultVenueFootprint(
                draft.latitude,
                draft.longitude,
                DEFAULT_FOOTPRINT_HALF_M
              ),
            })
          }
        >
          Reset {DEFAULT_FOOTPRINT_HALF_M}m square
        </button>
      </div>
      <div className="footprint-grid">
        {FOOTPRINT_CORNER_LABELS.map((label, index) => (
          <div key={label} className="footprint-corner">
            <span>{label}</span>
            <label>
              Lat
              <input
                type="number"
                step="any"
                value={corners[index]?.lat ?? 0}
                onChange={(e) =>
                  setCorner(index, {
                    lat: Number(e.target.value),
                    lng: corners[index]?.lng ?? 0,
                  })
                }
                required
              />
            </label>
            <label>
              Lng
              <input
                type="number"
                step="any"
                value={corners[index]?.lng ?? 0}
                onChange={(e) =>
                  setCorner(index, {
                    lat: corners[index]?.lat ?? 0,
                    lng: Number(e.target.value),
                  })
                }
                required
              />
            </label>
          </div>
        ))}
      </div>
    </div>
  );
}

function VenueFields({
  draft,
  onChange,
  geos,
  areas,
}: {
  draft: VenueDraft;
  onChange: (draft: VenueDraft) => void;
  geos: CatalogGeography[];
  areas: CatalogArea[];
}) {
  return (
    <>
      <label>
        Name
        <input
          value={draft.name}
          onChange={(e) => onChange({ ...draft, name: e.target.value })}
          required
        />
      </label>
      <label>
        Geography
        <select
          value={draft.geography_id ?? ""}
          onChange={(e) => {
            const geography_id = e.target.value || null;
            const firstArea = areas.find((a) => a.geography_id === geography_id);
            onChange({
              ...draft,
              geography_id,
              area: firstArea?.long_name ?? draft.area,
            });
          }}
          required
        >
          <option value="" disabled>
            Select geography
          </option>
          {geos.map((g) => (
            <option key={g.id} value={g.id}>
              {g.name}
            </option>
          ))}
        </select>
      </label>
      <label>
        Area
        <select
          value={draft.area}
          onChange={(e) => onChange({ ...draft, area: e.target.value })}
          required
        >
          {areas
            .filter((a) => a.geography_id === draft.geography_id)
            .map((a) => (
              <option key={a.id} value={a.long_name}>
                {a.long_name}
              </option>
            ))}
        </select>
      </label>
      <label>
        Center latitude
        <input
          type="number"
          step="any"
          value={draft.latitude}
          onChange={(e) => {
            const latitude = Number(e.target.value);
            onChange({
              ...draft,
              latitude,
              footprint: draft.footprint?.length
                ? draft.footprint
                : defaultVenueFootprint(latitude, draft.longitude),
            });
          }}
          required
        />
      </label>
      <label>
        Center longitude
        <input
          type="number"
          step="any"
          value={draft.longitude}
          onChange={(e) => {
            const longitude = Number(e.target.value);
            onChange({
              ...draft,
              longitude,
              footprint: draft.footprint?.length
                ? draft.footprint
                : defaultVenueFootprint(draft.latitude, longitude),
            });
          }}
          required
        />
      </label>
      <label>
        Sort order
        <input
          type="number"
          value={draft.sort_order}
          onChange={(e) =>
            onChange({ ...draft, sort_order: Number(e.target.value) })
          }
        />
      </label>
      <label>
        <span>
          <input
            type="checkbox"
            checked={draft.is_active}
            onChange={(e) =>
              onChange({ ...draft, is_active: e.target.checked })
            }
          />{" "}
          Active
        </span>
      </label>
      <label>
        <span>
          <input
            type="checkbox"
            checked={draft.is_test}
            onChange={(e) => onChange({ ...draft, is_test: e.target.checked })}
          />{" "}
          Test venue
        </span>
      </label>
      <FootprintFields draft={draft} onChange={onChange} />
    </>
  );
}

function venueToDraft(v: CatalogVenue): VenueDraft {
  return {
    name: v.name,
    area: v.area,
    geography_id: v.geography_id,
    latitude: v.latitude,
    longitude: v.longitude,
    radius_m: v.radius_m,
    footprint: normalizeFootprint(v.footprint, v.latitude, v.longitude),
    is_test: v.is_test,
    is_active: v.is_active,
    sort_order: v.sort_order,
  };
}

function freshAddDraft(
  geos: CatalogGeography[],
  areas: CatalogArea[]
): VenueDraft {
  const def = geos.find((g) => g.is_default) ?? geos[0];
  const firstArea = def
    ? areas.find((a) => a.geography_id === def.id)
    : undefined;
  return {
    ...empty,
    geography_id: def?.id ?? null,
    area: firstArea?.long_name ?? empty.area,
    footprint: defaultVenueFootprint(empty.latitude, empty.longitude),
  };
}

export function VenuesPanel({
  seedCoords = null,
  onSeedConsumed,
}: VenuesPanelProps) {
  const [rows, setRows] = useState<CatalogVenue[]>([]);
  const [geos, setGeos] = useState<CatalogGeography[]>([]);
  const [areas, setAreas] = useState<CatalogArea[]>([]);
  const [addDraft, setAddDraft] = useState<VenueDraft>(empty);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editDraft, setEditDraft] = useState<VenueDraft | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<CatalogVenue | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    const [vRes, gRes, aRes] = await Promise.all([
      supabase
        .from("catalog_venues")
        .select("*")
        .order("sort_order", { ascending: true }),
      supabase
        .from("catalog_geographies")
        .select("*")
        .order("sort_order", { ascending: true }),
      supabase
        .from("catalog_areas")
        .select("*")
        .order("sort_order", { ascending: true }),
    ]);
    if (vRes.error) setError(vRes.error.message);
    else {
      setError(null);
      setRows((vRes.data ?? []) as CatalogVenue[]);
    }
    if (!gRes.error) setGeos((gRes.data ?? []) as CatalogGeography[]);
    if (!aRes.error) setAreas((aRes.data ?? []) as CatalogArea[]);
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  useEffect(() => {
    if (!geos.length || addDraft.geography_id) return;
    const def = geos.find((g) => g.is_default) ?? geos[0];
    const firstArea = areas.find((a) => a.geography_id === def.id);
    setAddDraft((d) => ({
      ...d,
      geography_id: def.id,
      area: firstArea?.long_name ?? d.area,
    }));
  }, [geos, areas, addDraft.geography_id]);

  useEffect(() => {
    if (!seedCoords) return;
    setEditingId(null);
    setEditDraft(null);
    setAddDraft({
      ...freshAddDraft(geos, areas),
      latitude: seedCoords.latitude,
      longitude: seedCoords.longitude,
      footprint: defaultVenueFootprint(
        seedCoords.latitude,
        seedCoords.longitude
      ),
    });
    onSeedConsumed?.();
  }, [seedCoords]); // onSeedConsumed clears seed; omit from deps to avoid loops

  async function createVenue(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    const { error: err } = await supabase.from("catalog_venues").insert(addDraft);
    if (err) {
      setError(err.message);
      return;
    }
    setAddDraft(freshAddDraft(geos, areas));
    await load();
  }

  async function updateVenue(e: React.FormEvent, id: string) {
    e.preventDefault();
    if (!editDraft) return;
    setError(null);
    const { error: err } = await supabase
      .from("catalog_venues")
      .update(editDraft)
      .eq("id", id);
    if (err) {
      setError(err.message);
      return;
    }
    setEditingId(null);
    setEditDraft(null);
    await load();
  }

  function startEdit(v: CatalogVenue) {
    if (editingId === v.id) {
      setEditingId(null);
      setEditDraft(null);
      return;
    }
    setEditingId(v.id);
    setEditDraft(venueToDraft(v));
  }

  function cancelEdit() {
    setEditingId(null);
    setEditDraft(null);
  }

  async function confirmDelete() {
    if (!deleteTarget) return;
    setError(null);
    const { error: err } = await supabase
      .from("catalog_venues")
      .delete()
      .eq("id", deleteTarget.id);
    if (err) {
      setError(err.message);
      return;
    }
    if (editingId === deleteTarget.id) {
      setEditingId(null);
      setEditDraft(null);
    }
    setDeleteTarget(null);
    await load();
  }

  return (
    <div className="venues-panel">
      <h2>Add venue</h2>
      <form className="grid" onSubmit={createVenue}>
        <VenueFields
          draft={addDraft}
          onChange={setAddDraft}
          geos={geos}
          areas={areas}
        />
        <label className="full">
          <button type="submit">Create</button>
        </label>
      </form>

      {error && <p className="error">{error}</p>}

      <div className="table-scroll">
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Geography</th>
              <th>Area</th>
              <th>Lat / Lng</th>
              <th>Flags</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {rows.map((v) =>
              editingId === v.id && editDraft ? (
                <tr key={v.id} className="venue-row-editing">
                  <td colSpan={6}>
                    <form
                      className="venue-inline-edit"
                      onSubmit={(e) => void updateVenue(e, v.id)}
                    >
                      <div className="venue-inline-edit-header">
                        <strong>Editing {v.name}</strong>
                      </div>
                      <div className="grid venue-inline-edit-grid">
                        <VenueFields
                          draft={editDraft}
                          onChange={setEditDraft}
                          geos={geos}
                          areas={areas}
                        />
                      </div>
                      <div className="row-actions venue-inline-edit-actions">
                        <button type="submit">Save changes</button>
                        <button type="button" onClick={cancelEdit}>
                          Cancel
                        </button>
                      </div>
                    </form>
                  </td>
                </tr>
              ) : (
                <tr key={v.id}>
                  <td>{v.name}</td>
                  <td>
                    {geos.find((g) => g.id === v.geography_id)?.name ?? "—"}
                  </td>
                  <td>{v.area}</td>
                  <td>
                    {v.latitude.toFixed(5)}, {v.longitude.toFixed(5)}
                  </td>
                  <td>
                    {v.is_active ? "active" : "off"}
                    {v.is_test ? " · test" : ""}
                  </td>
                  <td className="row-actions">
                    <button type="button" onClick={() => startEdit(v)}>
                      Edit
                    </button>
                    <button
                      type="button"
                      className="danger"
                      onClick={() => setDeleteTarget(v)}
                    >
                      Delete
                    </button>
                  </td>
                </tr>
              )
            )}
          </tbody>
        </table>
      </div>

      {deleteTarget && (
        <ConfirmDeleteDialog
          title="Delete venue?"
          titleId="venue-delete-title"
          message={
            <>
              Are you sure you want to delete{" "}
              <strong>{deleteTarget.name}</strong>? This cannot be undone.
            </>
          }
          confirmLabel="Delete venue"
          onCancel={() => setDeleteTarget(null)}
          onConfirm={() => void confirmDelete()}
        />
      )}
    </div>
  );
}
