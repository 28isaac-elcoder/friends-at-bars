import { cn } from "@/lib/utils";
import type { ChatFeedSort } from "./types";

type ChatSortTabsProps = {
  sort: ChatFeedSort;
  onChange: (sort: ChatFeedSort) => void;
};

export function ChatSortTabs({ sort, onChange }: ChatSortTabsProps) {
  return (
    <div
      className="flex bg-card"
      role="tablist"
      aria-label="Chat feed sort"
    >
      <button
        type="button"
        role="tab"
        aria-selected={sort === "recent"}
        onClick={() => onChange("recent")}
        className={cn(
          "flex-1 py-2.5 text-sm font-medium transition-colors",
          sort === "recent"
            ? "border-b-2 border-primary text-primary"
            : "text-muted-foreground hover:text-foreground"
        )}
      >
        Recent
      </button>
      <button
        type="button"
        role="tab"
        aria-selected={sort === "popular"}
        onClick={() => onChange("popular")}
        className={cn(
          "flex-1 py-2.5 text-sm font-medium transition-colors",
          sort === "popular"
            ? "border-b-2 border-primary text-primary"
            : "text-muted-foreground hover:text-foreground"
        )}
      >
        Popular
      </button>
    </div>
  );
}
