import { useState } from "react";
import { Send } from "lucide-react";
import { Button } from "@/components/ui/Button";
import { cn } from "@/lib/utils";
import { CHAT_MAX_CHARS } from "./constants";
import { chatService } from "./chatService";
import type { ChatPost } from "./types";
import {
  useChatComposerGate,
  type ChatComposerGate,
} from "./useChatComposerGate";

type ChatComposerProps = {
  onPosted: (post: ChatPost) => void;
};

function placeholderForGate(gate: ChatComposerGate, venueName: string | null) {
  switch (gate) {
    case "need-location":
      return "Allow Location to Chat";
    case "not-at-bar":
      return "Must be at a Bar to Chat";
    case "ready":
      return venueName
        ? `What's happening at ${venueName}?`
        : "What's happening?";
    default:
      return "Checking location…";
  }
}

export function ChatComposer({ onPosted }: ChatComposerProps) {
  const { gate, venueName, checking, requestLocation, refresh } =
    useChatComposerGate();
  const [text, setText] = useState("");
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const remaining = CHAT_MAX_CHARS - text.length;
  const canSend =
    gate === "ready" &&
    text.trim().length > 0 &&
    text.length <= CHAT_MAX_CHARS &&
    !sending;

  const handleSend = async () => {
    if (!canSend) return;
    setSending(true);
    setError(null);
    try {
      await refresh();
      const post = await chatService.createPost(text);
      setText("");
      onPosted(post);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to post");
      void refresh();
    } finally {
      setSending(false);
    }
  };

  return (
    <div className="border-t border-border bg-card px-3 py-2">
      {gate === "need-location" ? (
        <button
          type="button"
          onClick={() => void requestLocation()}
          disabled={checking}
          className="w-full rounded-md border border-dashed border-border bg-muted/40 px-3 py-3 text-left text-sm text-muted-foreground"
        >
          {checking ? "Checking location…" : "Allow Location to Chat — tap to enable"}
        </button>
      ) : null}

      {gate === "not-at-bar" ? (
        <p className="rounded-md border border-dashed border-border bg-muted/40 px-3 py-3 text-sm text-muted-foreground">
          Must be at a Bar to Chat
        </p>
      ) : null}

      {gate === "loading" ? (
        <p className="rounded-md bg-muted/40 px-3 py-3 text-sm text-muted-foreground">
          Checking location…
        </p>
      ) : null}

      {gate === "ready" ? (
        <>
          {venueName ? (
            <p className="mb-1.5 text-xs text-muted-foreground">
              Posting from{" "}
              <span className="font-medium text-foreground">{venueName}</span>
            </p>
          ) : null}

          <div className="flex items-end gap-2">
            <div className="relative min-w-0 flex-1">
              <textarea
                value={text}
                onChange={(e) => {
                  const next = e.target.value.slice(0, CHAT_MAX_CHARS);
                  setText(next);
                }}
                disabled={sending}
                rows={2}
                maxLength={CHAT_MAX_CHARS}
                placeholder={placeholderForGate(gate, venueName)}
                className={cn(
                  "w-full resize-none rounded-md border border-input bg-background px-3 py-2 text-sm",
                  "placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring",
                  "disabled:cursor-not-allowed disabled:opacity-60"
                )}
                onKeyDown={(e) => {
                  if (e.key === "Enter" && !e.shiftKey) {
                    e.preventDefault();
                    void handleSend();
                  }
                }}
              />
              <span
                className={cn(
                  "pointer-events-none absolute bottom-2 right-2 text-[10px] tabular-nums text-muted-foreground",
                  remaining <= 20 && "text-destructive"
                )}
              >
                {remaining}
              </span>
            </div>
            <Button
              type="button"
              size="sm"
              disabled={!canSend}
              onClick={() => void handleSend()}
              className="h-10 shrink-0 px-3"
              aria-label="Send message"
            >
              <Send className="h-4 w-4" />
            </Button>
          </div>
        </>
      ) : null}

      {error ? (
        <p className="mt-1.5 text-xs text-destructive">{error}</p>
      ) : null}
    </div>
  );
}
