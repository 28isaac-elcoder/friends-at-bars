import { useCallback, useEffect, useMemo, useState } from "react";
import {
  CatalogArea,
  CatalogGeography,
  supabase,
} from "./supabase";
import type { MapCoords } from "./MapPanel";
import { ConfirmDeleteDialog } from "./ConfirmDeleteDialog";

type GeoDraft = Omit<CatalogGeography, "id">;
type AreaDraft = Omit<CatalogArea, "id">;

const emptyGeo: GeoDraft = {
  name: "",
  latitude: 39.981997,
  longitude: -83.004427,
  radius_miles: 35,
  is_default: false,
  is_active: true,
  is_test: false,
  sort_order: 0,
};

function emptyArea(geographyId: string): AreaDraft {
  return {
    geography_id: geographyId,
    long_name: "",
    short_name: "",
    accent_hex: "#387AEB",
    sort_order: 0,
    is_active: true,
  };
}

function geoToDraft(g: CatalogGeography): GeoDraft {
  return {
    name: g.name,
    latitude: g.latitude,
    longitude: g.longitude,
    radius_miles: g.radius_miles,
    is_default: g.is_default,
    is_active: g.is_active,
    is_test: g.is_test,
    sort_order: g.sort_order,
  };
}

function GeographyFields({
  draft,
  onChange,
}: {
  draft: GeoDraft;
  onChange: (draft: GeoDraft) => void;
}) {
  return (
    <>
      <label>
        Name
        <input
          value={draft.name}
          onChange={(e) => onChange({ ...draft, name: e.target.value })}
          required
          placeholder="Columbus"
        />
      </label>
      <label>
        Center latitude
        <input
          type="number"
          step="any"
          value={draft.latitude}
          onChange={(e) =>
            onChange({ ...draft, latitude: Number(e.target.value) })
          }
          required
        />
      </label>
      <label>
        Center longitude
        <input
          type="number"
          step="any"
          value={draft.longitude}
          onChange={(e) =>
            onChange({ ...draft, longitude: Number(e.target.value) })
          }
          required
        />
      </label>
      <label>
        Radius (miles)
        <input
          type="number"
          step="any"
          min={1}
          value={draft.radius_miles}
          onChange={(e) =>
            onChange({ ...draft, radius_miles: Number(e.target.value) })
          }
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
            checked={draft.is_default}
            onChange={(e) =>
              onChange({ ...draft, is_default: e.target.checked })
            }
          />{" "}
          Default geography
        </span>
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
          Test geography
        </span>
      </label>
    </>
  );
}

type GeographiesPanelProps = {
  seedCoords?: MapCoords | null;
  onSeedConsumed?: () => void;
};

export function GeographiesPanel({
  seedCoords = null,
  onSeedConsumed,
}: GeographiesPanelProps) {
  const [geos, setGeos] = useState<CatalogGeography[]>([]);
  const [areas, setAreas] = useState<CatalogArea[]>([]);
  const [addDraft, setAddDraft] = useState<GeoDraft>(emptyGeo);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editDraft, setEditDraft] = useState<GeoDraft | null>(null);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [areaDraft, setAreaDraft] = useState<AreaDraft>(emptyArea(""));
  const [editingAreaId, setEditingAreaId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [deleteGeoTarget, setDeleteGeoTarget] = useState<CatalogGeography | null>(
    null
  );
  const [deleteAreaTarget, setDeleteAreaTarget] = useState<CatalogArea | null>(
    null
  );

  const load = useCallback(async () => {
    const [gRes, aRes] = await Promise.all([
      supabase
        .from("catalog_geographies")
        .select("*")
        .order("sort_order", { ascending: true }),
      supabase
        .from("catalog_areas")
        .select("*")
        .order("sort_order", { ascending: true }),
    ]);
    if (gRes.error) setError(gRes.error.message);
    else {
      setError(null);
      setGeos((gRes.data ?? []) as CatalogGeography[]);
    }
    if (aRes.error) setError(aRes.error.message);
    else setAreas((aRes.data ?? []) as CatalogArea[]);
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  useEffect(() => {
    if (!seedCoords) return;
    setEditingId(null);
    setEditDraft(null);
    setAddDraft({
      ...emptyGeo,
      latitude: seedCoords.latitude,
      longitude: seedCoords.longitude,
    });
    onSeedConsumed?.();
  }, [seedCoords]);

  const selectedAreas = useMemo(
    () => areas.filter((a) => a.geography_id === selectedId),
    [areas, selectedId]
  );

  async function clearOtherDefaults(exceptId?: string) {
    let query = supabase
      .from("catalog_geographies")
      .update({ is_default: false })
      .eq("is_default", true);
    if (exceptId) query = query.neq("id", exceptId);
    await query;
  }

  async function createGeo(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    if (addDraft.is_default) await clearOtherDefaults();
    const { data, error: err } = await supabase
      .from("catalog_geographies")
      .insert(addDraft)
      .select("id")
      .single();
    if (err) {
      setError(err.message);
      return;
    }
    setAddDraft(emptyGeo);
    if (data?.id) setSelectedId(data.id as string);
    await load();
  }

  async function updateGeo(e: React.FormEvent, id: string) {
    e.preventDefault();
    if (!editDraft) return;
    setError(null);
    if (editDraft.is_default) await clearOtherDefaults(id);
    const { error: err } = await supabase
      .from("catalog_geographies")
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

  function startEdit(g: CatalogGeography) {
    if (editingId === g.id) {
      setEditingId(null);
      setEditDraft(null);
      return;
    }
    setEditingId(g.id);
    setEditDraft(geoToDraft(g));
  }

  function cancelEdit() {
    setEditingId(null);
    setEditDraft(null);
  }

  async function confirmDeleteGeo() {
    if (!deleteGeoTarget) return;
    const id = deleteGeoTarget.id;
    setError(null);
    const { error: err } = await supabase
      .from("catalog_geographies")
      .delete()
      .eq("id", id);
    if (err) {
      setError(err.message);
      return;
    }
    if (selectedId === id) setSelectedId(null);
    if (editingId === id) {
      setEditingId(null);
      setEditDraft(null);
    }
    setDeleteGeoTarget(null);
    await load();
  }

  async function confirmDeleteArea() {
    if (!deleteAreaTarget) return;
    const id = deleteAreaTarget.id;
    setError(null);
    const { error: err } = await supabase
      .from("catalog_areas")
      .delete()
      .eq("id", id);
    if (err) {
      setError(err.message);
      return;
    }
    if (editingAreaId === id) {
      setEditingAreaId(null);
      if (selectedId) setAreaDraft(emptyArea(selectedId));
    }
    setDeleteAreaTarget(null);
    await load();
  }

  async function saveArea(e: React.FormEvent) {
    e.preventDefault();
    if (!selectedId) return;
    setError(null);
    const payload = { ...areaDraft, geography_id: selectedId };
    if (editingAreaId) {
      const { error: err } = await supabase
        .from("catalog_areas")
        .update(payload)
        .eq("id", editingAreaId);
      if (err) {
        setError(err.message);
        return;
      }
    } else {
      const { error: err } = await supabase.from("catalog_areas").insert(payload);
      if (err) {
        setError(err.message);
        return;
      }
    }
    setAreaDraft(emptyArea(selectedId));
    setEditingAreaId(null);
    await load();
  }

  return (
    <div className="geographies-panel">
      <h2>Add geography</h2>
      <form className="grid" onSubmit={createGeo}>
        <GeographyFields draft={addDraft} onChange={setAddDraft} />
        <label className="full">
          <button type="submit" className="btn-primary">
            Create
          </button>
        </label>
      </form>

      {error && <p className="error">{error}</p>}

      <div className="table-scroll">
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Center</th>
              <th>Radius</th>
              <th>Flags</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {geos.map((g) =>
              editingId === g.id && editDraft ? (
                <tr key={g.id} className="venue-row-editing">
                  <td colSpan={5}>
                    <form
                      className="venue-inline-edit"
                      onSubmit={(e) => void updateGeo(e, g.id)}
                    >
                      <div className="venue-inline-edit-header">
                        <strong>Editing {g.name}</strong>
                      </div>
                      <div className="grid venue-inline-edit-grid">
                        <GeographyFields
                          draft={editDraft}
                          onChange={setEditDraft}
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
                <tr
                  key={g.id}
                  className={selectedId === g.id ? "row-selected" : undefined}
                >
                  <td>{g.name}</td>
                  <td>
                    {g.latitude.toFixed(5)}, {g.longitude.toFixed(5)}
                  </td>
                  <td>{g.radius_miles} mi</td>
                  <td>
                    {g.is_active ? "active" : "off"}
                    {g.is_test ? " · test" : ""}
                    {g.is_default ? " · default" : ""}
                  </td>
                  <td className="row-actions">
                    <button
                      type="button"
                      onClick={() => {
                        setSelectedId(g.id);
                        setAreaDraft(emptyArea(g.id));
                        setEditingAreaId(null);
                      }}
                    >
                      Areas
                    </button>
                    <button type="button" onClick={() => startEdit(g)}>
                      Edit
                    </button>
                    <button
                      type="button"
                      className="danger"
                      onClick={() => setDeleteGeoTarget(g)}
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

      {selectedId && (
        <div className="geo-areas">
          <h2>
            Areas — {geos.find((g) => g.id === selectedId)?.name ?? "Geography"}
          </h2>
          <form className="grid" onSubmit={saveArea}>
            <label>
              Long name
              <input
                value={areaDraft.long_name}
                onChange={(e) =>
                  setAreaDraft({ ...areaDraft, long_name: e.target.value })
                }
                required
                placeholder="Grandview / Breweries"
              />
            </label>
            <label>
              Short name
              <input
                value={areaDraft.short_name}
                onChange={(e) =>
                  setAreaDraft({ ...areaDraft, short_name: e.target.value })
                }
                required
                placeholder="Grand-Brew"
              />
            </label>
            <label>
              Color
              <input
                type="color"
                value={areaDraft.accent_hex}
                onChange={(e) =>
                  setAreaDraft({ ...areaDraft, accent_hex: e.target.value })
                }
              />
            </label>
            <label>
              Sort order
              <input
                type="number"
                value={areaDraft.sort_order}
                onChange={(e) =>
                  setAreaDraft({
                    ...areaDraft,
                    sort_order: Number(e.target.value),
                  })
                }
              />
            </label>
            <label className="full">
              <div className="row-actions">
                <button type="submit" className="btn-primary">
                  {editingAreaId ? "Update area" : "Add area"}
                </button>
                {editingAreaId && (
                  <button
                    type="button"
                    onClick={() => {
                      setEditingAreaId(null);
                      setAreaDraft(emptyArea(selectedId));
                    }}
                  >
                    Cancel
                  </button>
                )}
              </div>
            </label>
          </form>
          <div className="table-scroll">
            <table>
              <thead>
                <tr>
                  <th>Long</th>
                  <th>Short</th>
                  <th>Color</th>
                  <th />
                </tr>
              </thead>
              <tbody>
                {selectedAreas.map((a) => (
                  <tr key={a.id}>
                    <td>{a.long_name}</td>
                    <td>{a.short_name}</td>
                    <td>
                      <span
                        className="color-swatch"
                        style={{ background: a.accent_hex }}
                      />{" "}
                      {a.accent_hex}
                    </td>
                    <td className="row-actions">
                      <button
                        type="button"
                        onClick={() => {
                          setEditingAreaId(a.id);
                          setAreaDraft({
                            geography_id: a.geography_id,
                            long_name: a.long_name,
                            short_name: a.short_name,
                            accent_hex: a.accent_hex,
                            sort_order: a.sort_order,
                            is_active: a.is_active,
                          });
                        }}
                      >
                        Edit
                      </button>
                      <button
                        type="button"
                        className="danger"
                        onClick={() => setDeleteAreaTarget(a)}
                      >
                        Delete
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {deleteGeoTarget && (
        <ConfirmDeleteDialog
          title="Delete geography?"
          titleId="geography-delete-title"
          message={
            <>
              Are you sure you want to delete{" "}
              <strong>{deleteGeoTarget.name}</strong> and all of its areas? This
              cannot be undone.
            </>
          }
          confirmLabel="Delete geography"
          onCancel={() => setDeleteGeoTarget(null)}
          onConfirm={() => void confirmDeleteGeo()}
        />
      )}

      {deleteAreaTarget && (
        <ConfirmDeleteDialog
          title="Delete area?"
          titleId="area-delete-title"
          message={
            <>
              Are you sure you want to delete{" "}
              <strong>{deleteAreaTarget.long_name}</strong>? This cannot be
              undone.
            </>
          }
          confirmLabel="Delete area"
          onCancel={() => setDeleteAreaTarget(null)}
          onConfirm={() => void confirmDeleteArea()}
        />
      )}
    </div>
  );
}
