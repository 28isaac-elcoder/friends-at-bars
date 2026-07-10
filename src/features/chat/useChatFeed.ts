import { useCallback, useEffect, useState } from "react";
import { locationService } from "@/lib/locationService";
import { chatService } from "./chatService";
import type {
  ChatFeedSort,
  ChatPostWithVote,
  ChatVoteDirection,
} from "./types";

export function useChatFeed(sort: ChatFeedSort) {
  const userId = locationService.getUserId();
  const [posts, setPosts] = useState<ChatPostWithVote[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshing, setRefreshing] = useState(false);

  const load = useCallback(
    async (opts?: { soft?: boolean }) => {
      if (opts?.soft) setRefreshing(true);
      else setLoading(true);
      setError(null);
      try {
        const next = await chatService.fetchFeed(sort, userId);
        setPosts(next);
      } catch (err) {
        const msg =
          err instanceof Error ? err.message : "Failed to load chat";
        setError(msg);
      } finally {
        setLoading(false);
        setRefreshing(false);
      }
    },
    [sort, userId]
  );

  useEffect(() => {
    void load();
  }, [load]);

  useEffect(() => {
    const sub = chatService.subscribeToPosts(() => {
      void load({ soft: true });
    });
    return () => sub.unsubscribe();
  }, [load]);

  const removeLocal = useCallback((postId: string) => {
    setPosts((prev) => prev.filter((p) => p.id !== postId));
  }, []);

  const upsertLocal = useCallback((post: ChatPostWithVote) => {
    setPosts((prev) => {
      const without = prev.filter((p) => p.id !== post.id);
      if (post.is_hidden) return without;
      return [post, ...without];
    });
  }, []);

  const vote = useCallback(
    async (postId: string, direction: ChatVoteDirection) => {
      const updated = await chatService.setVote(postId, direction);
      if (updated.is_hidden) {
        removeLocal(postId);
        return;
      }
      setPosts((prev) =>
        prev.map((p) => {
          if (p.id !== postId) return p;
          let myVote = p.myVote;
          if (direction === "up") {
            myVote = myVote === 1 ? null : 1;
          } else {
            myVote = myVote === -1 ? null : -1;
          }
          return { ...p, ...updated, myVote };
        })
      );
      // Keep Popular order accurate after score changes
      void load({ soft: true });
    },
    [removeLocal, load]
  );

  const hideOwn = useCallback(
    async (postId: string) => {
      await chatService.hideOwnPost(postId);
      removeLocal(postId);
    },
    [removeLocal]
  );

  const report = useCallback(async (postId: string) => {
    await chatService.reportPost(postId);
  }, []);

  return {
    posts,
    loading,
    refreshing,
    error,
    reload: load,
    vote,
    hideOwn,
    report,
    upsertLocal,
    userId,
  };
}
