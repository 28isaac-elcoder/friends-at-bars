import { cn } from "@/lib/utils";

type CardBackProps = {
  className?: string;
  size?: "sm" | "md" | "lg" | "fill";
  /** Center label when no count (e.g. "Deck", "Active Card") */
  label?: string;
  /** Shown centered on the card face (deck pile) */
  showCount?: number | null;
};

const sizeClass = {
  sm: "h-16 w-11",
  md: "h-24 w-[4.25rem]",
  lg: "h-[9.625rem] w-[8.125rem]",
  fill: "h-full w-full min-h-0 min-w-0",
};

export function CardBack({
  className,
  size = "md",
  label,
  showCount,
}: CardBackProps) {
  return (
    <div
      className={cn(
        "relative flex items-center justify-center overflow-hidden rounded-[10px] border-[1.5px] border-white/25 bg-gradient-to-br from-[#1f387a] to-[#142352] shadow-md",
        sizeClass[size],
        className
      )}
      aria-hidden={showCount == null && !label}
      aria-label={
        showCount != null
          ? `Deck, ${showCount} cards`
          : label ?? undefined
      }
    >
      <div
        className="pointer-events-none absolute inset-1 rounded-sm border border-sky-400/25"
        style={{
          backgroundImage: `
            repeating-linear-gradient(45deg, transparent, transparent 4px, rgba(255,255,255,0.06) 4px, rgba(255,255,255,0.06) 8px),
            repeating-linear-gradient(-45deg, transparent, transparent 4px, rgba(255,255,255,0.06) 4px, rgba(255,255,255,0.06) 8px)
          `,
        }}
      />
      <span
        className="pointer-events-none absolute text-xl text-white/20"
        aria-hidden
      >
        ◆
      </span>
      {showCount != null ? (
        <span className="relative z-[1] text-xl font-bold tabular-nums text-white">
          {showCount}
        </span>
      ) : label ? (
        <span className="relative z-[1] px-1.5 text-center text-[11px] font-semibold leading-tight text-white/85">
          {label}
        </span>
      ) : null}
    </div>
  );
}
