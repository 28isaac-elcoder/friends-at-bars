import { useEffect, useState } from "react";
import type { ActivitiesCarouselItem } from "@/data/dealsAndEvents";
import { listingCardAccent, listingDetailText } from "@/data/dealsAndEvents";
import {
  CAROUSEL_DOT_ACTIVE_CLASSES,
  CAROUSEL_DOT_INACTIVE_CLASSES,
  CAROUSEL_LABEL_CLASSES,
  CAROUSEL_SURFACE_CLASSES,
  ListingDetailList,
  ListingTypeBadges,
  listingCarouselLabel,
} from "@/components/ListingDisplay";
import { cn } from "@/lib/utils";

const ROTATE_MS = 3000;

interface BarDealsCarouselProps {
  items: ActivitiesCarouselItem[];
  className?: string;
}

export default function BarDealsCarousel({
  items,
  className,
}: BarDealsCarouselProps) {
  const [index, setIndex] = useState(0);

  useEffect(() => {
    setIndex(0);
  }, [items]);

  useEffect(() => {
    if (items.length <= 1) return;
    const id = window.setInterval(() => {
      setIndex((prev) => (prev + 1) % items.length);
    }, ROTATE_MS);
    return () => window.clearInterval(id);
  }, [items.length]);

  if (items.length === 0) return null;

  const current = items[index]!;
  const accent = listingCardAccent(current.typeLabels);
  const hasTitle = current.title.trim().length > 0;
  const detailText = listingDetailText(current.title, current.details);

  return (
    <div
      className={cn(
        "flex shrink-0 flex-col gap-1.5 rounded-lg border px-3 py-2.5 shadow-sm",
        CAROUSEL_SURFACE_CLASSES[accent],
        className
      )}
      aria-live="polite"
      aria-atomic="true"
    >
      <div className="flex items-start justify-between gap-2">
        <div className="min-w-0 space-y-1">
          <p
            className={cn(
              "text-[10px] font-bold uppercase tracking-wide",
              CAROUSEL_LABEL_CLASSES[accent]
            )}
          >
            {listingCarouselLabel(current.typeLabels)}
          </p>
          <ListingTypeBadges typeLabels={current.typeLabels} />
        </div>
        {items.length > 1 ? (
          <div className="flex shrink-0 gap-1" aria-hidden>
            {items.map((_, i) => (
              <span
                key={i}
                className={cn(
                  "h-1.5 w-1.5 rounded-full transition-colors",
                  i === index
                    ? CAROUSEL_DOT_ACTIVE_CLASSES[accent]
                    : CAROUSEL_DOT_INACTIVE_CLASSES[accent]
                )}
              />
            ))}
          </div>
        ) : null}
      </div>
      {hasTitle ? (
        <p className="text-base font-bold leading-tight text-gray-900">
          {current.title}
        </p>
      ) : null}
      <p
        className={cn(
          "font-semibold text-gray-900",
          hasTitle ? "text-sm" : "text-base leading-tight"
        )}
      >
        {current.barName}
      </p>
      {current.time.trim() ? (
        <p className="text-xs font-medium text-gray-700">{current.time}</p>
      ) : null}
      <ListingDetailList text={detailText} />
    </div>
  );
}
