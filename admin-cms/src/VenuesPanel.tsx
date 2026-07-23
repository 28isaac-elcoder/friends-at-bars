import { useCallback, useEffect, useState } from "react";
import { CatalogVenue, supabase } from "./supabase";
import type { MapCoords } from "./MapPanel";

const empty: Omit<CatalogVenue, "id"> = {
  name: "",
  area: "North Campus",
  latitude: 40.0,
  longitude: -83.01,
  radius_m: 100,
  is_test: false,
  is_active: true,
  sort_order: 0,
};

type VenuesPanelProps = {
  seedCoords?: MapCoords | null;
  onSeedConsumed?: () => void;
};

export function VenuesPanel({
  seedCoords = null,
  onSeedConsumed,
}: VenuesPanelProps) {
  const [rows, setRows] = useState<CatalogVenue[]>([]);
  const [draft, setDraft] = useState(empty);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    const { data, error: err } = await supabase
      .from("catalog_venues")
      .select("*")
      .order("sort_order", { ascending: true });
    if (err) setError(err.message);
    else {
      setError(null);
      setRows((data ?? []) as CatalogVenue[]);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  useEffect(() => {
    if (!seedCoords) return;
    setEditingId(null);
    setDraft({
      ...empty,
      latitude: seedCoords.latitude,
      longitude: seedCoords.longitude,
    });
    onSeedConsumed?.();
  }, [seedCoords]); // onSeedConsumed clears seed; omit from deps to avoid loops


  async function save(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    if (editingId) {
      const { error: err } = await supabase
        .from("catalog_venues")
        .update(draft)
        .eq("id", editingId);
      if (err) {
        setError(err.message);
        return;
      }
    } else {
      const { error: err } = await supabase.from("catalog_venues").insert(draft);
      if (err) {
        setError(err.message);
        return;
      }
    }
    setDraft(empty);
    setEditingId(null);
    await load();
  }

  function startEdit(v: CatalogVenue) {
    setEditingId(v.id);
    setDraft({
      name: v.name,
      area: v.area,
      latitude: v.latitude,
      longitude: v.longitude,
      radius_m: v.radius_m,
      is_test: v.is_test,
      is_active: v.is_active,
      sort_order: v.sort_order,
    });
  }

  async function remove(id: string) {
    if (!confirm("Delete this venue?")) return;
    const { error: err } = await supabase
      .from("catalog_venues")
      .delete()
      .eq("id", id);
    if (err) setError(err.message);
    else await load();
  }

  return (
    <div>
      <h2>{editingId ? "Edit venue" : "Add venue"}</h2>
      <form className="grid" onSubmit={save}>
        <label>
          Name
          <input
            value={draft.name}
            onChange={(e) => setDraft({ ...draft, name: e.target.value })}
            required
          />
        </label>
        <label>
          Area
          <input
            value={draft.area}
            onChange={(e) => setDraft({ ...draft, area: e.target.value })}
            required
          />
        </label>
        <label>
          Latitude
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
          Longitude
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
          Radius (m)
          <input
            type="number"
            value={draft.radius_m}
            onChange={(e) =>
              setDraft({ ...draft, radius_m: Number(e.target.value) })
            }
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
              checked={draft.is_active}
              onChange={(e) =>
                setDraft({ ...draft, is_active: e.target.checked })
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
              onChange={(e) =>
                setDraft({ ...draft, is_test: e.target.checked })
              }
            />{" "}
            Test venue
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
                  setDraft(empty);
                }}
              >
                Cancel
              </button>
            )}
          </div>
        </label>
      </form>
      {error && <p className="error">{error}</p>}
      <table>
        <thead>
          <tr>
            <th>Name</th>
            <th>Area</th>
            <th>Lat / Lng</th>
            <th>Flags</th>
            <th />
          </tr>
        </thead>
        <tbody>
          {rows.map((v) => (
            <tr key={v.id}>
              <td>{v.name}</td>
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
                  onClick={() => void remove(v.id)}
                >
                  Delete
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
