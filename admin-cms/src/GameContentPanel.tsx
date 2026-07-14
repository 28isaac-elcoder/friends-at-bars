import { useCallback, useEffect, useState } from "react";
import { supabase } from "./supabase";

type Row = {
  id: string;
  game_key: string;
  pack_key: string;
  payload: unknown;
  is_active: boolean;
};

export function GameContentPanel() {
  const [rows, setRows] = useState<Row[]>([]);
  const [gameKey, setGameKey] = useState("switch-search");
  const [packKey, setPackKey] = useState("default");
  const [jsonText, setJsonText] = useState('{\n  "words": []\n}');
  const [editingId, setEditingId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    const { data, error: err } = await supabase
      .from("catalog_game_content")
      .select("*")
      .order("game_key");
    if (err) setError(err.message);
    else {
      setError(null);
      setRows((data ?? []) as Row[]);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    let payload: unknown;
    try {
      payload = JSON.parse(jsonText);
    } catch {
      setError("Invalid JSON");
      return;
    }
    const body = {
      game_key: gameKey,
      pack_key: packKey,
      payload,
      is_active: true,
    };
    if (editingId) {
      const { error: err } = await supabase
        .from("catalog_game_content")
        .update(body)
        .eq("id", editingId);
      if (err) {
        setError(err.message);
        return;
      }
    } else {
      const { error: err } = await supabase
        .from("catalog_game_content")
        .upsert(body, { onConflict: "game_key,pack_key" });
      if (err) {
        setError(err.message);
        return;
      }
    }
    setEditingId(null);
    await load();
  }

  function startEdit(row: Row) {
    setEditingId(row.id);
    setGameKey(row.game_key);
    setPackKey(row.pack_key);
    setJsonText(JSON.stringify(row.payload, null, 2));
  }

  return (
    <div>
      <h2>{editingId ? "Edit pack" : "Upsert game pack"}</h2>
      <form className="grid" onSubmit={save}>
        <label>
          Game key
          <input
            value={gameKey}
            onChange={(e) => setGameKey(e.target.value)}
            required
          />
        </label>
        <label>
          Pack key
          <input
            value={packKey}
            onChange={(e) => setPackKey(e.target.value)}
            required
          />
        </label>
        <label className="full">
          Payload JSON
          <textarea
            rows={12}
            value={jsonText}
            onChange={(e) => setJsonText(e.target.value)}
            style={{ fontFamily: "ui-monospace, monospace" }}
          />
        </label>
        <label className="full">
          <div className="row-actions">
            <button type="submit">{editingId ? "Update" : "Save"}</button>
            {editingId && (
              <button type="button" onClick={() => setEditingId(null)}>
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
            <th>Game</th>
            <th>Pack</th>
            <th>Active</th>
            <th />
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.id}>
              <td>{r.game_key}</td>
              <td>{r.pack_key}</td>
              <td>{r.is_active ? "yes" : "no"}</td>
              <td>
                <button type="button" onClick={() => startEdit(r)}>
                  Edit
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
