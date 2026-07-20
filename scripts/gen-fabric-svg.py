#!/usr/bin/env python3
"""Generate a polished, marketing-style SVG of the Fabric workspace-level
Private Link topology, then it can be rasterized to PNG (macOS):

    python3 scripts/gen-fabric-svg.py
    qlmanage -t -s 3200 -o docs/images /tmp/fabric.svg   # or use the wrapper below

Official Microsoft Fabric item icons (docs/diagrams/icons/fabric) are embedded as
base64 data URIs. Azure-side glyphs (user, lock, globe, shield, clients) are drawn
inline so the file is fully self-contained.
"""
import base64
import html
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
ICONS = ROOT / "docs" / "diagrams" / "icons" / "fabric"
OUT_SVG = ROOT / "docs" / "diagrams" / "05-fabric-private-link.svg"

# ---- palette ----------------------------------------------------------------
INK = "#20242b"
GRAY = "#5b5f66"
TEAL = "#117865"       # Fabric brand teal-green
TEAL_TINT = "#eaf5f2"
AZURE = "#0f6cbd"
AZURE_TINT = "#eef6fc"
AZURE_LINE = "#cfe4f7"
RED = "#c1272d"
GREEN = "#1a7f37"
CARD = "#ffffff"
FRAME = "#f5f8fb"
FRAME_BORDER = "#e3e9f0"
FONT = "'Helvetica Neue','Segoe UI',Arial,sans-serif"

W, H = 1600, 900
SQ = 1600            # square canvas so macOS qlmanage doesn't center-crop the export
YOFF = (SQ - H) // 2  # vertical centering offset for the design band


def data_uri(svg_file: str) -> str:
    raw = (ICONS / svg_file).read_bytes()
    return "data:image/svg+xml;base64," + base64.b64encode(raw).decode()


def esc(s: str) -> str:
    return html.escape(s, quote=True)


P = []  # svg body parts


def rrect(x, y, w, h, r, fill, stroke="none", sw=1.5, shadow=False, dash=None, opacity=1.0):
    f = ' filter="url(#soft)"' if shadow else ""
    d = f' stroke-dasharray="{dash}"' if dash else ""
    P.append(
        f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" ry="{r}" '
        f'fill="{fill}" fill-opacity="{opacity}" stroke="{stroke}" stroke-width="{sw}"{d}{f}/>'
    )


def text(x, y, s, size=15, color=INK, weight="400", anchor="start", italic=False, spacing="0"):
    st = ' font-style="italic"' if italic else ""
    P.append(
        f'<text x="{x}" y="{y}" font-family="{FONT}" font-size="{size}" '
        f'font-weight="{weight}" fill="{color}" text-anchor="{anchor}" '
        f'letter-spacing="{spacing}"{st}>{esc(s)}</text>'
    )


def fabric_icon(cx, top, size, svg_file, label):
    x = cx - size / 2
    P.append(f'<image x="{x}" y="{top}" width="{size}" height="{size}" href="{data_uri(svg_file)}"/>')
    text(cx, top + size + 16, label, size=12.5, color=INK, weight="600", anchor="middle")


def person_badge(cx, cy, s, color):
    x, y = cx - s / 2, cy - s / 2
    P.append(f'<rect x="{x}" y="{y}" width="{s}" height="{s}" rx="{s*0.22}" fill="url(#gAzure)" filter="url(#soft)"/>')
    hr = s * 0.15
    P.append(f'<circle cx="{cx}" cy="{cy - s*0.13}" r="{hr}" fill="#ffffff"/>')
    P.append(
        f'<path d="M {cx - s*0.24} {cy + s*0.28} '
        f'a {s*0.24} {s*0.22} 0 0 1 {s*0.48} 0 Z" fill="#ffffff"/>'
    )


def lock_badge(cx, cy, s, color):
    x, y = cx - s / 2, cy - s / 2
    P.append(f'<rect x="{x}" y="{y}" width="{s}" height="{s}" rx="{s*0.22}" fill="url(#gAzure)" filter="url(#soft)"/>')
    bw, bh = s * 0.42, s * 0.30
    bx, by = cx - bw / 2, cy - bh * 0.15
    P.append(f'<rect x="{bx}" y="{by}" width="{bw}" height="{bh}" rx="{bh*0.22}" fill="#ffffff"/>')
    r = s * 0.15
    P.append(
        f'<path d="M {cx - r} {by} v {-r*0.2} a {r} {r} 0 0 1 {2*r} 0 v {r*0.2}" '
        f'fill="none" stroke="#ffffff" stroke-width="{s*0.07}"/>'
    )
    P.append(f'<circle cx="{cx}" cy="{by + bh*0.5}" r="{s*0.05}" fill="{AZURE}"/>')


def shield_badge(cx, cy, s, color):
    x, y = cx - s / 2, cy - s / 2
    P.append(f'<rect x="{x}" y="{y}" width="{s}" height="{s}" rx="{s*0.22}" fill="url(#gTeal)" filter="url(#soft)"/>')
    P.append(
        f'<path d="M {cx} {cy - s*0.28} L {cx + s*0.22} {cy - s*0.16} '
        f'V {cy + s*0.06} Q {cx + s*0.22} {cy + s*0.24} {cx} {cy + s*0.30} '
        f'Q {cx - s*0.22} {cy + s*0.24} {cx - s*0.22} {cy + s*0.06} '
        f'V {cy - s*0.16} Z" fill="#ffffff"/>'
    )
    P.append(
        f'<path d="M {cx - s*0.09} {cy + s*0.01} l {s*0.07} {s*0.07} l {s*0.13} {-s*0.14}" '
        f'fill="none" stroke="{TEAL}" stroke-width="{s*0.05}" stroke-linecap="round" stroke-linejoin="round"/>'
    )


def globe(cx, cy, r):
    P.append(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="url(#gGlobe)" stroke="{RED}" stroke-width="2"/>')
    P.append(f'<line x1="{cx-r}" y1="{cy}" x2="{cx+r}" y2="{cy}" stroke="#ffffff" stroke-width="1.4" opacity="0.9"/>')
    P.append(f'<ellipse cx="{cx}" cy="{cy}" rx="{r*0.45}" ry="{r}" fill="none" stroke="#ffffff" stroke-width="1.4" opacity="0.9"/>')
    P.append(f'<ellipse cx="{cx}" cy="{cy}" rx="{r}" ry="{r*0.45}" fill="none" stroke="#ffffff" stroke-width="1.4" opacity="0.5"/>')


def arrow(x1, y1, x2, y2, color, width=2.5, dash=None, marker="end", opacity=1.0):
    d = f' stroke-dasharray="{dash}"' if dash else ""
    me = ' marker-end="url(#arrow)"' if marker in ("end", "both") else ""
    ms = ' marker-start="url(#arrowS)"' if marker in ("both",) else ""
    P.append(
        f'<path d="M {x1} {y1} L {x2} {y2}" fill="none" stroke="{color}" '
        f'stroke-width="{width}" stroke-linecap="round"{d} opacity="{opacity}"{me}{ms}/>'
    )


# ---- background + defs -------------------------------------------------------
# (background is emitted in the assembly step so it fills the square canvas)

# ---- title ------------------------------------------------------------------
text(64, 74, "Workspace Private Link for Fabric", size=40, color=INK, weight="700")
text(66, 114, "Perimeter network security for your workspace", size=21, color=TEAL, weight="600")

# ---- outer frame ------------------------------------------------------------
rrect(48, 150, 1504, 560, 22, FRAME, FRAME_BORDER, 1.5)

# ---- left: sources ----------------------------------------------------------
rrect(96, 196, 132, 42, 10, "#f3f2f1", "#c8c6c4", 1.5, shadow=True)
text(162, 222, "On-prem", size=14, weight="600", anchor="middle")
rrect(244, 196, 132, 42, 10, "#f3f2f1", "#c8c6c4", 1.5, shadow=True)
text(310, 222, "Azure VNets", size=14, weight="600", anchor="middle")

# peering arrows down into customer vnet
arrow(162, 240, 162, 292, AZURE, 2.2, dash="5 4")
text(150, 268, "VNet peering", size=11, color=AZURE, anchor="end", weight="600")
arrow(310, 240, 310, 292, AZURE, 2.2, dash="5 4")
text(322, 268, "Peering", size=11, color=AZURE, weight="600")

# customer vnet dashed box
rrect(96, 292, 300, 260, 16, "#eef4fb", "#7f9fca", 1.8, dash="9 7")
text(116, 320, "Customer VNet1  (Fabric spoke)", size=13.5, color="#3a4f6b", weight="700")
person_badge(176, 402, 60, AZURE)
text(176, 452, "User", size=12.5, weight="600", anchor="middle")
lock_badge(316, 402, 60, AZURE)
text(316, 452, "Private Endpoint", size=12.5, weight="600", anchor="middle")
rrect(150, 486, 196, 40, 8, "#ffffff", "#c7d6ea", 1.4)
text(248, 511, "pe-subnet", size=12, color=GRAY, weight="600", anchor="middle")

# ---- private link arrow into Fabric ----------------------------------------
arrow(396, 402, 486, 402, AZURE, 3.4)
rrect(360, 372, 168, 38, 7, "#ffffff", "none", 0)
text(441, 384, "Azure Private Link", size=12.5, color=AZURE, weight="700", anchor="middle")
text(441, 400, "(Workspace Level)", size=11.5, color=AZURE, weight="600", anchor="middle")

# ---- Fabric tenant panel ----------------------------------------------------
rrect(492, 190, 872, 400, 20, TEAL_TINT, TEAL, 2.0, shadow=True)
P.append(f'<image x="514" y="206" width="30" height="30" href="{data_uri("fabric_20_color.svg")}"/>')
text(554, 228, "Fabric Tenant", size=19, color=TEAL, weight="700")

# workspace A (private)
rrect(516, 254, 396, 300, 14, CARD, "#e4e9ef", 1.4, shadow=True)
text(536, 284, "Workspace A", size=15.5, weight="700")
text(536, 304, "Private — public access Disabled", size=11.5, color=GRAY, weight="600")
fabric_icon(576, 322, 52, "lakehouse_64_item.svg", "Lakehouse")
fabric_icon(714, 322, 46, "data_warehouse_32_item.svg", "Warehouse")
fabric_icon(852, 322, 52, "notebook_64_item.svg", "Notebook")
fabric_icon(576, 440, 46, "one_lake_24_color.svg", "OneLake")
fabric_icon(760, 440, 46, "spark_job_direction_32_item.svg", "Spark Job Def.")

# workspace B (public)
rrect(944, 254, 396, 300, 14, CARD, "#e4e9ef", 1.4, shadow=True)
text(964, 284, "Workspace B", size=15.5, weight="700")
text(964, 304, "Public — via Entra Conditional Access", size=11.5, color=GRAY, weight="600")
fabric_icon(1024, 328, 44, "semantic_model_20_item.svg", "Semantic Model")
fabric_icon(1236, 328, 44, "report_20_item.svg", "Report")
fabric_icon(1024, 446, 46, "pipeline_48_item.svg", "Pipeline")
fabric_icon(1236, 446, 46, "kql_database_48_item.svg", "KQL Database")

# private data access between the two cards
arrow(912, 404, 944, 404, TEAL, 2.4, dash="4 4", marker="both")
text(928, 356, "Private", size=11, color=TEAL, weight="700", anchor="middle")
text(928, 370, "Data", size=11, color=TEAL, weight="700", anchor="middle")
text(928, 384, "Access", size=11, color=TEAL, weight="700", anchor="middle")

# ---- right: Entra CA + clients ---------------------------------------------
shield_badge(1454, 300, 60, TEAL)
text(1454, 352, "Entra Conditional", size=12.5, weight="700", anchor="middle")
text(1454, 368, "Access (Tenant)", size=12.5, weight="700", anchor="middle")
person_badge(1454, 452, 56, AZURE)
text(1454, 500, "Portal / API users", size=12, color=GRAY, weight="600", anchor="middle")
arrow(1424, 300, 1340, 320, GRAY, 2.2)
arrow(1454, 424, 1454, 348, GRAY, 2.2)

# ---- public access globe ----------------------------------------------------
globe(928, 646, 34)
text(928, 704, "Public Access", size=13, color=RED, weight="700", anchor="middle")
# A -> globe disabled
arrow(700, 556, 902, 636, RED, 2.2, dash="6 5", marker="none")
rrect(724, 590, 132, 22, 6, "#ffffff", "none", 0)
text(742, 605, "\u2715  Disabled", size=12.5, color=RED, weight="700")
# B -> globe enabled
arrow(1142, 556, 956, 636, GREEN, 2.2, dash="6 5", marker="none")
rrect(1002, 590, 262, 22, 6, "#ffffff", "none", 0)
text(1010, 605, "\u2713  Enabled (with Entra CA)", size=12.5, color=GREEN, weight="700", anchor="start")

# ---- bottom caption bars ----------------------------------------------------
caps = [
    "Selected workspaces are protected with Private Links and closed from the public internet.",
    "A secure link between public and private workspaces uses private data access.",
    "Public workspaces are secured through Entra Conditional Access policies (e.g. Power BI).",
]
cx = 48
cw = (1504 - 2 * 24) / 3
for i, c in enumerate(caps):
    bx = cx + i * (cw + 24)
    rrect(bx, 742, cw, 96, 14, AZURE_TINT, AZURE_LINE, 1.4)
    # simple word-wrap into <= 3 lines
    words, line, lines = c.split(), "", []
    for w in words:
        if len(line) + len(w) + 1 > 46:
            lines.append(line)
            line = w
        else:
            line = (line + " " + w).strip()
    lines.append(line)
    ty = 742 + 96 / 2 - (len(lines) - 1) * 11 + 5
    for ln in lines:
        text(bx + cw / 2, ty, ln, size=13, color="#254a68", weight="600", anchor="middle")
        ty += 22

# ---- assemble ---------------------------------------------------------------
defs = f'''<defs>
  <filter id="soft" x="-20%" y="-20%" width="140%" height="140%">
    <feDropShadow dx="0" dy="2" stdDeviation="4" flood-color="#0b1a2b" flood-opacity="0.14"/>
  </filter>
  <linearGradient id="gAzure" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#2a8fe0"/><stop offset="1" stop-color="#0f6cbd"/>
  </linearGradient>
  <linearGradient id="gTeal" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#1a9e86"/><stop offset="1" stop-color="#117865"/>
  </linearGradient>
  <radialGradient id="gGlobe" cx="0.35" cy="0.30" r="0.85">
    <stop offset="0" stop-color="#5aa9e6"/><stop offset="1" stop-color="#2a6db0"/>
  </radialGradient>
  <marker id="arrow" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
    <path d="M 0 0 L 10 5 L 0 10 z" fill="context-stroke"/>
  </marker>
  <marker id="arrowS" viewBox="0 0 10 10" refX="2" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
    <path d="M 10 0 L 0 5 L 10 10 z" fill="context-stroke"/>
  </marker>
</defs>'''

svg = (
    f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
    f'viewBox="0 0 {SQ} {SQ}" width="{SQ}" height="{SQ}" font-family="{FONT}">\n'
    f'{defs}\n'
    f'<rect x="0" y="0" width="{SQ}" height="{SQ}" fill="#ffffff"/>\n'
    f'<g transform="translate(0,{YOFF})">\n' + "\n".join(P) + "\n</g>\n</svg>\n"
)
OUT_SVG.write_text(svg, encoding="utf-8")
print(f"wrote {OUT_SVG}  ({len(svg)} bytes)")
