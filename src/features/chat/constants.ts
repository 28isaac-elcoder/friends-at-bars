/** Max message length (enforced in UI + Supabase). */
export const CHAT_MAX_CHARS = 150;

/** Max posts per author per rolling hour (server-enforced). */
export const CHAT_MAX_POSTS_PER_HOUR = 5;

/** Soft-hide threshold (server-enforced via vote trigger). */
export const CHAT_HIDE_SCORE_THRESHOLD = -4;
