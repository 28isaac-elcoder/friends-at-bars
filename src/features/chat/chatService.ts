import {
  supabase,
  isSupabaseNetworkError,
  logSupabaseNetworkOnce,
} from "@/lib/supabaseClient";
import { locationService } from "@/lib/locationService";
import { isVenueVisible } from "@/data/venues";
import type {
  ChatFeedSort,
  ChatMyVote,
  ChatPost,
  ChatPostWithVote,
  ChatVoteDirection,
} from "./types";

function mapRpcError(err: unknown): Error {
  if (err && typeof err === "object") {
    const e = err as { message?: string; details?: string; hint?: string };
    const raw = String(e.message ?? e.details ?? "Request failed");
    // PostgREST may prefix with "P0001:" or function name
    const cleaned = raw
      .replace(/^P0001:\s*/i, "")
      .replace(/^.*create_chat_post[^:]*:\s*/i, "")
      .replace(/^.*set_chat_vote[^:]*:\s*/i, "")
      .replace(/^.*hide_own_chat_post[^:]*:\s*/i, "")
      .replace(/^.*report_chat_post[^:]*:\s*/i, "")
      .trim();
    return new Error(cleaned || raw);
  }
  return new Error("Request failed");
}

/** Active post at a venue visible in this build (hides Test Locations in production). */
function isVisiblePost(post: ChatPost): boolean {
  return (
    !post.is_hidden &&
    new Date(post.expires_at).getTime() > Date.now() &&
    isVenueVisible(post.venue_name)
  );
}

async function fetchMyVotes(
  postIds: string[],
  voterId: string
): Promise<Map<string, ChatMyVote>> {
  const map = new Map<string, ChatMyVote>();
  if (postIds.length === 0) return map;

  const { data, error } = await supabase
    .from("chat_votes")
    .select("post_id, vote")
    .eq("voter_id", voterId)
    .in("post_id", postIds);

  if (error) {
    if (isSupabaseNetworkError(error)) {
      logSupabaseNetworkOnce(error);
      return map;
    }
    throw error;
  }

  for (const row of data ?? []) {
    const v = row.vote;
    if (v === 1 || v === -1) {
      map.set(row.post_id, v);
    }
  }
  return map;
}

function attachVotes(
  posts: ChatPost[],
  voteMap: Map<string, ChatMyVote>
): ChatPostWithVote[] {
  return posts.map((p) => ({
    ...p,
    myVote: voteMap.get(p.id) ?? null,
  }));
}

export const chatService = {
  async fetchFeed(
    sort: ChatFeedSort,
    userId: string
  ): Promise<ChatPostWithVote[]> {
    try {
      let query = supabase
        .from("chat_posts")
        .select("*")
        .eq("is_hidden", false)
        .gt("expires_at", new Date().toISOString());

      if (sort === "popular") {
        query = query
          .order("score", { ascending: false })
          .order("created_at", { ascending: false });
      } else {
        query = query.order("created_at", { ascending: false });
      }

      const { data, error } = await query.limit(100);

      if (error) throw error;

      const posts = (data as ChatPost[]).filter(isVisiblePost);
      const voteMap = await fetchMyVotes(
        posts.map((p) => p.id),
        userId
      );
      return attachVotes(posts, voteMap);
    } catch (err) {
      if (isSupabaseNetworkError(err)) {
        logSupabaseNetworkOnce(err);
        return [];
      }
      throw err;
    }
  },

  /**
   * Rechecks GPS, upserts live_locations, then creates a post via RPC
   * (rate limit + venue presence enforced server-side).
   */
  async createPost(body: string): Promise<ChatPost> {
    const userId = locationService.getUserId();
    const trimmed = body.trim();
    if (!trimmed) {
      throw new Error("Message cannot be empty");
    }
    if (trimmed.length > 150) {
      throw new Error("Message must be 150 characters or fewer");
    }

    const loc = await locationService.getCurrentLocation();
    if (!loc) {
      throw new Error("Allow Location to Chat");
    }

    const venueName = locationService.getVenueNameIfAtVenue(
      loc.latitude,
      loc.longitude
    );
    if (!venueName) {
      throw new Error("Must be at a Bar to Chat");
    }

    // Refresh live_locations so create_chat_post anti-spoof check passes
    await locationService.updateLiveLocation({
      latitude: loc.latitude,
      longitude: loc.longitude,
      accuracy: loc.accuracy ?? 0,
    });

    const { data, error } = await supabase.rpc("create_chat_post", {
      p_author_id: userId,
      p_body: trimmed,
      p_venue_name: venueName,
    });

    if (error) throw mapRpcError(error);
    return data as ChatPost;
  },

  async setVote(
    postId: string,
    direction: ChatVoteDirection
  ): Promise<ChatPost> {
    const userId = locationService.getUserId();
    const { data, error } = await supabase.rpc("set_chat_vote", {
      p_post_id: postId,
      p_voter_id: userId,
      p_direction: direction,
    });

    if (error) throw mapRpcError(error);
    return data as ChatPost;
  },

  async hideOwnPost(postId: string): Promise<ChatPost> {
    const userId = locationService.getUserId();
    const { data, error } = await supabase.rpc("hide_own_chat_post", {
      p_post_id: postId,
      p_author_id: userId,
    });

    if (error) throw mapRpcError(error);
    return data as ChatPost;
  },

  async reportPost(postId: string, reason?: string): Promise<void> {
    const userId = locationService.getUserId();
    const { error } = await supabase.rpc("report_chat_post", {
      p_post_id: postId,
      p_reporter_id: userId,
      p_reason: reason ?? null,
    });

    if (error) throw mapRpcError(error);
  },

  subscribeToPosts(onChange: () => void) {
    const channel = supabase
      .channel("chat_posts_feed")
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "chat_posts" },
        () => {
          onChange();
        }
      )
      .subscribe();

    return {
      unsubscribe: () => {
        void supabase.removeChannel(channel);
      },
    };
  },
};
