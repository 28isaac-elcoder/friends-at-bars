import { useState } from "react";
import { ChevronDown, ChevronRight } from "lucide-react";
import { VISIBLE_CAMPUS_AREAS } from "@/data/venues";
import {
  WEEKDAY_LABELS,
  countItemsForArea,
  getListingsForAreaWeekday,
  type WeekdayIndex,
} from "@/data/dealsAndEvents";
import { ListingCard } from "@/components/ListingDisplay";
import { cn } from "@/lib/utils";

function dayKey(area: string, weekday: WeekdayIndex) {
  return `${area}-${weekday}`;
}

export default function DealsEventsPanel() {
  const [expandedAreas, setExpandedAreas] = useState<Set<string>>(new Set());
  const [expandedDays, setExpandedDays] = useState<Set<string>>(new Set());

  const toggleArea = (area: string) => {
    setExpandedAreas((prev) => {
      const next = new Set(prev);
      if (next.has(area)) next.delete(area);
      else next.add(area);
      return next;
    });
  };

  const toggleDay = (area: string, weekday: WeekdayIndex) => {
    const key = dayKey(area, weekday);
    setExpandedDays((prev) => {
      const next = new Set(prev);
      if (next.has(key)) next.delete(key);
      else next.add(key);
      return next;
    });
  };

  return (
    <div className="flex min-h-0 flex-1 flex-col overflow-hidden">
      <h1 className="mb-2 shrink-0 text-sm font-bold text-gray-900">
        Deals &amp; Events
      </h1>
      <p className="mb-3 shrink-0 text-xs text-gray-500">
        Weekly specials and events by area. Type badges show drink specials,
        food specials, and events — combo listings mark events in red.
      </p>
      <div className="min-h-0 flex-1 overflow-y-auto">
        <div className="space-y-2 pb-2">
          {VISIBLE_CAMPUS_AREAS.map((area) => {
            const isAreaExpanded = expandedAreas.has(area);
            const itemCount = countItemsForArea(area);
            return (
              <div
                key={area}
                className="rounded-lg border border-gray-200 bg-gray-50"
              >
                <button
                  type="button"
                  onClick={() => toggleArea(area)}
                  className="flex w-full items-center justify-between gap-2 p-3 text-left transition hover:bg-gray-100"
                >
                  <div className="flex min-w-0 items-center gap-2">
                    {isAreaExpanded ? (
                      <ChevronDown className="h-4 w-4 shrink-0 text-gray-500" />
                    ) : (
                      <ChevronRight className="h-4 w-4 shrink-0 text-gray-500" />
                    )}
                    <span className="font-semibold text-gray-900">{area}</span>
                  </div>
                  <span className="shrink-0 rounded-full bg-amber-100 px-2 py-0.5 text-xs font-semibold text-amber-900">
                    {itemCount}
                  </span>
                </button>
                {isAreaExpanded ? (
                  <div className="space-y-1 border-t border-gray-200 bg-white p-2">
                    {WEEKDAY_LABELS.map((dayLabel, weekday) => {
                      const wd = weekday as WeekdayIndex;
                      const listings = getListingsForAreaWeekday(area, wd);
                      const key = dayKey(area, wd);
                      const isDayExpanded = expandedDays.has(key);
                      return (
                        <div
                          key={key}
                          className="rounded-md border border-gray-100 bg-gray-50/80"
                        >
                          <button
                            type="button"
                            onClick={() => toggleDay(area, wd)}
                            className="flex w-full items-center justify-between gap-2 px-3 py-2 text-left text-sm transition hover:bg-gray-100"
                          >
                            <div className="flex min-w-0 items-center gap-2">
                              {isDayExpanded ? (
                                <ChevronDown className="h-3.5 w-3.5 shrink-0 text-gray-500" />
                              ) : (
                                <ChevronRight className="h-3.5 w-3.5 shrink-0 text-gray-500" />
                              )}
                              <span className="font-medium text-gray-800">
                                {dayLabel}
                              </span>
                            </div>
                            <span
                              className={cn(
                                "shrink-0 text-xs font-medium",
                                listings.length > 0
                                  ? "text-gray-600"
                                  : "text-gray-400"
                              )}
                            >
                              {listings.length === 0
                                ? "None"
                                : `${listings.length} item${listings.length === 1 ? "" : "s"}`}
                            </span>
                          </button>
                          {isDayExpanded ? (
                            <div className="space-y-1.5 border-t border-gray-100 px-3 py-2">
                              {listings.length === 0 ? (
                                <p className="text-xs text-gray-500">
                                  Nothing scheduled
                                </p>
                              ) : (
                                listings.map((item, i) => (
                                  <ListingCard
                                    key={`${item.barName}-${item.title}-${item.time}-${i}`}
                                    item={item}
                                  />
                                ))
                              )}
                            </div>
                          ) : null}
                        </div>
                      );
                    })}
                  </div>
                ) : null}
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
