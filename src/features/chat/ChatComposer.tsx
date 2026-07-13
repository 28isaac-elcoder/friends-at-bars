import { useEffect, useLayoutEffect, useMemo, useRef, useState } from "react";
import { Send } from "lucide-react";
import { Select } from "@/components/ui/Select";
import { cn } from "@/lib/utils";
import { useTestMode } from "@/contexts/TestModeContext";
import { VISIBLE_VENUES } from "@/data/venues";
import { CHAT_MAX_CHARS } from "./constants";
import { chatService } from "./chatService";
import type { TestChatSender } from "./testChatService";
import type { ChatPost } from "./types";
import {
  useChatComposerGate,
  type ChatComposerGate,
} from "./useChatComposerGate";

/** Matches `text-sm leading-6` (24px). */
const COMPOSER_LINE_HEIGHT_PX = 24;
const COMPOSER_MAX_LINES = 4;
const COMPOSER_MAX_HEIGHT_PX = COMPOSER_LINE_HEIGHT_PX * COMPOSER_MAX_LINES;

type ChatComposerProps = {
  onPosted: (post: ChatPost) => void;
  /** When Test Mode mock data is on, posts go through this local creator. */
  createLocalPost?: (
    body: string,
    sender: TestChatSender,
    venueName?: string
  ) => Promise<ChatPost>;
  useLocal?: boolean;
  /**
   * Test Mode only: simulate OS location permission.
   * When false, shows the same “Allow Location to Chat” gate as production.
   */
  simulateLocationAllowed?: boolean;
  onSimulateAllowLocation?: () => void;
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

export function ChatComposer({
  onPosted,
  createLocalPost,
  useLocal = false,
  simulateLocationAllowed = true,
  onSimulateAllowLocation,
}: ChatComposerProps) {
  const { useMockCheckIns } = useTestMode();
  const local = useLocal || useMockCheckIns;
  const { gate, venueName, checking, requestLocation, refresh } =
    useChatComposerGate();
  const [text, setText] = useState("");
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [sender, setSender] = useState<TestChatSender>("user");
  const [simulatedVenue, setSimulatedVenue] = useState<string>("");

  const venueOptions = useMemo(() => {
    const byArea = new Map<string, string[]>();
    for (const v of VISIBLE_VENUES) {
      const list = byArea.get(v.area) ?? [];
      list.push(v.name);
      byArea.set(v.area, list);
    }
    return [...byArea.entries()];
  }, []);

  useEffect(() => {
    if (!local) return;
    setSimulatedVenue((prev) => {
      if (prev && VISIBLE_VENUES.some((v) => v.name === prev)) return prev;
      if (venueName && VISIBLE_VENUES.some((v) => v.name === venueName)) {
        return venueName;
      }
      const testLoc = VISIBLE_VENUES.find((v) => v.name === "Test Location 1");
      return testLoc?.name ?? VISIBLE_VENUES[0]?.name ?? "";
    });
  }, [local, venueName]);

  const effectiveGate: ChatComposerGate = local
    ? simulateLocationAllowed
      ? "ready"
      : "need-location"
    : gate;
  const effectiveVenue = local ? simulatedVenue : venueName;
  const showTestControls = local && simulateLocationAllowed;

  const [limitOverlay, setLimitOverlay] = useState(false);
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const overLimit = text.length > CHAT_MAX_CHARS;
  const hasDraft = text.trim().length > 0;
  const showSend = text.length > 0;
  const canAttemptSend =
    effectiveGate === "ready" &&
    hasDraft &&
    !sending &&
    (!local || Boolean(simulatedVenue));

  const resizeComposer = () => {
    const el = textareaRef.current;
    if (!el) return;
    el.style.height = "0px";
    el.style.overflowY = "hidden";
    const scroll = el.scrollHeight;
    el.style.height = `${Math.max(Math.min(scroll, COMPOSER_MAX_HEIGHT_PX), COMPOSER_LINE_HEIGHT_PX)}px`;
    el.style.overflowY = scroll > COMPOSER_MAX_HEIGHT_PX ? "auto" : "hidden";
  };

  useLayoutEffect(() => {
    resizeComposer();
  }, [text]);

  useEffect(() => {
    if (!limitOverlay) return;
    const t = window.setTimeout(() => setLimitOverlay(false), 1600);
    return () => window.clearTimeout(t);
  }, [limitOverlay]);

  const handleSend = async () => {
    if (!canAttemptSend) return;
    if (overLimit) {
      setLimitOverlay(true);
      return;
    }
    setSending(true);
    setError(null);
    setLimitOverlay(false);
    try {
      let post: ChatPost;
      if (local && createLocalPost) {
        post = await createLocalPost(text, sender, simulatedVenue);
      } else {
        await refresh();
        post = await chatService.createPost(text);
      }
      setText("");
      onPosted(post);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to post");
      if (!local) void refresh();
    } finally {
      setSending(false);
    }
  };

  return (
    <div className="border-t border-border bg-card px-3 py-2">
      {showTestControls ? (
        <div className="mb-2 space-y-2">
          <div className="flex flex-wrap items-center gap-2">
            <span className="text-[10px] font-medium uppercase tracking-wide text-muted-foreground">
              Send as
            </span>
            <div className="inline-flex rounded-md border border-border p-0.5">
              <button
                type="button"
                onClick={() => setSender("user")}
                className={cn(
                  "rounded px-2.5 py-1 text-xs font-medium transition-colors",
                  sender === "user"
                    ? "bg-primary text-primary-foreground"
                    : "text-muted-foreground hover:text-foreground"
                )}
              >
                User
              </button>
              <button
                type="button"
                onClick={() => setSender("other")}
                className={cn(
                  "rounded px-2.5 py-1 text-xs font-medium transition-colors",
                  sender === "other"
                    ? "bg-primary text-primary-foreground"
                    : "text-muted-foreground hover:text-foreground"
                )}
              >
                Other
              </button>
            </div>
            <span className="text-[10px] text-muted-foreground">
              Local test feed
            </span>
          </div>
          <div className="flex items-center gap-2">
            <label
              htmlFor="test-chat-venue"
              className="shrink-0 text-[10px] font-medium uppercase tracking-wide text-muted-foreground"
            >
              Bar
            </label>
            <Select
              id="test-chat-venue"
              value={simulatedVenue}
              onChange={(e) => setSimulatedVenue(e.target.value)}
              className="h-8 min-w-0 flex-1 py-1 text-xs"
              aria-label="Simulated bar for message"
            >
              {venueOptions.map(([area, names]) => (
                <optgroup key={area} label={area}>
                  {names.map((name) => (
                    <option key={name} value={name}>
                      {name}
                    </option>
                  ))}
                </optgroup>
              ))}
            </Select>
          </div>
        </div>
      ) : null}

      {effectiveGate === "need-location" ? (
        <button
          type="button"
          onClick={() => {
            if (local) onSimulateAllowLocation?.();
            else void requestLocation();
          }}
          disabled={!local && checking}
          className="w-full rounded-md border border-dashed border-border bg-muted/40 px-3 py-3 text-left text-sm text-muted-foreground"
        >
          {!local && checking
            ? "Checking location…"
            : "Allow Location to Chat — tap to enable"}
        </button>
      ) : null}

      {!local && gate === "not-at-bar" ? (
        <p className="rounded-md border border-dashed border-border bg-muted/40 px-3 py-3 text-sm text-muted-foreground">
          Must be at a Bar to Chat
        </p>
      ) : null}

      {!local && gate === "loading" ? (
        <p className="rounded-md bg-muted/40 px-3 py-3 text-sm text-muted-foreground">
          Checking location…
        </p>
      ) : null}

      {effectiveGate === "ready" ? (
        <>
          {!local && effectiveVenue ? (
            <p className="mb-1.5 text-xs text-muted-foreground">
              Posting from{" "}
              <span className="font-medium text-foreground">
                {effectiveVenue}
              </span>
            </p>
          ) : null}

          <div className="relative w-full">
            <div
              className={cn(
                "flex items-end gap-1.5 rounded-[22px] border border-border/80 bg-muted",
                "box-border py-1.5 pl-3.5 pr-1.5"
              )}
              style={{
                // One text line + vertical padding — stable empty ↔ typing
                minHeight:
                  COMPOSER_LINE_HEIGHT_PX + 12 /* py-1.5 top+bottom */,
              }}
            >
              <textarea
                ref={textareaRef}
                value={text}
                onChange={(e) => {
                  setLimitOverlay(false);
                  setText(e.target.value);
                }}
                disabled={sending}
                rows={1}
                placeholder={
                  local
                    ? sender === "other"
                      ? "Message as another user…"
                      : placeholderForGate("ready", effectiveVenue)
                    : placeholderForGate(gate, venueName)
                }
                className={cn(
                  "min-w-0 flex-1 resize-none border-0 bg-transparent p-0 text-sm leading-6",
                  "placeholder:text-muted-foreground focus-visible:outline-none",
                  "disabled:cursor-not-allowed disabled:opacity-60",
                  "[scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden",
                  overLimit && "text-destructive"
                )}
                style={{
                  height: COMPOSER_LINE_HEIGHT_PX,
                  maxHeight: COMPOSER_MAX_HEIGHT_PX,
                  minHeight: COMPOSER_LINE_HEIGHT_PX,
                  lineHeight: `${COMPOSER_LINE_HEIGHT_PX}px`,
                }}
                onKeyDown={(e) => {
                  if (e.key === "Enter" && !e.shiftKey) {
                    e.preventDefault();
                    void handleSend();
                  }
                }}
              />
              {/* Fixed slot = one text line tall so send never grows the bubble */}
              <div
                className="flex shrink-0 items-center justify-center"
                style={{
                  width: COMPOSER_LINE_HEIGHT_PX,
                  height: COMPOSER_LINE_HEIGHT_PX,
                }}
                aria-hidden={!showSend}
              >
                {showSend ? (
                  <button
                    type="button"
                    disabled={!canAttemptSend}
                    onClick={() => void handleSend()}
                    aria-label="Send message"
                    className={cn(
                      "chat-composer-send flex h-full w-full items-center justify-center rounded-full p-0",
                      "bg-primary text-primary-foreground",
                      "disabled:pointer-events-none disabled:opacity-40"
                    )}
                  >
                    <Send className="h-3 w-3" aria-hidden />
                  </button>
                ) : null}
              </div>
            </div>
            {limitOverlay ? (
              <div
                className="absolute inset-0 z-10 flex items-center justify-center rounded-[22px] bg-muted/95 px-4"
                role="alert"
              >
                <p className="text-center text-sm font-medium text-muted-foreground">
                  150 Character Limit
                </p>
              </div>
            ) : null}
          </div>
        </>
      ) : null}

      {error ? (
        <p className="mt-1.5 text-xs text-destructive">{error}</p>
      ) : null}
    </div>
  );
}
