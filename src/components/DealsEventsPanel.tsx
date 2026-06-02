import { useState } from "react";
import { ChevronDown, ChevronRight, Sparkles } from "lucide-react";
import { CAMPUS_AREAS } from "@/data/venues";
import {
  WEEKDAY_LABELS,
  countItemsForArea,
  getDealsForAreaWeekday,
  getEventsForAreaWeekday,
  type WeekdayIndex,
  type DealListItem,
  type EventListItem,
} from "@/data/dealsAndEvents";
import { cn } from "@/lib/utils";

function SpecialBadge({ label }: { label: string }) {
  return (
    <span className="inline-flex items-center gap-0.5 rounded-full bg-emerald-100 px-2 py-0.5 text-[10px] font-semibold text-emerald-900">
      <Sparkles className="h-3 w-3 shrink-0" aria-hidden />
      {label}
    </span>
  );
}

function DealRow({ item }: { item: DealListItem }) {
  return (
    <div className="rounded-md border border-amber-200/80 bg-amber-50/60 px-3 py-2">
      <div className="flex flex-wrap items-center gap-2">
        <span className="text-sm font-semibold text-gray-900">{item.deal}</span>
        {item.specialLabel ? <SpecialBadge label={item.specialLabel} /> : null}
      </div>
      <p className="mt-0.5 text-xs font-medium text-amber-950/85">
        {item.barName}
      </p>
      <p className="text-xs text-gray-600">
        {item.time}
        {item.conditions.trim() ? ` · ${item.conditions}` : null}
      </p>
      {item.specialDates?.length ? (
        <p className="mt-0.5 text-[10px] text-gray-500">
          {item.specialDates.join(", ")}
        </p>
      ) : null}
    </div>
  );
}

function EventRow({ item }: { item: EventListItem }) {
  return (
    <div className="rounded-md border border-violet-200/80 bg-violet-50/50 px-3 py-2">
      <div className="flex flex-wrap items-center gap-2">
        <span className="text-sm font-semibold text-gray-900">{item.title}</span>
        {item.specialLabel ? <SpecialBadge label={item.specialLabel} /> : null}
      </div>
      <p className="mt-0.5 text-xs font-medium text-violet-950/85">
        {item.barName}
      </p>
      {item.description.trim() ? (
        <p className="text-xs text-gray-700">{item.description}</p>
      ) : null}
      <p className="text-xs text-gray-600">
        {item.time}
        {item.conditions.trim() ? ` · ${item.conditions}` : null}
      </p>
      {item.specialDates?.length ? (
        <p className="mt-0.5 text-[10px] text-gray-500">
          {item.specialDates.join(", ")}
        </p>
      ) : null}
    </div>
  );
}

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
        Weekly lineup by area. Special one-night deals and events (e.g. holidays)
        show on the matching day with a badge.
      </p>
      <div className="min-h-0 flex-1 overflow-y-auto">
        <div className="space-y-2 pb-2">
          {CAMPUS_AREAS.map((area) => {
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
                      const deals = getDealsForAreaWeekday(area, wd);
                      const events = getEventsForAreaWeekday(area, wd);
                      const key = dayKey(area, wd);
                      const isDayExpanded = expandedDays.has(key);
                      const dayTotal = deals.length + events.length;
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
                                dayTotal > 0
                                  ? "text-gray-600"
                                  : "text-gray-400"
                              )}
                            >
                              {dayTotal === 0
                                ? "None"
                                : `${deals.length} deal${deals.length === 1 ? "" : "s"}, ${events.length} event${events.length === 1 ? "" : "s"}`}
                            </span>
                          </button>
                          {isDayExpanded ? (
                            <div className="space-y-3 border-t border-gray-100 px-3 py-2">
                              <div>
                                <h3 className="mb-1.5 text-[11px] font-bold uppercase tracking-wide text-amber-900/70">
                                  Deals
                                </h3>
                                {deals.length === 0 ? (
                                  <p className="text-xs text-gray-500">
                                    No deals scheduled
                                  </p>
                                ) : (
                                  <div className="space-y-1.5">
                                    {deals.map((d, i) => (
                                      <DealRow
                                        key={`${d.deal}-${d.barName}-${i}`}
                                        item={d}
                                      />
                                    ))}
                                  </div>
                                )}
                              </div>
                              <div>
                                <h3 className="mb-1.5 text-[11px] font-bold uppercase tracking-wide text-violet-900/70">
                                  Events
                                </h3>
                                {events.length === 0 ? (
                                  <p className="text-xs text-gray-500">
                                    No events scheduled
                                  </p>
                                ) : (
                                  <div className="space-y-1.5">
                                    {events.map((e, i) => (
                                      <EventRow
                                        key={`${e.title}-${e.barName}-${i}`}
                                        item={e}
                                      />
                                    ))}
                                  </div>
                                )}
                              </div>
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
