import { useCallback, useEffect, useState } from "react";
import { CatalogListing, CatalogVenue, supabase } from "./supabase";

const empty: Omit<CatalogListing, "id"> = {
  venue_name: "",
  title: "",
  time_label: "",
  details: "",
  area: "",
  listing_kind: "deal",
  type_labels: ["Drink Special"],
  days_of_week: [4],
  priority: 0,
  is_active: true,
};

export function ListingsPanel() {
  const [rows, setRows] = useState<CatalogListing[]>([]);
  const [venues, setVenues] = useState<CatalogVenue[]>([]);
  const [draft, setDraft] = useState(empty);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    const [listingsRes, venuesRes] = await Promise.all([
      supabase
        .from("catalog_listings")
        .select("*")
        .order("priority", { ascending: false }),
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
      setDraft((d) =>
        d.venue_name ? d : { ...d, venue_name: v[0]?.name ?? "" }
      );
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    const payload = {
      ...draft,
      type_labels: draft.type_labels,
      days_of_week: draft.days_of_week,
    };
    if (editingId) {
      const { error: err } = await supabase
        .from("catalog_listings")
        .update(payload)
        .eq("id", editingId);
      if (err) {
        setError(err.message);
        return;
      }
    } else {
      const { error: err } = await supabase
        .from("catalog_listings")
        .insert(payload);
      if (err) {
        setError(err.message);
        return;
      }
    }
    setDraft({
      ...empty,
      venue_name: venues[0]?.name ?? "",
    });
    setEditingId(null);
    await load();
  }

  function startEdit(row: CatalogListing) {
    setEditingId(row.id);
    setDraft({
      venue_name: row.venue_name,
      title: row.title,
      time_label: row.time_label,
      details: row.details,
      area: row.area,
      listing_kind: row.listing_kind,
      type_labels: row.type_labels,
      days_of_week: row.days_of_week,
      priority: row.priority,
      is_active: row.is_active,
    });
  }

  async function remove(id: string) {
    if (!confirm("Delete this listing?")) return;
    const { error: err } = await supabase
      .from("catalog_listings")
      .delete()
      .eq("id", id);
    if (err) setError(err.message);
    else await load();
  }

  return (
    <div>
      <h2>{editingId ? "Edit listing" : "Add listing"}</h2>
      <form className="grid" onSubmit={save}>
        <label>
          Venue
          <select
            value={draft.venue_name}
            onChange={(e) =>
              setDraft({ ...draft, venue_name: e.target.value })
            }
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
          Kind
          <select
            value={draft.listing_kind}
            onChange={(e) =>
              setDraft({
                ...draft,
                listing_kind: e.target.value as CatalogListing["listing_kind"],
              })
            }
          >
            <option value="deal">deal</option>
            <option value="event">event</option>
            <option value="food">food</option>
          </select>
        </label>
        <label>
          Title
          <input
            value={draft.title}
            onChange={(e) => setDraft({ ...draft, title: e.target.value })}
          />
        </label>
        <label>
          Time
          <input
            value={draft.time_label}
            onChange={(e) =>
              setDraft({ ...draft, time_label: e.target.value })
            }
          />
        </label>
        <label className="full">
          Details
          <textarea
            rows={3}
            value={draft.details}
            onChange={(e) => setDraft({ ...draft, details: e.target.value })}
          />
        </label>
        <label>
          Area
          <input
            value={draft.area}
            onChange={(e) => setDraft({ ...draft, area: e.target.value })}
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
          Type labels (comma)
          <input
            value={draft.type_labels.join(", ")}
            onChange={(e) =>
              setDraft({
                ...draft,
                type_labels: e.target.value
                  .split(",")
                  .map((s) => s.trim())
                  .filter(Boolean),
              })
            }
          />
        </label>
        <label>
          Days of week (0=Sun…6, comma)
          <input
            value={draft.days_of_week.join(",")}
            onChange={(e) =>
              setDraft({
                ...draft,
                days_of_week: e.target.value
                  .split(",")
                  .map((s) => Number(s.trim()))
                  .filter((n) => !Number.isNaN(n)),
              })
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
        <label className="full">
          <div className="row-actions">
            <button type="submit">{editingId ? "Update" : "Create"}</button>
            {editingId && (
              <button
                type="button"
                onClick={() => {
                  setEditingId(null);
                  setDraft({
                    ...empty,
                    venue_name: venues[0]?.name ?? "",
                  });
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
            <th>Venue</th>
            <th>Title</th>
            <th>Kind</th>
            <th>Days</th>
            <th />
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.id}>
              <td>{r.venue_name}</td>
              <td>
                {r.title || r.details.slice(0, 40)}
                {!r.is_active && " (off)"}
              </td>
              <td>{r.listing_kind}</td>
              <td>{r.days_of_week.join(",")}</td>
              <td className="row-actions">
                <button type="button" onClick={() => startEdit(r)}>
                  Edit
                </button>
                <button
                  type="button"
                  className="danger"
                  onClick={() => void remove(r.id)}
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
