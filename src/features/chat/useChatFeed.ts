import { useCallback, useEffect, useState } from "react";
import { locationService } from "@/lib/locationService";
import { useTestMode } from "@/contexts/TestModeContext";
import { chatService } from "./chatService";
import {
  testChatService,
  type TestChatSender,
} from "./testChatService";
import type {
  ChatFeedSort,
  ChatPostWithVote,
  ChatVoteDirection,
} from "./types";

function activeService(useLocal: boolean) {
  return useLocal ? testChatService : chatService;
}

export function useChatFeed(sort: ChatFeedSort) {
  const { useMockCheckIns } = useTestMode();
  const useLocal = useMockCheckIns;
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
        const next = await activeService(useLocal).fetchFeed(sort, userId);
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
    [sort, userId, useLocal]
  );

  useEffect(() => {
    void load();
  }, [load]);

  useEffect(() => {
    const sub = activeService(useLocal).subscribeToPosts(() => {
      void load({ soft: true });
    });
    return () => sub.unsubscribe();
  }, [load, useLocal]);

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
      const updated = await activeService(useLocal).setVote(postId, direction);
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
      void load({ soft: true });
    },
    [removeLocal, load, useLocal]
  );

  const hideOwn = useCallback(
    async (postId: string) => {
      if (useLocal) {
        await testChatService.hidePost(postId);
      } else {
        await chatService.hideOwnPost(postId);
      }
      removeLocal(postId);
    },
    [removeLocal, useLocal]
  );

  const hideMany = useCallback(
    async (postIds: string[]) => {
      for (const id of postIds) {
        if (useLocal) {
          await testChatService.hidePost(id);
        } else {
          await chatService.hideOwnPost(id);
        }
        removeLocal(id);
      }
    },
    [removeLocal, useLocal]
  );

  const voteMany = useCallback(
    async (postIds: string[], direction: ChatVoteDirection) => {
      for (const id of postIds) {
        const post = posts.find((p) => p.id === id);
        if (!post || post.author_id === userId) continue;
        try {
          if (useLocal) {
            const updated = await testChatService.setVote(id, direction, {
              mode: "set",
            });
            if (updated.is_hidden) removeLocal(id);
          } else {
            const updated = await chatService.setVote(id, direction);
            if (updated.is_hidden) removeLocal(id);
          }
        } catch {
          /* skip failures */
        }
      }
      await load({ soft: true });
    },
    [posts, userId, useLocal, removeLocal, load]
  );

  const report = useCallback(
    async (postId: string) => {
      await activeService(useLocal).reportPost(postId);
    },
    [useLocal]
  );

  const createLocalPost = useCallback(
    async (body: string, sender: TestChatSender, venueName?: string) => {
      return testChatService.createPost(body, { sender, venueName });
    },
    []
  );

  return {
    posts,
    loading,
    refreshing,
    error,
    reload: load,
    vote,
    voteMany,
    hideOwn,
    hideMany,
    report,
    upsertLocal,
    userId,
    useLocal,
    createLocalPost,
  };
}
