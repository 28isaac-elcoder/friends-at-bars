import { useMemo, useState } from "react";
import {
  ChatComposer,
  ChatPostCard,
  ChatSortTabs,
  useChatFeed,
  type ChatFeedSort,
  type ChatPost,
} from "@/features/chat";
import { shellHeightWithBottomNav } from "@/constants/layoutHeights";

export default function Chat() {
  const [sort, setSort] = useState<ChatFeedSort>("recent");
  const {
    posts,
    loading,
    error,
    vote,
    hideOwn,
    report,
    upsertLocal,
    userId,
    reload,
  } = useChatFeed(sort);

  const sortedPosts = useMemo(() => {
    const copy = [...posts];
    if (sort === "popular") {
      copy.sort((a, b) => {
        if (b.score !== a.score) return b.score - a.score;
        return (
          new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
        );
      });
    } else {
      copy.sort(
        (a, b) =>
          new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
      );
    }
    return copy;
  }, [posts, sort]);

  const handlePosted = (post: ChatPost) => {
    upsertLocal({ ...post, myVote: null });
    if (sort !== "recent") {
      void reload({ soft: true });
    }
  };

  return (
    <div
      className="flex min-h-0 flex-col bg-background"
      style={{ height: shellHeightWithBottomNav() }}
    >
      <header className="shrink-0 border-b border-border px-4 py-3">
        <h1 className="text-lg font-semibold text-foreground">Chat</h1>
        <p className="text-xs text-muted-foreground">
          Anonymous campus feed · posts expire in 24 hours
        </p>
      </header>

      <ChatSortTabs sort={sort} onChange={setSort} />

      <div className="min-h-0 flex-1 overflow-y-auto">
        {loading ? (
          <div className="flex items-center justify-center py-16 text-sm text-muted-foreground">
            Loading…
          </div>
        ) : error ? (
          <div className="px-4 py-8 text-center">
            <p className="text-sm text-destructive">{error}</p>
            <button
              type="button"
              className="mt-3 text-sm font-medium text-primary underline"
              onClick={() => void reload()}
            >
              Try again
            </button>
          </div>
        ) : sortedPosts.length === 0 ? (
          <div className="px-4 py-16 text-center text-sm text-muted-foreground">
            No messages yet. Be the first when you&apos;re at a bar.
          </div>
        ) : (
          <ul>
            {sortedPosts.map((post) => (
              <li key={post.id}>
                <ChatPostCard
                  post={post}
                  isOwn={post.author_id === userId}
                  onVote={vote}
                  onHideOwn={hideOwn}
                  onReport={report}
                />
              </li>
            ))}
          </ul>
        )}
      </div>

      <div className="shrink-0">
        <ChatComposer onPosted={handlePosted} />
      </div>
    </div>
  );
}
