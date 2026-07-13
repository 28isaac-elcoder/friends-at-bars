import { locationService } from "@/lib/locationService";
import { isVenueVisible } from "@/data/venues";
import { CHAT_HIDE_SCORE_THRESHOLD, CHAT_MAX_CHARS } from "./constants";
import type {
  ChatFeedSort,
  ChatMyVote,
  ChatPost,
  ChatPostWithVote,
  ChatVoteDirection,
} from "./types";

const STORAGE_POSTS_KEY = "barfest_test_chat_posts";
const STORAGE_VOTES_KEY = "barfest_test_chat_votes";

/** Stable fake author for “Other” sender mode in Test Mode. */
export const TEST_CHAT_OTHER_AUTHOR_ID = "test_chat_other";

export type TestChatSender = "user" | "other";

type VoteMap = Record<string, 1 | -1>;

let posts: ChatPost[] = [];
let votes: VoteMap = {};
let loaded = false;
const listeners = new Set<() => void>();

function notify() {
  listeners.forEach((fn) => fn());
}

function persist() {
  if (typeof localStorage === "undefined") return;
  try {
    localStorage.setItem(STORAGE_POSTS_KEY, JSON.stringify(posts));
    localStorage.setItem(STORAGE_VOTES_KEY, JSON.stringify(votes));
  } catch {
    /* ignore quota */
  }
}

function ensureLoaded() {
  if (loaded) return;
  loaded = true;
  if (typeof localStorage === "undefined") return;
  try {
    const rawPosts = localStorage.getItem(STORAGE_POSTS_KEY);
    const rawVotes = localStorage.getItem(STORAGE_VOTES_KEY);
    if (rawPosts) posts = JSON.parse(rawPosts) as ChatPost[];
    if (rawVotes) votes = JSON.parse(rawVotes) as VoteMap;
  } catch {
    posts = [];
    votes = {};
  }
}

function isActive(post: ChatPost): boolean {
  return (
    !post.is_hidden &&
    new Date(post.expires_at).getTime() > Date.now() &&
    isVenueVisible(post.venue_name)
  );
}

function withMyVote(post: ChatPost): ChatPostWithVote {
  const v = votes[post.id];
  return {
    ...post,
    myVote: v === 1 || v === -1 ? v : null,
  };
}

function applyScoreAndHide(post: ChatPost, newScore: number): ChatPost {
  return {
    ...post,
    score: newScore,
    is_hidden: newScore <= CHAT_HIDE_SCORE_THRESHOLD ? true : post.is_hidden,
  };
}

export const testChatService = {
  async fetchFeed(
    sort: ChatFeedSort,
    _userId: string
  ): Promise<ChatPostWithVote[]> {
    ensureLoaded();
    let list = posts.filter(isActive).map(withMyVote);
    if (sort === "popular") {
      list = [...list].sort((a, b) => {
        if (b.score !== a.score) return b.score - a.score;
        return (
          new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
        );
      });
    } else {
      list = [...list].sort(
        (a, b) =>
          new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
      );
    }
    return list;
  },

  async createPost(
    body: string,
    opts?: { sender?: TestChatSender; venueName?: string }
  ): Promise<ChatPost> {
    ensureLoaded();
    const trimmed = body.trim();
    if (!trimmed) throw new Error("Message cannot be empty");
    if (trimmed.length > CHAT_MAX_CHARS) {
      throw new Error(`Message must be ${CHAT_MAX_CHARS} characters or fewer`);
    }

    const userId = locationService.getUserId();
    const sender = opts?.sender ?? "user";
    const authorId =
      sender === "other" ? TEST_CHAT_OTHER_AUTHOR_ID : userId;

    let venueName = opts?.venueName?.trim() || "";
    if (!venueName) {
      const loc = await locationService.getCurrentLocation();
      if (loc) {
        venueName =
          locationService.getVenueNameIfAtVenue(loc.latitude, loc.longitude) ??
          "";
      }
    }
    if (!venueName) venueName = "Test Location 1";

    const now = new Date();
    const post: ChatPost = {
      id: `test_chat_${now.getTime()}_${Math.random().toString(36).slice(2, 9)}`,
      author_id: authorId,
      body: trimmed,
      venue_name: venueName,
      score: 0,
      is_hidden: false,
      created_at: now.toISOString(),
      expires_at: new Date(now.getTime() + 24 * 60 * 60 * 1000).toISOString(),
    };

    posts = [post, ...posts];
    persist();
    notify();
    return post;
  },

  async setVote(
    postId: string,
    direction: ChatVoteDirection,
    opts?: { mode?: "toggle" | "set" }
  ): Promise<ChatPost> {
    ensureLoaded();
    const userId = locationService.getUserId();
    const idx = posts.findIndex((p) => p.id === postId);
    if (idx < 0) throw new Error("Post not found");

    let post = posts[idx];
    if (post.is_hidden || new Date(post.expires_at).getTime() <= Date.now()) {
      throw new Error("Post is not available");
    }
    if (post.author_id === userId) {
      throw new Error("Cannot vote on your own post");
    }

    const desired: 1 | -1 = direction === "up" ? 1 : -1;
    const existing = votes[postId] as ChatMyVote | undefined;
    const mode = opts?.mode ?? "toggle";
    let delta = 0;

    if (mode === "set") {
      if (existing === desired) {
        return post;
      }
      if (existing == null) {
        votes[postId] = desired;
        delta = desired;
      } else {
        votes[postId] = desired;
        delta = desired - existing;
      }
    } else if (existing === desired) {
      delete votes[postId];
      delta = -desired;
    } else if (existing == null) {
      votes[postId] = desired;
      delta = desired;
    } else {
      votes[postId] = desired;
      delta = desired - existing;
    }

    post = applyScoreAndHide(post, post.score + delta);
    posts = posts.map((p, i) => (i === idx ? post : p));
    if (post.is_hidden) delete votes[postId];
    persist();
    notify();
    return post;
  },

  /** Soft-hide any post (test bulk delete / own delete). */
  async hidePost(postId: string): Promise<ChatPost> {
    ensureLoaded();
    const idx = posts.findIndex((p) => p.id === postId);
    if (idx < 0) throw new Error("Post not found");
    const post = { ...posts[idx], is_hidden: true };
    posts = posts.map((p, i) => (i === idx ? post : p));
    delete votes[postId];
    persist();
    notify();
    return post;
  },

  async hideOwnPost(postId: string): Promise<ChatPost> {
    ensureLoaded();
    const userId = locationService.getUserId();
    const post = posts.find((p) => p.id === postId);
    if (!post) throw new Error("Post not found or not yours");
    if (post.author_id !== userId) {
      throw new Error("Post not found or not yours");
    }
    return this.hidePost(postId);
  },

  async reportPost(_postId: string, _reason?: string): Promise<void> {
    // No-op locally; keep UI parity
  },

  subscribeToPosts(onChange: () => void) {
    ensureLoaded();
    listeners.add(onChange);
    return {
      unsubscribe: () => {
        listeners.delete(onChange);
      },
    };
  },

  clearAll() {
    ensureLoaded();
    posts = [];
    votes = {};
    persist();
    notify();
  },
};
