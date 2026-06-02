import DealsEventsPanel from "@/components/DealsEventsPanel";

export default function DealsEvents() {
  return (
    <div
      className="relative flex h-full w-full flex-col bg-background"
      style={{ height: "calc(100vh - var(--navbar-height, 4rem) - 3.5rem)" }}
    >
      <div className="flex flex-1 flex-col overflow-hidden rounded-xl border border-gray-200 bg-white shadow-sm">
        <div className="flex min-h-0 flex-1 flex-col overflow-hidden px-3 py-2">
          <DealsEventsPanel />
        </div>
      </div>
    </div>
  );
}
