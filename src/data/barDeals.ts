/**
 * @deprecated Import from `@/data/dealsAndEvents` for new code.
 * Re-exports kept for existing Activities carousel imports.
 */
export type { BarListing as BarDeal, ActivitiesCarouselItem } from "@/data/dealsAndEvents";
export {
  getActivitiesCarouselItems,
  getActivitiesCarouselItems as getBarDealsForDate,
  ACTIVITIES_CAROUSEL_ITEMS as BAR_DEAL_SCHEDULE,
} from "@/data/dealsAndEvents";
