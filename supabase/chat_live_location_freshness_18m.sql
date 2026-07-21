-- Align chat anti-spoof freshness with native live-location policy:
-- heartbeat 15 minutes, count/chat trust window 18 minutes.
-- Run in the Supabase SQL editor (safe to re-run).

CREATE OR REPLACE FUNCTION create_chat_post(
  p_author_id TEXT,
  p_body TEXT,
  p_venue_name TEXT
)
RETURNS chat_posts
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  trimmed TEXT;
  recent_count INTEGER;
  location_ok BOOLEAN;
  new_row chat_posts;
BEGIN
  IF p_author_id IS NULL OR length(trim(p_author_id)) = 0 THEN
    RAISE EXCEPTION 'author_id required';
  END IF;

  trimmed := trim(p_body);
  IF trimmed IS NULL OR length(trimmed) = 0 THEN
    RAISE EXCEPTION 'Message cannot be empty';
  END IF;
  IF char_length(trimmed) > 150 THEN
    RAISE EXCEPTION 'Message must be 150 characters or fewer';
  END IF;

  IF p_venue_name IS NULL OR length(trim(p_venue_name)) = 0 THEN
    RAISE EXCEPTION 'Must be at a bar to chat';
  END IF;

  SELECT COUNT(*)::INTEGER
  INTO recent_count
  FROM chat_posts
  WHERE author_id = p_author_id
    AND created_at > NOW() - INTERVAL '1 hour';

  IF recent_count >= 5 THEN
    RAISE EXCEPTION 'Rate limit: max 5 messages per hour';
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM live_locations
    WHERE user_id = p_author_id
      AND venue_name = trim(p_venue_name)
      AND is_active = true
      AND last_updated > NOW() - INTERVAL '18 minutes'
  )
  INTO location_ok;

  IF NOT location_ok THEN
    RAISE EXCEPTION 'Must be at a bar to chat';
  END IF;

  INSERT INTO chat_posts (author_id, body, venue_name)
  VALUES (p_author_id, trimmed, trim(p_venue_name))
  RETURNING * INTO new_row;

  RETURN new_row;
END;
$$;
