import json
import re
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

path = Path(__file__).resolve().parents[1] / "temporary" / "Columbus Bars Deals and Events v3.xlsx"
ns = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}


def col_row(cell_ref: str):
    m = re.match(r"([A-Z]+)(\d+)", cell_ref)
    return m.group(1), int(m.group(2))


def col_index(col: str) -> int:
    n = 0
    for ch in col:
        n = n * 26 + (ord(ch) - ord("A") + 1)
    return n - 1


with zipfile.ZipFile(path) as z:
    ss_root = ET.fromstring(z.read("xl/sharedStrings.xml"))
    strings = []
    for si in ss_root.findall("m:si", ns):
        parts = []
        for t in si.iter("{http://schemas.openxmlformats.org/spreadsheetml/2006/main}t"):
            parts.append(t.text or "")
        strings.append("".join(parts))

    wb = ET.fromstring(z.read("xl/workbook.xml"))
    sheets = []
    for sh in wb.findall("m:sheets/m:sheet", ns):
        sheets.append(
            (
                sh.get("name"),
                sh.get("{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id"),
            )
        )

    rels = ET.fromstring(z.read("xl/_rels/workbook.xml.rels"))
    rid_to_target = {rel.get("Id"): rel.get("Target") for rel in rels}

    def read_sheet(sheet_path: str):
        root = ET.fromstring(z.read("xl/" + sheet_path.lstrip("/")))
        rows: dict[int, dict[int, str]] = {}
        for row in root.findall(".//m:sheetData/m:row", ns):
            rnum = int(row.get("r"))
            rows[rnum] = {}
            for c in row.findall("m:c", ns):
                ref = c.get("r")
                col, _ = col_row(ref)
                idx = col_index(col)
                t = c.get("t")
                v = c.find("m:v", ns)
                val = v.text if v is not None else ""
                if t == "s":
                    val = strings[int(val)]
                elif t == "inlineStr":
                    is_el = c.find("m:is/m:t", ns)
                    val = is_el.text if is_el is not None else ""
                rows[rnum][idx] = val
        return rows

    all_sheets = {}
    for name, rid in sheets:
        target = rid_to_target[rid]
        rows = read_sheet(target)
        max_row = max(rows) if rows else 0
        table = []
        for r in range(1, max_row + 1):
            if r not in rows:
                continue
            max_col = max(rows[r]) if rows[r] else 0
            table.append([rows[r].get(i, "") for i in range(max_col + 1)])
        all_sheets[name] = table

print(json.dumps(all_sheets, indent=2))
