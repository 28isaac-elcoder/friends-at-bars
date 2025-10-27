export interface CheckIn {
  id: string;
  venue: string;
  venueArea?: string; // Optional area for future use
  startTime: string;
  durationMinutes: number;
  endTime: string; // calculated from startTime + durationMinutes
  timestamp: Date;
}

export interface CheckInFormData {
  venue: string;
  startTime: string;
  durationMinutes: number;
}

export interface Venue {
  name: string;
  area: string;
  coordinates: [number, number]; // [latitude, longitude]
}

// Supabase database types
export interface SupabaseCheckIn {
  id: string;
  venue: string;
  start_time: string;
  end_time: string;
  created_at: string;
}

export interface SupabaseCheckInInsert {
  venue: string;
  start_time: string;
  end_time: string;
}
