import {
  useEffect,
  useRef,
  useState,
  type PointerEvent as ReactPointerEvent,
} from "react";
import { formatDistanceToNow } from "date-fns";
import {
  ArrowBigUp,
  ArrowBigDown,
  Flag,
  Trash2,
  MapPin,
  Check,
} from "lucide-react";
import { cn } from "@/lib/utils";
import type { ChatPostWithVote, ChatVoteDirection } from "./types";

const SWIPE_REVEAL_PX = 72;
const OPEN_THRESHOLD = 36;

function useFinePointer(): boolean {
  const [fine, setFine] = useState(false);
  useEffect(() => {
    if (typeof window === "undefined" || !window.matchMedia) return;
    const mq = window.matchMedia("(pointer: fine)");
    const sync = () => setFine(mq.matches);
    sync();
    mq.addEventListener("change", sync);
    return () => mq.removeEventListener("change", sync);
  }, []);
  return fine;
}

type ChatPostCardProps = {
  post: ChatPostWithVote;
  isOwn: boolean;
  onVote: (postId: string, direction: ChatVoteDirection) => Promise<void>;
  onHideOwn: (postId: string) => Promise<void>;
  onReport: (postId: string) => Promise<void>;
  selectMode?: boolean;
  selected?: boolean;
  onToggleSelect?: (postId: string) => void;
};

export function ChatPostCard({
  post,
  isOwn,
  onVote,
  onHideOwn,
  onReport,
  selectMode = false,
  selected = false,
  onToggleSelect,
}: ChatPostCardProps) {
  const finePointer = useFinePointer();
  const [busy, setBusy] = useState<
    "up" | "down" | "clear" | "hide" | "report" | null
  >(null);
  const [reportDone, setReportDone] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);
  const [offset, setOffset] = useState(0);
  const [dragging, setDragging] = useState(false);
  const offsetRef = useRef(0);
  const startXRef = useRef(0);
  const startOffsetRef = useRef(0);
  const draggingRef = useRef(false);

  const swipeEnabled =
    !selectMode && !finePointer && (isOwn || (!isOwn && !reportDone));

  const when = (() => {
    try {
      return formatDistanceToNow(new Date(post.created_at), {
        addSuffix: true,
      });
    } catch {
      return "";
    }
  })();

  const run = async (
    key: "up" | "down" | "clear" | "hide" | "report",
    fn: () => Promise<void>
  ) => {
    if (busy) return;
    setBusy(key);
    setActionError(null);
    try {
      await fn();
    } catch (err) {
      setActionError(err instanceof Error ? err.message : "Something went wrong");
    } finally {
      setBusy(null);
    }
  };

  const setSwipeOffset = (value: number) => {
    const clamped = Math.max(0, Math.min(SWIPE_REVEAL_PX, value));
    offsetRef.current = clamped;
    setOffset(clamped);
  };

  const onPointerDown = (e: ReactPointerEvent<HTMLDivElement>) => {
    if (!swipeEnabled) return;
    draggingRef.current = true;
    setDragging(true);
    startXRef.current = e.clientX;
    startOffsetRef.current = offsetRef.current;
    e.currentTarget.setPointerCapture(e.pointerId);
  };

  const onPointerMove = (e: ReactPointerEvent<HTMLDivElement>) => {
    if (!draggingRef.current || !swipeEnabled) return;
    const dx = e.clientX - startXRef.current;
    setSwipeOffset(startOffsetRef.current + dx);
  };

  const endDrag = (e: ReactPointerEvent<HTMLDivElement>) => {
    if (!draggingRef.current) return;
    draggingRef.current = false;
    setDragging(false);
    try {
      e.currentTarget.releasePointerCapture(e.pointerId);
    } catch {
      /* already released */
    }
    const open = offsetRef.current >= OPEN_THRESHOLD;
    setSwipeOffset(open ? SWIPE_REVEAL_PX : 0);
  };

  return (
    <article
      className={cn(
        "relative overflow-hidden border-b border-border",
        selectMode && selected && "bg-primary/5"
      )}
    >
      {swipeEnabled ? (
        <div
          className={cn(
            "absolute inset-y-0 left-0 flex w-[72px] items-center justify-center",
            isOwn ? "bg-destructive" : "bg-amber-600"
          )}
          aria-hidden={offset < 8}
        >
          <button
            type="button"
            disabled={busy !== null}
            aria-label={isOwn ? "Delete message" : "Report message"}
            className={cn(
              "chat-vote-chevron flex h-full w-full items-center justify-center",
              isOwn ? "text-destructive-foreground" : "text-white"
            )}
            onClick={() => {
              if (isOwn) {
                void run("hide", async () => {
                  setSwipeOffset(0);
                  await onHideOwn(post.id);
                });
              } else {
                void run("report", async () => {
                  setSwipeOffset(0);
                  await onReport(post.id);
                  setReportDone(true);
                });
              }
            }}
          >
            {isOwn ? (
              <Trash2 className="h-5 w-5" />
            ) : (
              <Flag className="h-5 w-5" />
            )}
          </button>
        </div>
      ) : null}

      <div
        className={cn(
          "relative bg-background px-3 py-2",
          swipeEnabled && "touch-pan-y",
          selectMode && "cursor-pointer"
        )}
        style={
          swipeEnabled
            ? {
                transform: `translateX(${offset}px)`,
                transition: dragging ? "none" : "transform 160ms ease-out",
              }
            : undefined
        }
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={endDrag}
        onPointerCancel={endDrag}
        onClick={() => {
          if (selectMode) onToggleSelect?.(post.id);
        }}
      >
        <div className="flex items-start gap-2">
          {selectMode ? (
            <div
              className={cn(
                "mt-0.5 flex h-4 w-4 shrink-0 items-center justify-center rounded border",
                selected
                  ? "border-primary bg-primary text-primary-foreground"
                  : "border-muted-foreground/40"
              )}
              aria-hidden
            >
              {selected ? <Check className="h-3 w-3" /> : null}
            </div>
          ) : null}

          <div
            className={cn(
              "flex w-8 shrink-0 flex-col items-center justify-center gap-0.5 rounded-md border border-border bg-muted/30 px-0.5 py-0.5"
            )}
          >
            <button
              type="button"
              disabled={isOwn || busy !== null || selectMode}
              aria-label="Upvote"
              aria-pressed={post.myVote === 1}
              onClick={(e) => {
                e.stopPropagation();
                void run("up", () => onVote(post.id, "up"));
              }}
              className={cn(
                "chat-vote-chevron rounded p-0 transition-colors disabled:opacity-40",
                post.myVote === 1
                  ? "text-green-600"
                  : "text-muted-foreground hover:text-green-600",
                isOwn && "hover:text-muted-foreground"
              )}
            >
              <ArrowBigUp
                className={cn(
                  "h-5 w-5",
                  post.myVote === 1 ? "fill-green-600" : "fill-none"
                )}
                strokeWidth={1.75}
              />
            </button>
            <button
              type="button"
              disabled={
                isOwn || busy !== null || selectMode || post.myVote == null
              }
              aria-label="Clear vote"
              title={post.myVote != null ? "Clear your vote" : undefined}
              onClick={(e) => {
                e.stopPropagation();
                if (post.myVote == null) return;
                const direction = post.myVote === 1 ? "up" : "down";
                void run("clear", () => onVote(post.id, direction));
              }}
              className={cn(
                "chat-vote-score min-w-[1.25rem] rounded px-0 text-center text-xs font-bold tabular-nums leading-4 transition-colors",
                post.myVote === 1 && "text-green-600",
                post.myVote === -1 && "text-red-600",
                post.myVote == null && post.score > 0 && "text-green-700/80",
                post.myVote == null && post.score < 0 && "text-red-700/80",
                post.myVote == null && post.score === 0 && "text-foreground",
                post.myVote != null &&
                  !isOwn &&
                  !selectMode &&
                  "cursor-pointer hover:bg-muted",
                (isOwn || post.myVote == null || selectMode) &&
                  "cursor-default disabled:opacity-100"
              )}
            >
              {post.score}
            </button>
            <button
              type="button"
              disabled={isOwn || busy !== null || selectMode}
              aria-label="Downvote"
              aria-pressed={post.myVote === -1}
              onClick={(e) => {
                e.stopPropagation();
                void run("down", () => onVote(post.id, "down"));
              }}
              className={cn(
                "chat-vote-chevron rounded p-0 transition-colors disabled:opacity-40",
                post.myVote === -1
                  ? "text-red-600"
                  : "text-muted-foreground hover:text-red-600",
                isOwn && "hover:text-muted-foreground"
              )}
            >
              <ArrowBigDown
                className={cn(
                  "h-5 w-5",
                  post.myVote === -1 ? "fill-red-600" : "fill-none"
                )}
                strokeWidth={1.75}
              />
            </button>
          </div>

          <div className="min-w-0 flex-1">
            <div className="flex gap-2">
              <div className="min-w-0 flex-1">
                <p className="whitespace-pre-wrap break-words text-sm leading-snug text-foreground">
                  {post.body}
                </p>
                <div className="mt-1 flex flex-wrap items-center gap-x-2 gap-y-0.5 text-[11px] leading-tight text-muted-foreground">
                  <span className="inline-flex items-center gap-0.5 font-medium text-foreground/80">
                    <MapPin className="h-3 w-3 shrink-0" />
                    {post.venue_name}
                  </span>
                  <span>{when}</span>
                  {isOwn ? (
                    <span className="text-primary/80">You</span>
                  ) : null}
                  {reportDone ? (
                    <span className="text-muted-foreground">Reported</span>
                  ) : null}
                </div>
              </div>

              {finePointer && !selectMode ? (
                <div className="flex shrink-0 flex-col items-center justify-start gap-1 pt-0.5">
                  {isOwn ? (
                    <button
                      type="button"
                      disabled={busy !== null}
                      aria-label="Delete message"
                      title="Delete"
                      className="chat-vote-chevron rounded p-1 text-muted-foreground transition-colors hover:bg-muted hover:text-destructive"
                      onClick={(e) => {
                        e.stopPropagation();
                        void run("hide", () => onHideOwn(post.id));
                      }}
                    >
                      <Trash2 className="h-4 w-4" />
                    </button>
                  ) : reportDone ? null : (
                    <button
                      type="button"
                      disabled={busy !== null}
                      aria-label="Report message"
                      title="Report"
                      className="chat-vote-chevron rounded p-1 text-muted-foreground transition-colors hover:bg-muted hover:text-amber-700"
                      onClick={(e) => {
                        e.stopPropagation();
                        void run("report", async () => {
                          await onReport(post.id);
                          setReportDone(true);
                        });
                      }}
                    >
                      <Flag className="h-4 w-4" />
                    </button>
                  )}
                </div>
              ) : null}
            </div>

            {actionError ? (
              <p className="mt-1 text-xs text-destructive">{actionError}</p>
            ) : null}
          </div>
        </div>
      </div>
    </article>
  );
}
