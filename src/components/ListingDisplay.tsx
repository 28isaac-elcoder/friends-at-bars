import { cn } from "@/lib/utils";
import {
  listingBadgeVariant,
  listingCardAccent,
  listingDetailText,
  type ListingTypeLabel,
} from "@/data/dealsAndEvents";

const BADGE_CLASSES: Record<"amber" | "violet" | "red", string> = {
  amber: "bg-amber-100 text-amber-900",
  violet: "bg-violet-100 text-violet-900",
  red: "bg-red-100 text-red-900",
};

const CARD_CLASSES: Record<"amber" | "violet" | "red", string> = {
  amber: "border-amber-200/80 bg-amber-50/60",
  violet: "border-violet-200/80 bg-violet-50/50",
  red: "border-red-200/80 bg-red-50/55",
};

const BAR_NAME_CLASSES: Record<"amber" | "violet" | "red", string> = {
  amber: "text-amber-950/90",
  violet: "text-violet-950/85",
  red: "text-red-950/90",
};

export function ListingTypeBadges({
  typeLabels,
}: {
  typeLabels: ListingTypeLabel[];
}) {
  return (
    <div className="flex flex-wrap items-center gap-1.5">
      {typeLabels.map((label) => (
        <span
          key={label}
          className={cn(
            "inline-flex rounded-full px-2 py-0.5 text-[10px] font-semibold",
            BADGE_CLASSES[listingBadgeVariant(label, typeLabels)]
          )}
        >
          {label}
        </span>
      ))}
    </div>
  );
}

export function ListingDetailList({ text }: { text: string }) {
  const parts = text
    .split(";")
    .map((part) => part.trim())
    .filter(Boolean);
  if (parts.length === 0) return null;
  return (
    <ul className="mt-1 list-inside list-disc space-y-0.5 text-xs text-gray-700">
      {parts.map((part, i) => (
        <li key={`${part}-${i}`}>{part}</li>
      ))}
    </ul>
  );
}

export interface ListingDisplayItem {
  title: string;
  time: string;
  details: string;
  barName: string;
  typeLabels: ListingTypeLabel[];
}

export function ListingCard({ item }: { item: ListingDisplayItem }) {
  const accent = listingCardAccent(item.typeLabels);
  const hasTitle = item.title.trim().length > 0;
  const detailText = listingDetailText(item.title, item.details);

  return (
    <div className={cn("rounded-md border px-3 py-2.5", CARD_CLASSES[accent])}>
      <ListingTypeBadges typeLabels={item.typeLabels} />
      {hasTitle ? (
        <p className="mt-1.5 text-sm font-semibold text-gray-900">{item.title}</p>
      ) : null}
      <p
        className={cn(
          "font-semibold",
          hasTitle ? "mt-0.5 text-xs font-medium" : "mt-1.5 text-sm",
          BAR_NAME_CLASSES[accent]
        )}
      >
        {item.barName}
      </p>
      {item.time.trim() ? (
        <p className="mt-0.5 text-xs font-medium text-gray-600">{item.time}</p>
      ) : null}
      <ListingDetailList text={detailText} />
    </div>
  );
}

export function listingCarouselLabel(typeLabels: ListingTypeLabel[]): string {
  const hasEvent = typeLabels.includes("Event");
  const hasSpecial =
    typeLabels.includes("Drink Special") || typeLabels.includes("Food Special");
  if (hasEvent && hasSpecial) return "Bar deal & event";
  if (hasEvent) return "Bar event";
  return "Bar deal";
}

export const CAROUSEL_SURFACE_CLASSES: Record<"amber" | "violet" | "red", string> = {
  amber: "border-amber-800/25 bg-gradient-to-br from-amber-50 to-amber-100/80",
  violet: "border-violet-800/25 bg-gradient-to-br from-violet-50 to-violet-100/80",
  red: "border-red-800/25 bg-gradient-to-br from-red-50 to-red-100/80",
};

export const CAROUSEL_LABEL_CLASSES: Record<"amber" | "violet" | "red", string> = {
  amber: "text-amber-900/70",
  violet: "text-violet-900/70",
  red: "text-red-900/70",
};

export const CAROUSEL_DOT_ACTIVE_CLASSES: Record<"amber" | "violet" | "red", string> = {
  amber: "bg-amber-800",
  violet: "bg-violet-800",
  red: "bg-red-800",
};

export const CAROUSEL_DOT_INACTIVE_CLASSES: Record<"amber" | "violet" | "red", string> = {
  amber: "bg-amber-800/25",
  violet: "bg-violet-800/25",
  red: "bg-red-800/25",
};
