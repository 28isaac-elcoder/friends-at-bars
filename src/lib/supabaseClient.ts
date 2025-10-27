import { createClient } from "@supabase/supabase-js";
import { SupabaseCheckIn, SupabaseCheckInInsert } from "@/types/checkin";

// You'll need to replace these with your actual Supabase project URL and anon key
// Get these from your Supabase project settings
const supabaseUrl =
  (import.meta as any).env?.VITE_SUPABASE_URL ||
  "https://your-project.supabase.co";
const supabaseAnonKey =
  (import.meta as any).env?.VITE_SUPABASE_ANON_KEY || "your-anon-key";

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

// Database functions
export const checkInService = {
  // Insert a new check-in
  async insertCheckIn(data: SupabaseCheckInInsert) {
    const { data: result, error } = await supabase
      .from("checkins")
      .insert(data)
      .select()
      .single();

    if (error) throw error;
    return result;
  },

  // Fetch all check-ins
  async fetchCheckIns() {
    const { data, error } = await supabase
      .from("checkins")
      .select("*")
      .order("created_at", { ascending: false });

    if (error) throw error;
    return data as SupabaseCheckIn[];
  },

  // Subscribe to real-time updates
  subscribeToCheckIns(callback: (payload: any) => void) {
    return supabase
      .channel("checkins")
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "checkins" },
        callback
      )
      .subscribe();
  },
};
