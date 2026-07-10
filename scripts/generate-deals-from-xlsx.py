"""Generate src/data/dealsAndEvents.ts from the Columbus Bars spreadsheet."""
from __future__ import annotations

import json
import re
import zipfile
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
XLSX = ROOT / "temporary" / "Columbus Bars Deals and Events v3.xlsx"
OUT = ROOT / "src" / "data" / "dealsAndEvents.ts"

NS = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}

SHEET_BAR_ALIASES: dict[str, str] = {
    "Fourth Street": "Fourth Street Taproom",
    "Fourth Street Taproom": "Fourth Street Taproom",
    "Big Bar": "Big Bar / Sky Bar",
    "Sky Bar": "Big Bar / Sky Bar",
    "Good Night John Boy": "Good Night John Boy",
    "GNJB": "Good Night John Boy",
    "Land Grant Brewing": "Land Grant",
    "Land Grant Brewing Co.": "Land Grant",
    "Nocterra": "Nocterra Brewing Co.",
    "Barley": "Barley Brewing Co.",
    "Seventh Son": "Seventh Son Brewing",
    "Highbank": "Highbank Distillery",
    "Ethyl and Tank": "Ethyl & Tank",
    "Out R Inn": "Out-R-Inn",
    "Out R-Inn": "Out-R-Inn",
    "Varsity": "Varsity Club",
    "Go Go": "The Go Go",
    "Draft King": "Draft Kings",
    "DraftKings": "Draft Kings",
    "SNT": "Short North Tavern",
    "Ugly Tuna": "Ugly Tuna 2",
}

TYPE_COLUMNS: list[tuple[int, str]] = [
    (9, "Drink Special"),
    (10, "Food Special"),
    (11, "Event"),
]


def normalize_key(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", value.lower())


def resolve_bar_name(sheet_name: str, app_names: set[str]) -> str | None:
    trimmed = sheet_name.strip()
    if trimmed in app_names:
        return trimmed
    if trimmed in SHEET_BAR_ALIASES:
        return SHEET_BAR_ALIASES[trimmed]
    norm = normalize_key(trimmed)
    alias_norm = {normalize_key(k): v for k, v in SHEET_BAR_ALIASES.items()}
    if norm in alias_norm:
        return alias_norm[norm]
    for name in app_names:
        if normalize_key(name) == norm:
            return name
    for name in app_names:
        n = normalize_key(name)
        if norm in n or n in norm:
            return name
    return None


def col_row(cell_ref: str) -> tuple[str, int]:
    m = re.match(r"([A-Z]+)(\d+)", cell_ref)
    return m.group(1), int(m.group(2))


def col_index(col: str) -> int:
    n = 0
    for ch in col:
        n = n * 26 + (ord(ch) - ord("A") + 1)
    return n - 1


def read_xlsx(path: Path) -> list[list[str]]:
    with zipfile.ZipFile(path) as z:
        ss_root = ET.fromstring(z.read("xl/sharedStrings.xml"))
        strings: list[str] = []
        for si in ss_root.findall("m:si", NS):
            parts = []
            for t in si.iter("{http://schemas.openxmlformats.org/spreadsheetml/2006/main}t"):
                parts.append(t.text or "")
            strings.append("".join(parts))

        wb = ET.fromstring(z.read("xl/workbook.xml"))
        first_rid = wb.find("m:sheets/m:sheet", NS).get(
            "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id"
        )
        rels = ET.fromstring(z.read("xl/_rels/workbook.xml.rels"))
        target = next(rel.get("Target") for rel in rels if rel.get("Id") == first_rid)

        root = ET.fromstring(z.read("xl/" + target.lstrip("/")))
        rows: dict[int, dict[int, str]] = {}
        for row in root.findall(".//m:sheetData/m:row", NS):
            rnum = int(row.get("r"))
            rows[rnum] = {}
            for c in row.findall("m:c", NS):
                ref = c.get("r")
                col, _ = col_row(ref)
                idx = col_index(col)
                t = c.get("t")
                v = c.find("m:v", NS)
                val = v.text if v is not None else ""
                if t == "s":
                    val = strings[int(val)]
                elif t == "inlineStr":
                    is_el = c.find("m:is/m:t", NS)
                    val = is_el.text if is_el is not None else ""
                rows[rnum][idx] = val.strip()

        max_row = max(rows) if rows else 0
        table: list[list[str]] = []
        for r in range(1, max_row + 1):
            if r not in rows:
                continue
            max_col = max(rows[r]) if rows[r] else 0
            table.append([rows[r].get(i, "").strip() for i in range(max_col + 1)])
        return table


def excel_time_to_display(value: str) -> str:
    value = value.strip()
    if not value:
        return ""
    lowered = value.lower()
    if lowered in {"open", "close", "unsure", "varies"}:
        return value.title() if lowered != "unsure" else "Unsure"
    if "midnight" in lowered or "noon" in lowered:
        return value
    try:
        frac = float(value)
    except ValueError:
        return value
    if frac < 0 or frac >= 1:
        return value
    total_minutes = int(round(frac * 24 * 60))
    total_minutes %= 24 * 60
    hour24 = total_minutes // 60
    minute = total_minutes % 60
    period = "am" if hour24 < 12 else "pm"
    hour12 = hour24 % 12 or 12
    if minute == 0:
        return f"{hour12}{period}"
    return f"{hour12}:{minute:02d}{period}"


def format_time_range(start: str, end: str) -> str:
    start_d = excel_time_to_display(start)
    end_d = excel_time_to_display(end)
    if start_d and end_d:
        return f"{start_d}–{end_d}"
    return start_d or end_d


def parse_days(row: list[str]) -> list[int]:
    days: list[int] = []
    for i in range(7):
        flag = row[2 + i] if len(row) > 2 + i else ""
        if flag in {"1", "1.0", "TRUE", "True"}:
            days.append((i + 1) % 7)
    return days


def parse_type_labels(row: list[str]) -> list[str]:
    labels: list[str] = []
    for idx, label in TYPE_COLUMNS:
        flag = row[idx] if len(row) > idx else ""
        if flag in {"1", "1.0", "TRUE", "True"}:
            labels.append(label)
    return labels


@dataclass
class ParsedRow:
    area: str
    bar_name: str
    days_of_week: list[int]
    type_labels: list[str]
    time: str
    title: str
    priority: int | None
    details: str


def parse_rows(table: list[list[str]], app_names: set[str]) -> tuple[list[ParsedRow], list[str]]:
    warnings: list[str] = []
    parsed: list[ParsedRow] = []
    for row in table[2:]:
        if len(row) < 2 or not row[0] or not row[1]:
            continue
        area = row[0]
        resolved = resolve_bar_name(row[1], app_names)
        if not resolved:
            warnings.append(f"Unmapped bar: {row[1]!r} ({area})")
            continue
        days = parse_days(row)
        if not days:
            continue
        type_labels = parse_type_labels(row)
        if not type_labels:
            continue
        time = format_time_range(row[12] if len(row) > 12 else "", row[13] if len(row) > 13 else "")
        title = row[14] if len(row) > 14 else ""
        details = row[16] if len(row) > 16 else ""
        priority_raw = row[15] if len(row) > 15 else ""
        priority: int | None = int(priority_raw) if priority_raw.isdigit() else None
        parsed.append(
            ParsedRow(
                area=area,
                bar_name=resolved,
                days_of_week=days,
                type_labels=type_labels,
                time=time,
                title=title.strip(),
                priority=priority,
                details=details.strip(),
            )
        )
    return parsed, warnings


def ts_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def ts_labels(labels: list[str]) -> str:
    return "[" + ", ".join(ts_string(label) for label in labels) + "]"


def generate_ts(parsed: list[ParsedRow], warnings: list[str]) -> str:
    carousel = sorted([r for r in parsed if r.priority is not None], key=lambda r: r.priority or 0)

    lines: list[str] = [
        "",
        "/**",
        " * Deals & events from Columbus Bars Deals and Events v3.xlsx",
        " * Sheet bar names are mapped to canonical venue names in venues.ts.",
        " */",
        "",
        'export type ListingTypeLabel = "Drink Special" | "Food Special" | "Event";',
        "",
        "export interface BarListing {",
        "  /** Empty when the sheet has no title — details carry the listing text. */",
        "  title: string;",
        "  time: string;",
        "  details: string;",
        "  barName: string;",
        "  typeLabels: ListingTypeLabel[];",
        "}",
        "",
        "interface ScheduleFields {",
        "  area: string;",
        "  daysOfWeek: number[];",
        "  priority?: number;",
        "}",
        "",
        "export type ScheduledListing = BarListing & ScheduleFields;",
        "export type ActivitiesCarouselItem = BarListing & { priority: number };",
        "",
        "export const WEEKDAY_LABELS = [",
        '  "Sunday",',
        '  "Monday",',
        '  "Tuesday",',
        '  "Wednesday",',
        '  "Thursday",',
        '  "Friday",',
        '  "Saturday",',
        "] as const;",
        "",
        "export type WeekdayIndex = 0 | 1 | 2 | 3 | 4 | 5 | 6;",
        "",
        "export const WEEKLY_LISTINGS: ScheduledListing[] = [",
    ]

    for r in parsed:
        pri = f", priority: {r.priority}" if r.priority is not None else ""
        lines.append(
            f"  {{ title: {ts_string(r.title)}, time: {ts_string(r.time)}, details: {ts_string(r.details)}, barName: {ts_string(r.bar_name)}, typeLabels: {ts_labels(r.type_labels)}, area: {ts_string(r.area)}, daysOfWeek: {r.days_of_week}{pri} }},"
        )

    lines.extend(
        [
            "];",
            "",
            "export const ACTIVITIES_CAROUSEL_ITEMS: ActivitiesCarouselItem[] = [",
        ]
    )

    for r in carousel:
        lines.append(
            f"  {{ title: {ts_string(r.title)}, time: {ts_string(r.time)}, details: {ts_string(r.details)}, barName: {ts_string(r.bar_name)}, typeLabels: {ts_labels(r.type_labels)}, priority: {r.priority} }},"
        )

    lines.extend(
        [
            "];",
            "",
            "export type ListingBadgeVariant = \"amber\" | \"violet\" | \"red\";",
            "",
            "export function listingBadgeVariant(",
            "  label: ListingTypeLabel,",
            "  typeLabels: ListingTypeLabel[]",
            '): ListingBadgeVariant {',
            "  const hasEvent = typeLabels.includes(\"Event\");",
            "  const hasSpecial =",
            '    typeLabels.includes("Drink Special") || typeLabels.includes("Food Special");',
            '  if (label === "Event" && hasEvent && hasSpecial) return "red";',
            '  if (label === "Event") return "violet";',
            '  return "amber";',
            "}",
            "",
            "export function listingCardAccent(typeLabels: ListingTypeLabel[]): ListingBadgeVariant {",
            "  const hasEvent = typeLabels.includes(\"Event\");",
            "  const hasSpecial =",
            '    typeLabels.includes("Drink Special") || typeLabels.includes("Food Special");',
            '  if (hasEvent && hasSpecial) return "red";',
            '  if (hasEvent) return "violet";',
            '  return "amber";',
            "}",
            "",
            "/** Omit detail text that duplicates the title. */",
            "export function listingDetailText(title: string, details: string): string {",
            "  const trimmedTitle = title.trim();",
            "  const trimmedDetails = details.trim();",
            "  if (!trimmedDetails) return \"\";",
            "  if (!trimmedTitle) return trimmedDetails;",
            "  if (trimmedDetails === trimmedTitle) return \"\";",
            "  const firstSegment = trimmedDetails.split(\";\")[0]?.trim() ?? \"\";",
            "  if (firstSegment === trimmedTitle) {",
            '    return trimmedDetails.includes(";")',
            "      ? trimmedDetails",
            '          .split(";")',
            "          .slice(1)",
            '          .map((part) => part.trim())',
            "          .filter(Boolean)",
            '          .join("; ")',
            '      : "";',
            "  }",
            "  return trimmedDetails;",
            "}",
            "",
            "function entryMatchesWeekday(entry: { daysOfWeek: number[] }, weekday: WeekdayIndex): boolean {",
            "  return entry.daysOfWeek.includes(weekday);",
            "}",
            "",
            "export type ListingListItem = BarListing;",
            "",
            "export function getListingsForAreaWeekday(",
            "  area: string,",
            "  weekday: WeekdayIndex",
            "): ListingListItem[] {",
            "  return WEEKLY_LISTINGS.filter(",
            "    (entry) => entry.area === area && entryMatchesWeekday(entry, weekday)",
            "  ).map(({ title, time, details, barName, typeLabels }) => ({",
            "    title,",
            "    time,",
            "    details,",
            "    barName,",
            "    typeLabels,",
            "  }));",
            "}",
            "",
            "export function countItemsForArea(area: string): number {",
            "  let n = 0;",
            "  for (let day = 0; day <= 6; day++) {",
            "    n += getListingsForAreaWeekday(area, day as WeekdayIndex).length;",
            "  }",
            "  return n;",
            "}",
            "",
            "/** Activities carousel — priority items only, ascending priority (1…n, then loop). */",
            "export function getActivitiesCarouselItems(_date?: string): ActivitiesCarouselItem[] {",
            "  return [...ACTIVITIES_CAROUSEL_ITEMS].sort((a, b) => a.priority - b.priority);",
            "}",
            "",
        ]
    )

    if warnings:
        lines.insert(2, " * Unmapped sheet bars: " + "; ".join(warnings[:10]))

    return "\n".join(lines) + "\n"


def main() -> None:
    venues_ts = (ROOT / "src" / "data" / "venues.ts").read_text(encoding="utf-8")
    app_names = set(re.findall(r'name:\s*"([^"]+)"', venues_ts))
    table = read_xlsx(XLSX)
    parsed, warnings = parse_rows(table, app_names)
    OUT.write_text(generate_ts(parsed, warnings), encoding="utf-8")
    print(f"Wrote {OUT} ({len(parsed)} rows, {len(warnings)} unmapped bars)")
    if warnings:
        for w in warnings:
            print("  WARN:", w)
    pri = sorted({r.priority for r in parsed if r.priority is not None})
    print("Priorities:", pri)


if __name__ == "__main__":
    main()
