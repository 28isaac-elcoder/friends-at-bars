import { cn } from "@/lib/utils";
import type {
  Card,
  ColorGuess,
  CompareGuess,
  GamePhase,
  Guess,
  RangeGuess,
  RoundIndex,
  RoundSlots,
  Suit,
} from "@/lib/rideTheBus/types";
import { CardBack } from "./CardBack";
import { PlayingCard } from "./PlayingCard";

const ACTIVE_CARD = "h-[9.625rem] w-[6.875rem]";
const SLOT_CARD = "h-[6.25rem] w-[4.5rem]";
const PILE_CARD = "h-[6.125rem] w-[4.375rem]";

type RideTheBusGameBoardProps = {
  deckCount: number;
  trashTopCard: Card | null;
  roundSlots: RoundSlots;
  round: RoundIndex;
  phase: GamePhase;
  current: Card | null;
  won: boolean;
  canGuess: boolean;
  /** Hide New Game when ranked win is submitting / done */
  showNewGame?: boolean;
  selectedGuess?: Guess | null;
  failHeadline?: string | null;
  failSubtitle?: string | null;
  onGuess: (guess: Guess) => void;
  onExit: () => void;
  onNewGame?: () => void;
};

function GuessButton({
  title,
  subtitle,
  tint,
  disabled,
  lit,
  dimmed,
  onClick,
}: {
  title: string;
  subtitle: string;
  tint: "red" | "dark";
  disabled: boolean;
  lit?: boolean;
  dimmed?: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      disabled={disabled}
      onClick={onClick}
      className={cn(
        "flex w-full flex-col items-center gap-0.5 rounded-xl px-2 py-4 text-white transition-all",
        tint === "red" ? "bg-red-600" : "bg-neutral-800",
        lit && "scale-[1.06] ring-2 ring-white/80 shadow-[0_0_18px_rgba(255,255,255,0.35)]",
        dimmed && "opacity-35 scale-[0.96]",
        !lit && !dimmed && (disabled ? "opacity-45" : "opacity-100 active:scale-[0.98]")
      )}
    >
      <span className="text-sm font-bold">{title}</span>
      <span className="text-xs font-semibold opacity-90">{subtitle}</span>
    </button>
  );
}

function SuitButton({
  suit,
  label,
  symbol,
  disabled,
  lit,
  dimmed,
  onClick,
}: {
  suit: Suit;
  label: string;
  symbol: string;
  disabled: boolean;
  lit?: boolean;
  dimmed?: boolean;
  onClick: () => void;
}) {
  const red = suit === "hearts" || suit === "diamonds";
  return (
    <button
      type="button"
      disabled={disabled}
      onClick={onClick}
      className={cn(
        "flex w-full flex-col items-center gap-0.5 rounded-xl px-2 py-3 text-white transition-all",
        red ? "bg-red-600" : "bg-neutral-800",
        lit && "scale-[1.06] ring-2 ring-white/80 shadow-[0_0_18px_rgba(255,255,255,0.35)]",
        dimmed && "opacity-35 scale-[0.96]",
        !lit && !dimmed && (disabled ? "opacity-45" : "opacity-100 active:scale-[0.98]")
      )}
    >
      <span className="text-xl font-bold leading-none">{symbol}</span>
      <span className="text-[10px] font-semibold">{label}</span>
    </button>
  );
}

function isSelected(
  selected: Guess | null | undefined,
  candidate: Guess
): boolean {
  if (!selected) return false;
  return JSON.stringify(selected) === JSON.stringify(candidate);
}

function LeftOptions({
  round,
  disabled,
  selectedGuess,
  onColor,
  onCompare,
  onRange,
  onSuit,
}: {
  round: RoundIndex;
  disabled: boolean;
  selectedGuess?: Guess | null;
  onColor: (v: ColorGuess) => void;
  onCompare: (v: CompareGuess) => void;
  onRange: (v: RangeGuess) => void;
  onSuit: (v: Suit) => void;
}) {
  const hasSel = Boolean(selectedGuess);
  if (round === 0) {
    const g: Guess = { round: 0, value: "red" };
    return (
      <GuessButton
        title="Red"
        subtitle="♥ ♦"
        tint="red"
        disabled={disabled}
        lit={isSelected(selectedGuess, g)}
        dimmed={hasSel && !isSelected(selectedGuess, g)}
        onClick={() => onColor("red")}
      />
    );
  }
  if (round === 1) {
    const g: Guess = { round: 1, value: "higher" };
    return (
      <GuessButton
        title="Higher"
        subtitle="↑"
        tint="dark"
        disabled={disabled}
        lit={isSelected(selectedGuess, g)}
        dimmed={hasSel && !isSelected(selectedGuess, g)}
        onClick={() => onCompare("higher")}
      />
    );
  }
  if (round === 2) {
    const g: Guess = { round: 2, value: "inside" };
    return (
      <GuessButton
        title="Inside"
        subtitle="→ ←"
        tint="dark"
        disabled={disabled}
        lit={isSelected(selectedGuess, g)}
        dimmed={hasSel && !isSelected(selectedGuess, g)}
        onClick={() => onRange("inside")}
      />
    );
  }
  return (
    <div className="flex flex-col gap-2.5">
      <SuitButton
        suit="hearts"
        label="Hearts"
        symbol="♥"
        disabled={disabled}
        lit={isSelected(selectedGuess, { round: 3, value: "hearts" })}
        dimmed={hasSel && !isSelected(selectedGuess, { round: 3, value: "hearts" })}
        onClick={() => onSuit("hearts")}
      />
      <SuitButton
        suit="diamonds"
        label="Diamonds"
        symbol="♦"
        disabled={disabled}
        lit={isSelected(selectedGuess, { round: 3, value: "diamonds" })}
        dimmed={
          hasSel && !isSelected(selectedGuess, { round: 3, value: "diamonds" })
        }
        onClick={() => onSuit("diamonds")}
      />
    </div>
  );
}

function RightOptions({
  round,
  disabled,
  selectedGuess,
  onColor,
  onCompare,
  onRange,
  onSuit,
}: {
  round: RoundIndex;
  disabled: boolean;
  selectedGuess?: Guess | null;
  onColor: (v: ColorGuess) => void;
  onCompare: (v: CompareGuess) => void;
  onRange: (v: RangeGuess) => void;
  onSuit: (v: Suit) => void;
}) {
  const hasSel = Boolean(selectedGuess);
  if (round === 0) {
    const g: Guess = { round: 0, value: "black" };
    return (
      <GuessButton
        title="Black"
        subtitle="♠ ♣"
        tint="dark"
        disabled={disabled}
        lit={isSelected(selectedGuess, g)}
        dimmed={hasSel && !isSelected(selectedGuess, g)}
        onClick={() => onColor("black")}
      />
    );
  }
  if (round === 1) {
    const g: Guess = { round: 1, value: "lower" };
    return (
      <GuessButton
        title="Lower"
        subtitle="↓"
        tint="dark"
        disabled={disabled}
        lit={isSelected(selectedGuess, g)}
        dimmed={hasSel && !isSelected(selectedGuess, g)}
        onClick={() => onCompare("lower")}
      />
    );
  }
  if (round === 2) {
    const g: Guess = { round: 2, value: "outside" };
    return (
      <GuessButton
        title="Outside"
        subtitle="← →"
        tint="dark"
        disabled={disabled}
        lit={isSelected(selectedGuess, g)}
        dimmed={hasSel && !isSelected(selectedGuess, g)}
        onClick={() => onRange("outside")}
      />
    );
  }
  return (
    <div className="flex flex-col gap-2.5">
      <SuitButton
        suit="clubs"
        label="Clubs"
        symbol="♣"
        disabled={disabled}
        lit={isSelected(selectedGuess, { round: 3, value: "clubs" })}
        dimmed={hasSel && !isSelected(selectedGuess, { round: 3, value: "clubs" })}
        onClick={() => onSuit("clubs")}
      />
      <SuitButton
        suit="spades"
        label="Spades"
        symbol="♠"
        disabled={disabled}
        lit={isSelected(selectedGuess, { round: 3, value: "spades" })}
        dimmed={
          hasSel && !isSelected(selectedGuess, { round: 3, value: "spades" })
        }
        onClick={() => onSuit("spades")}
      />
    </div>
  );
}

function ActiveCardFace({
  won,
  phase,
  current,
}: {
  won: boolean;
  phase: GamePhase;
  current: Card | null;
}) {
  if (won) {
    return (
      <div
        className={cn(
          "flex items-center justify-center rounded-[10px] border-2 border-green-500/45 bg-green-500/10",
          ACTIVE_CARD
        )}
        aria-label="You won"
      >
        <span className="text-4xl text-green-500" aria-hidden>
          ✓
        </span>
      </div>
    );
  }

  if (phase === "reveal" || phase === "failing") {
    if (current) {
      return <PlayingCard card={current} className={ACTIVE_CARD} size="fill" />;
    }
  }

  return <CardBack size="fill" label="Active Card" className={ACTIVE_CARD} />;
}

function RoundSlot({ index, card }: { index: number; card: Card | null }) {
  return (
    <div
      className={cn(
        "flex items-center justify-center rounded-[10px] border border-white/15 bg-[#1f2e59] p-1",
        SLOT_CARD
      )}
      aria-label={card ? `Round ${index + 1} card` : `Round ${index + 1} empty`}
    >
      {card ? (
        <PlayingCard card={card} size="fill" className="h-full w-full shadow-sm" />
      ) : (
        <span className="text-lg font-semibold text-white/35">{index + 1}</span>
      )}
    </div>
  );
}

export function RideTheBusGameBoard({
  deckCount,
  trashTopCard,
  roundSlots,
  round,
  phase,
  current,
  won,
  canGuess,
  showNewGame = false,
  selectedGuess = null,
  failHeadline = null,
  failSubtitle = null,
  onGuess,
  onExit,
  onNewGame,
}: RideTheBusGameBoardProps) {
  const guessDisabled = !canGuess || won;
  const failMode =
    phase === "failing" || phase === "failInterstitial";
  const displayRound: RoundIndex =
    phase === "failInterstitial" ? 0 : round;
  const hideActive =
    phase === "failInterstitial" || (phase === "failing" && !current);
  const showSlots = phase !== "failInterstitial";

  return (
    <div className="flex h-full min-h-0 w-full max-w-lg flex-col text-white">
      <div className="relative flex flex-shrink-0 items-center justify-center px-2 pt-1">
        <button
          type="button"
          onClick={onExit}
          className="absolute left-1 top-0.5 flex h-11 w-11 items-center justify-center text-white"
          aria-label="Exit"
        >
          <span className="text-lg font-semibold" aria-hidden>
            ‹
          </span>
        </button>
        <h1 className="text-xl font-bold tracking-tight drop-shadow-[0_0_8px_rgba(255,255,255,0.35)]">
          Ride The Bus
        </h1>
      </div>

      {won && (
        <p className="mt-1.5 px-5 text-center text-sm font-semibold text-green-500">
          Congrats! You’ve Conquered The Bus!
        </p>
      )}

      {failHeadline && (
        <div className="mt-1.5 px-5 text-center">
          <p className="text-sm font-bold text-[#ff736b]">{failHeadline}</p>
          {failSubtitle && (
            <p className="mt-0.5 text-xs font-semibold text-[#ff736b]/failSubtitle}</p>
          )}
        </div>
      )}

      <div className="flex min-h-0 flex-1 flex-col justify-between gap-3 py-3">
        <div className="flex items-center gap-2.5 px-3">
          {won ? (
            <div className="flex flex-1 justify-center">
              <ActiveCardFace won phase={phase} current={current} />
            </div>
          ) : (
            <>
              <div className="flex min-w-0 flex-1">
                <LeftOptions
                  round={displayRound}
                  disabled={guessDisabled || failMode}
                  selectedGuess={selectedGuess}
                  onColor={(v) => onGuess({ round: 0, value: v })}
                  onCompare={(v) => onGuess({ round: 1, value: v })}
                  onRange={(v) => onGuess({ round: 2, value: v })}
                  onSuit={(v) => onGuess({ round: 3, value: v })}
                />
              </div>
              {hideActive ? (
                <div className={cn(ACTIVE_CARD)} aria-hidden />
              ) : (
                <div
                  className={cn(
                    phase === "failing" &&
                      "animate-pulse shadow-[0_0_28px_rgba(239,68,68,0.75)]",
                    phase === "reveal" &&
                      "shadow-[0_0_28px_rgba(250,204,21,0.65)]"
                  )}
                >
                  <ActiveCardFace won={false} phase={phase} current={current} />
                </div>
              )}
              <div className="flex min-w-0 flex-1">
                <RightOptions
                  round={displayRound}
                  disabled={guessDisabled || failMode}
                  selectedGuess={selectedGuess}
                  onColor={(v) => onGuess({ round: 0, value: v })}
                  onCompare={(v) => onGuess({ round: 1, value: v })}
                  onRange={(v) => onGuess({ round: 2, value: v })}
                  onSuit={(v) => onGuess({ round: 3, value: v })}
                />
              </div>
            </>
          )}
        </div>

        {showSlots && (
          <div
            className={cn(
              "flex justify-center gap-3.5 px-6",
              phase === "failing" && "animate-pulse"
            )}
            aria-label="Completed rounds"
          >
            {[0, 1, 2].map((i) => (
              <RoundSlot key={i} index={i} card={roundSlots[i] ?? null} />
            ))}
          </div>
        )}

        <div className="flex items-center gap-4 px-7 pb-2">
          <div className="flex flex-col items-center gap-2">
            <CardBack
              size="fill"
              showCount={deckCount}
              className={cn(PILE_CARD, "shadow-[0_0_12px_rgba(59,130,246,0.35)]")}
            />
            <span className="text-xs font-medium text-white/55">Deck</span>
          </div>

          {showNewGame && onNewGame ? (
            <button
              type="button"
              onClick={onNewGame}
              className="flex-1 rounded-xl bg-green-500 py-3.5 text-base font-semibold text-black active:scale-[0.98]"
            >
              New Game
            </button>
          ) : (
            <div className="min-w-0 flex-1" aria-hidden />
          )}

          <div className="flex flex-col items-center gap-2">
            <div
              className={cn(
                "flex items-center justify-center rounded-lg border-2 border-dashed border-white/25 bg-white/5 p-1",
                PILE_CARD
              )}
              aria-label={trashTopCard ? "Trash pile" : "Trash empty"}
            >
              {trashTopCard ? (
                <PlayingCard
                  card={trashTopCard}
                  size="fill"
                  className="h-full w-full"
                />
              ) : (
                <svg
                  className="h-6 w-6 text-white/35"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="1.75"
                  aria-hidden
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    d="M4 7h16M9 7V5a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2m2 0v12a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2V7h12zM10 11v6M14 11v6"
                  />
                </svg>
              )}
            </div>
            <span className="text-xs font-medium text-white/55">Trash</span>
          </div>
        </div>
      </div>
    </div>
  );
}
