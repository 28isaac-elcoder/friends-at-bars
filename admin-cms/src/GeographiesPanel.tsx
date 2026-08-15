import { useCallback, useEffect, useMemo, useState } from "react";
import {
  CatalogArea,
  CatalogGeography,
  supabase,
} from "./supabase";
import type { MapCoords } from "./MapPanel";

type GeoDraft = Omit<CatalogGeography, "id">;
type AreaDraft = Omit<CatalogArea, "id">;

const emptyGeo: GeoDraft = {
  name: "",
  latitude: 39.981997,
  longitude: -83.004427,
  radius_miles: 35,
  is_default: false,
  is_active: true,
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
  const [draft, setDraft] = useState<GeoDraft>(emptyGeo);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [areaDraft, setAreaDraft] = useState<AreaDraft>(emptyArea(""));
  const [editingAreaId, setEditingAreaId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

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
    setDraft({
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

  async function saveGeo(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    if (draft.is_default) {
      await supabase
        .from("catalog_geographies")
        .update({ is_default: false })
        .eq("is_default", true);
    }
    if (editingId) {
      const { error: err } = await supabase
        .from("catalog_geographies")
        .update(draft)
        .eq("id", editingId);
      if (err) {
        setError(err.message);
        return;
      }
    } else {
      const { data, error: err } = await supabase
        .from("catalog_geographies")
        .insert(draft)
        .select("id")
        .single();
      if (err) {
        setError(err.message);
        return;
      }
      if (data?.id) setSelectedId(data.id as string);
    }
    setDraft(emptyGeo);
    setEditingId(null);
    await load();
  }

  async function removeGeo(id: string) {
    if (!confirm("Delete this geography and its areas?")) return;
    const { error: err } = await supabase
      .from("catalog_geographies")
      .delete()
      .eq("id", id);
    if (err) setError(err.message);
    else {
      if (selectedId === id) setSelectedId(null);
      await load();
    }
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

  async function removeArea(id: string) {
    if (!confirm("Delete this area?")) return;
    const { error: err } = await supabase
      .from("catalog_areas")
      .delete()
      .eq("id", id);
    if (err) setError(err.message);
    else await load();
  }

  return (
    <div>
      <h2>{editingId ? "Edit geography" : "Add geography"}</h2>
      <form className="grid" onSubmit={saveGeo}>
        <label>
          Name
          <input
            value={draft.name}
            onChange={(e) => setDraft({ ...draft, name: e.target.value })}
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
              setDraft({ ...draft, latitude: Number(e.target.value) })
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
              setDraft({ ...draft, longitude: Number(e.target.value) })
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
              setDraft({ ...draft, radius_miles: Number(e.target.value) })
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
              setDraft({ ...draft, sort_order: Number(e.target.value) })
            }
          />
        </label>
        <label>
          <span>
            <input
              type="checkbox"
              checked={draft.is_default}
              onChange={(e) =>
                setDraft({ ...draft, is_default: e.target.checked })
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
                setDraft({ ...draft, is_active: e.target.checked })
              }
            />{" "}
            Active
          </span>
        </label>
        <label className="full">
          <div className="row-actions">
            <button type="submit">{editingId ? "Update" : "Create"}</button>
            {editingId && (
              <button
                type="button"
                onClick={() => {
                  setEditingId(null);
                  setDraft(emptyGeo);
                }}
              >
                Cancel
              </button>
            )}
          </div>
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
            {geos.map((g) => (
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
                  <button
                    type="button"
                    onClick={() => {
                      setEditingId(g.id);
                      setSelectedId(g.id);
                      setDraft({
                        name: g.name,
                        latitude: g.latitude,
                        longitude: g.longitude,
                        radius_miles: g.radius_miles,
                        is_default: g.is_default,
                        is_active: g.is_active,
                        sort_order: g.sort_order,
                      });
                    }}
                  >
                    Edit
                  </button>
                  <button
                    type="button"
                    className="danger"
                    onClick={() => void removeGeo(g.id)}
                  >
                    Delete
                  </button>
                </td>
              </tr>
            ))}
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
                <button type="submit">
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
                        onClick={() => void removeArea(a.id)}
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
    </div>
  );
}
