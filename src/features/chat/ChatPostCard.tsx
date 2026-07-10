import { useState } from "react";
import { formatDistanceToNow } from "date-fns";
import {
  ChevronUp,
  ChevronDown,
  Flag,
  Trash2,
  MapPin,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/Button";
import type { ChatPostWithVote, ChatVoteDirection } from "./types";

type ChatPostCardProps = {
  post: ChatPostWithVote;
  isOwn: boolean;
  onVote: (postId: string, direction: ChatVoteDirection) => Promise<void>;
  onHideOwn: (postId: string) => Promise<void>;
  onReport: (postId: string) => Promise<void>;
};

export function ChatPostCard({
  post,
  isOwn,
  onVote,
  onHideOwn,
  onReport,
}: ChatPostCardProps) {
  const [busy, setBusy] = useState<"up" | "down" | "hide" | "report" | null>(
    null
  );
  const [reportDone, setReportDone] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);

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
    key: "up" | "down" | "hide" | "report",
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

  return (
    <article className="border-b border-border px-4 py-3">
      <div className="flex gap-3">
        <div className="flex flex-col items-center gap-0.5 pt-0.5">
          <button
            type="button"
            disabled={isOwn || busy !== null}
            aria-label="Upvote"
            aria-pressed={post.myVote === 1}
            onClick={() =>
              void run("up", () => onVote(post.id, "up"))
            }
            className={cn(
              "rounded p-0.5 text-muted-foreground transition-colors disabled:opacity-40",
              post.myVote === 1 && "text-primary",
              !isOwn && "hover:text-foreground"
            )}
          >
            <ChevronUp className="h-6 w-6" strokeWidth={2.5} />
          </button>
          <span
            className={cn(
              "min-w-[1.5rem] text-center text-sm font-semibold tabular-nums",
              post.score > 0 && "text-primary",
              post.score < 0 && "text-destructive"
            )}
          >
            {post.score}
          </span>
          <button
            type="button"
            disabled={isOwn || busy !== null}
            aria-label="Downvote"
            aria-pressed={post.myVote === -1}
            onClick={() =>
              void run("down", () => onVote(post.id, "down"))
            }
            className={cn(
              "rounded p-0.5 text-muted-foreground transition-colors disabled:opacity-40",
              post.myVote === -1 && "text-destructive",
              !isOwn && "hover:text-foreground"
            )}
          >
            <ChevronDown className="h-6 w-6" strokeWidth={2.5} />
          </button>
        </div>

        <div className="min-w-0 flex-1">
          <p className="whitespace-pre-wrap break-words text-sm leading-relaxed text-foreground">
            {post.body}
          </p>
          <div className="mt-2 flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-muted-foreground">
            <span className="inline-flex items-center gap-1 font-medium text-foreground/80">
              <MapPin className="h-3 w-3 shrink-0" />
              {post.venue_name}
            </span>
            <span>{when}</span>
          </div>

          <div className="mt-2 flex flex-wrap items-center gap-2">
            {isOwn ? (
              <Button
                type="button"
                variant="ghost"
                size="sm"
                disabled={busy !== null}
                className="h-8 px-2 text-xs text-destructive hover:text-destructive"
                onClick={() =>
                  void run("hide", () => onHideOwn(post.id))
                }
              >
                <Trash2 className="mr-1 h-3.5 w-3.5" />
                {busy === "hide" ? "Removing…" : "Delete"}
              </Button>
            ) : reportDone ? (
              <span className="text-xs text-muted-foreground">Reported</span>
            ) : (
              <Button
                type="button"
                variant="ghost"
                size="sm"
                disabled={busy !== null}
                className="h-8 px-2 text-xs text-muted-foreground"
                onClick={() =>
                  void run("report", async () => {
                    await onReport(post.id);
                    setReportDone(true);
                  })
                }
              >
                <Flag className="mr-1 h-3.5 w-3.5" />
                {busy === "report" ? "Reporting…" : "Report"}
              </Button>
            )}
          </div>

          {actionError ? (
            <p className="mt-1 text-xs text-destructive">{actionError}</p>
          ) : null}
        </div>
      </div>
    </article>
  );
}
