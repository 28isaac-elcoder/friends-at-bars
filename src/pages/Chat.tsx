import { useEffect, useMemo, useState } from "react";
import {
  ChevronDown,
  ChevronUp,
  List,
  MapPin,
  MapPinOff,
  Trash2,
  X,
} from "lucide-react";
import {
  ChatComposer,
  ChatPostCard,
  ChatSortTabs,
  useChatFeed,
  type ChatFeedSort,
  type ChatPost,
} from "@/features/chat";
import { shellHeightWithBottomNav } from "@/constants/layoutHeights";
import { Button } from "@/components/ui/Button";
import { cn } from "@/lib/utils";

export default function Chat() {
  const [sort, setSort] = useState<ChatFeedSort>("recent");
  const [selectMode, setSelectMode] = useState(false);
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [bulkBusy, setBulkBusy] = useState(false);
  /** Test Mode: simulate OS location on/off for composer gate preview. */
  const [simulateLocationAllowed, setSimulateLocationAllowed] = useState(true);

  const {
    posts,
    loading,
    error,
    vote,
    voteMany,
    hideOwn,
    hideMany,
    report,
    upsertLocal,
    userId,
    reload,
    useLocal,
    createLocalPost,
  } = useChatFeed(sort);

  useEffect(() => {
    if (!useLocal) {
      setSelectMode(false);
      setSelectedIds(new Set());
    }
  }, [useLocal]);

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

  const exitSelectMode = () => {
    setSelectMode(false);
    setSelectedIds(new Set());
  };

  const toggleSelect = (postId: string) => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(postId)) next.delete(postId);
      else next.add(postId);
      return next;
    });
  };

  const selectedList = [...selectedIds];

  const runBulk = async (fn: () => Promise<void>) => {
    if (selectedList.length === 0 || bulkBusy) return;
    setBulkBusy(true);
    try {
      await fn();
      exitSelectMode();
    } finally {
      setBulkBusy(false);
    }
  };

  return (
    <div
      className="flex min-h-0 flex-col bg-background"
      style={{ height: shellHeightWithBottomNav() }}
    >
      <div className="flex shrink-0 items-stretch border-b border-border">
        <div className="min-w-0 flex-1">
          <ChatSortTabs sort={sort} onChange={setSort} />
        </div>
        {useLocal ? (
          <>
            <button
              type="button"
              aria-label={
                simulateLocationAllowed
                  ? "Simulate location denied"
                  : "Simulate location allowed"
              }
              aria-pressed={simulateLocationAllowed}
              title={
                simulateLocationAllowed
                  ? "Location on (tap to deny)"
                  : "Location off (tap to allow)"
              }
              onClick={() => setSimulateLocationAllowed((v) => !v)}
              className={cn(
                "flex items-center border-l border-border px-3 text-muted-foreground transition-colors hover:bg-muted hover:text-foreground",
                simulateLocationAllowed && "bg-primary/10 text-primary"
              )}
            >
              {simulateLocationAllowed ? (
                <MapPin className="h-5 w-5" />
              ) : (
                <MapPinOff className="h-5 w-5" />
              )}
            </button>
            <button
              type="button"
              aria-label={selectMode ? "Exit select mode" : "Select messages"}
              aria-pressed={selectMode}
              onClick={() => {
                if (selectMode) exitSelectMode();
                else setSelectMode(true);
              }}
              className={cn(
                "flex items-center border-l border-border px-3 text-muted-foreground transition-colors hover:bg-muted hover:text-foreground",
                selectMode && "bg-primary/10 text-primary"
              )}
            >
              {selectMode ? (
                <X className="h-5 w-5" />
              ) : (
                <List className="h-5 w-5" />
              )}
            </button>
          </>
        ) : null}
      </div>

      {selectMode && useLocal ? (
        <div className="flex shrink-0 items-center gap-2 border-b border-border bg-muted/30 px-3 py-2">
          <span className="mr-auto text-xs text-muted-foreground">
            {selectedList.length} selected
          </span>
          <Button
            type="button"
            variant="outline"
            size="sm"
            className="h-8 px-2"
            disabled={bulkBusy || selectedList.length === 0}
            onClick={() => void runBulk(() => voteMany(selectedList, "up"))}
            aria-label="Upvote selected"
          >
            <ChevronUp className="h-4 w-4" />
          </Button>
          <Button
            type="button"
            variant="outline"
            size="sm"
            className="h-8 px-2"
            disabled={bulkBusy || selectedList.length === 0}
            onClick={() => void runBulk(() => voteMany(selectedList, "down"))}
            aria-label="Downvote selected"
          >
            <ChevronDown className="h-4 w-4" />
          </Button>
          <Button
            type="button"
            variant="destructive"
            size="sm"
            className="h-8 px-2"
            disabled={bulkBusy || selectedList.length === 0}
            onClick={() => void runBulk(() => hideMany(selectedList))}
            aria-label="Delete selected"
          >
            <Trash2 className="h-4 w-4" />
          </Button>
        </div>
      ) : null}

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
            {useLocal
              ? "No local messages yet. Send one below."
              : "No messages yet. Be the first when you\u2019re at a bar."}
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
                  selectMode={selectMode && useLocal}
                  selected={selectedIds.has(post.id)}
                  onToggleSelect={toggleSelect}
                />
              </li>
            ))}
          </ul>
        )}
      </div>

      <div className="shrink-0">
        <ChatComposer
          onPosted={handlePosted}
          useLocal={useLocal}
          createLocalPost={createLocalPost}
          simulateLocationAllowed={simulateLocationAllowed}
          onSimulateAllowLocation={() => setSimulateLocationAllowed(true)}
        />
      </div>
    </div>
  );
}
