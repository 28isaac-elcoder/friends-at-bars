export type FailCopy = {
  headline: string;
  subtitle: string;
  /** Classifies two-sip tie prompts only (not a stored drink counter). */
  isTwoSip: boolean;
};

export function parseFailMessage(full: string): FailCopy {
  const trimmed = full.trim();
  const bang = trimmed.indexOf("!");
  if (bang < 0) {
    return { headline: trimmed, subtitle: "", isTwoSip: false };
  }
  const headline = trimmed.slice(0, bang + 1);
  const subtitle = trimmed.slice(bang + 1).trim();
  const lower = subtitle.toLowerCase();
  const isTwoSip = lower.includes("2 sip") || lower.includes("two sip");
  return { headline, subtitle, isTwoSip };
}

const ALL_RAW = [
  "Engine Overheated! Sit tight, take a drink, try again.",
  "Driver Hit A Pothole! Take a drink - Draw again.",
  "Sharp Turn! The Bus Rolled. Take 2 sips.",
  "Flat Tire! Pull over and take a drink while we swap it out.",
  "Brake Check! BOOM! Take a sip, you’re gonna need it.",
  "Missed Your Stop! Double back. Take a drink and redraw.",
  "Caught At a Red Light! Wait it out and take a drink.",
  "Ticket Inspector Onboard! Caught without a pass. Take 2 sips.",
  "The Bus is Full! Wait for the next one. Take a sip.",
  "Dead Battery! Need a jumpstart. Take a drink.",
  "Fell Asleep on The Back Row! Woke up at the depot. Take 2 sips.",
  "Speed Bump Surprise! Hit it too fast. Drink and redraw.",
] as const;

export const ALL_FAIL_MESSAGES: FailCopy[] = ALL_RAW.map(parseFailMessage);

export const TWO_SIP_FAIL_MESSAGES: FailCopy[] = ALL_FAIL_MESSAGES.filter(
  (m) => m.isTwoSip
);
