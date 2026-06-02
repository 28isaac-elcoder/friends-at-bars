import { useEffect, useState } from "react";
import type { BarDeal } from "@/data/barDeals";
import { cn } from "@/lib/utils";

const ROTATE_MS = 3000;

interface BarDealsCarouselProps {
  deals: BarDeal[];
  className?: string;
}

export default function BarDealsCarousel({
  deals,
  className,
}: BarDealsCarouselProps) {
  const [index, setIndex] = useState(0);

  useEffect(() => {
    setIndex(0);
  }, [deals]);

  useEffect(() => {
    if (deals.length <= 1) return;
    const id = window.setInterval(() => {
      setIndex((prev) => (prev + 1) % deals.length);
    }, ROTATE_MS);
    return () => window.clearInterval(id);
  }, [deals.length]);

  if (deals.length === 0) return null;

  const current = deals[index]!;

  return (
    <div
      className={cn(
        "flex shrink-0 flex-col gap-1 rounded-lg border border-amber-800/25 bg-gradient-to-br from-amber-50 to-amber-100/80 px-3 py-2.5 shadow-sm",
        className
      )}
      aria-live="polite"
      aria-atomic="true"
    >
      <div className="flex items-center justify-between gap-2">
        <p className="text-[10px] font-bold uppercase tracking-wide text-amber-900/70">
          Bar deals
        </p>
        {deals.length > 1 ? (
          <div className="flex shrink-0 gap-1" aria-hidden>
            {deals.map((_, i) => (
              <span
                key={i}
                className={cn(
                  "h-1.5 w-1.5 rounded-full transition-colors",
                  i === index ? "bg-amber-800" : "bg-amber-800/25"
                )}
              />
            ))}
          </div>
        ) : null}
      </div>
      <p className="text-base font-bold leading-tight text-gray-900">
        {current.deal}
      </p>
      <p className="text-sm font-semibold text-amber-950/90">{current.barName}</p>
      <div className="flex flex-wrap items-baseline gap-x-2 gap-y-0.5 text-xs text-gray-700">
        <span>{current.time}</span>
        {current.conditions.trim() ? (
          <span className="text-gray-500">· {current.conditions}</span>
        ) : null}
      </div>
    </div>
  );
}
