#!/usr/bin/env python3
"""Generate a polished, marketing-style SVG of the Fabric workspace-level
Private Link topology, then rasterize with scripts/render-fabric-svg.sh (macOS).

Official Microsoft Fabric item icons (docs/diagrams/icons/fabric) are embedded as
base64 data URIs. Azure-side glyphs (user, lock, globe, clients) are drawn inline
so the file is fully self-contained.
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
TEAL = "#117865"
TEAL_TINT = "#eaf5f2"
AZURE = "#0f6cbd"
AZURE_TINT = "#eef6fc"
AZURE_LINE = "#cfe4f7"
RED = "#c1272d"
GREEN = "#1a7f37"
CARD = "#ffffff"
FRAME = "#f5f8fb"
FRAME_BORDER = "#e3e9f0"
# System font (San Francisco on macOS via system-ui) — closest to the Segoe UI look.
FONT = "system-ui,-apple-system,'Segoe UI','Helvetica Neue',Arial,sans-serif"

W, H = 1600, 832
SQ = 1600             # square canvas so macOS qlmanage doesn't center-crop the export
YOFF = (SQ - H) // 2  # vertical centering offset for the design band

MK = {AZURE: "Az", TEAL: "Te", GRAY: "Gy", RED: "Rd", GREEN: "Gn"}

P = []


def data_uri(svg_file: str) -> str:
    raw = (ICONS / svg_file).read_bytes()
    return "data:image/svg+xml;base64," + base64.b64encode(raw).decode()


def esc(s: str) -> str:
    return html.escape(s, quote=True)


def rrect(x, y, w, h, r, fill, stroke="none", sw=1.5, shadow=False, dash=None):
    f = ' filter="url(#soft)"' if shadow else ""
    d = f' stroke-dasharray="{dash}"' if dash else ""
    P.append(
        f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" ry="{r}" '
        f'fill="{fill}" stroke="{stroke}" stroke-width="{sw}"{d}{f}/>'
    )


def text(x, y, s, size=15, color=INK, weight="400", anchor="start", italic=False):
    st = ' font-style="italic"' if italic else ""
    P.append(
        f'<text x="{x}" y="{y}" font-size="{size}" font-weight="{weight}" '
        f'fill="{color}" text-anchor="{anchor}"{st}>{esc(s)}</text>'
    )


def fabric_icon(cx, top, size, svg_file, label):
    P.append(f'<image x="{cx - size/2}" y="{top}" width="{size}" height="{size}" href="{data_uri(svg_file)}"/>')
    text(cx, top + size + 20, label, size=14, color=INK, weight="600", anchor="middle")


def person_badge(cx, cy, s):
    P.append(f'<rect x="{cx-s/2}" y="{cy-s/2}" width="{s}" height="{s}" rx="{s*0.22}" fill="url(#gAzure)" filter="url(#soft)"/>')
    P.append(f'<circle cx="{cx}" cy="{cy - s*0.13}" r="{s*0.15}" fill="#ffffff"/>')
    P.append(f'<path d="M {cx - s*0.24} {cy + s*0.28} a {s*0.24} {s*0.22} 0 0 1 {s*0.48} 0 Z" fill="#ffffff"/>')


def lock_badge(cx, cy, s):
    P.append(f'<rect x="{cx-s/2}" y="{cy-s/2}" width="{s}" height="{s}" rx="{s*0.22}" fill="url(#gAzure)" filter="url(#soft)"/>')
    bw, bh = s * 0.42, s * 0.30
    bx, by = cx - bw / 2, cy - bh * 0.15
    P.append(f'<rect x="{bx}" y="{by}" width="{bw}" height="{bh}" rx="{bh*0.22}" fill="#ffffff"/>')
    r = s * 0.15
    P.append(f'<path d="M {cx - r} {by} v {-r*0.2} a {r} {r} 0 0 1 {2*r} 0 v {r*0.2}" fill="none" stroke="#ffffff" stroke-width="{s*0.07}"/>')
    P.append(f'<circle cx="{cx}" cy="{by + bh*0.5}" r="{s*0.05}" fill="{AZURE}"/>')


def globe(cx, cy, r):
    P.append(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="url(#gGlobe)" stroke="{RED}" stroke-width="2"/>')
    P.append(f'<line x1="{cx-r}" y1="{cy}" x2="{cx+r}" y2="{cy}" stroke="#ffffff" stroke-width="1.5" opacity="0.9"/>')
    P.append(f'<ellipse cx="{cx}" cy="{cy}" rx="{r*0.45}" ry="{r}" fill="none" stroke="#ffffff" stroke-width="1.5" opacity="0.9"/>')
    P.append(f'<ellipse cx="{cx}" cy="{cy}" rx="{r}" ry="{r*0.45}" fill="none" stroke="#ffffff" stroke-width="1.5" opacity="0.5"/>')


def arrow(x1, y1, x2, y2, color, width=2.5, dash=None, marker="end"):
    mk = MK.get(color, "Gy")
    d = f' stroke-dasharray="{dash}"' if dash else ""
    me = f' marker-end="url(#mk{mk})"' if marker in ("end", "both") else ""
    ms = f' marker-start="url(#mkS{mk})"' if marker == "both" else ""
    P.append(
        f'<path d="M {x1} {y1} L {x2} {y2}" fill="none" stroke="{color}" '
        f'stroke-width="{width}" stroke-linecap="round"{d}{me}{ms}/>'
    )


def opath(points, color, width=2.4, dash=None, marker="none"):
    mk = MK.get(color, "Gy")
    d = f' stroke-dasharray="{dash}"' if dash else ""
    me = f' marker-end="url(#mk{mk})"' if marker == "end" else ""
    dd = "M " + " L ".join(f"{x} {y}" for x, y in points)
    P.append(f'<path d="{dd}" fill="none" stroke="{color}" stroke-width="{width}" '
             f'stroke-linejoin="round" stroke-linecap="round"{d}{me}/>')


def g_people(cx, cy, s):
    for dx in (-s * 0.17, s * 0.17):
        P.append(f'<circle cx="{cx+dx}" cy="{cy-s*0.16}" r="{s*0.15}" fill="{AZURE}"/>')
        P.append(f'<path d="M {cx+dx-s*0.25} {cy+s*0.30} a {s*0.25} {s*0.23} 0 0 1 {s*0.50} 0 Z" fill="{AZURE}"/>')


def g_wifi(cx, cy, s):
    for rr in (s * 0.44, s * 0.30, s * 0.16):
        P.append(f'<path d="M {cx-rr} {cy+s*0.12} A {rr} {rr} 0 0 1 {cx+rr} {cy+s*0.12}" '
                 f'fill="none" stroke="{AZURE}" stroke-width="3" stroke-linecap="round"/>')
    P.append(f'<circle cx="{cx}" cy="{cy+s*0.18}" r="{s*0.07}" fill="{AZURE}"/>')


def g_laptop(cx, cy, s):
    P.append(f'<rect x="{cx-s*0.32}" y="{cy-s*0.26}" width="{s*0.64}" height="{s*0.40}" rx="{s*0.05}" fill="{AZURE}"/>')
    P.append(f'<rect x="{cx-s*0.28}" y="{cy-s*0.22}" width="{s*0.56}" height="{s*0.32}" fill="#ffffff"/>')
    P.append(f'<path d="M {cx-s*0.44} {cy+s*0.24} L {cx+s*0.44} {cy+s*0.24} L {cx+s*0.33} {cy+s*0.14} L {cx-s*0.33} {cy+s*0.14} Z" fill="{AZURE}"/>')


def g_phone(cx, cy, s):
    P.append(f'<rect x="{cx-s*0.19}" y="{cy-s*0.33}" width="{s*0.38}" height="{s*0.66}" rx="{s*0.08}" fill="{AZURE}"/>')
    P.append(f'<rect x="{cx-s*0.15}" y="{cy-s*0.25}" width="{s*0.30}" height="{s*0.44}" fill="#ffffff"/>')
    P.append(f'<circle cx="{cx}" cy="{cy+s*0.25}" r="{s*0.045}" fill="#ffffff"/>')


# ============================ layout =========================================
# ---- title ----
text(64, 78, "Workspace Private Link for Fabric", size=42, color=INK, weight="700")
text(66, 120, "Perimeter network security for your workspace", size=22, color=TEAL, weight="600")

# ---- outer frame ----
rrect(48, 156, 1504, 652, 24, FRAME, FRAME_BORDER, 1.5)

# ---- sources ----
rrect(104, 206, 150, 50, 12, "#f3f2f1", "#c8c6c4", 1.5, shadow=True)
text(179, 238, "On-prem", size=16, weight="600", anchor="middle")
rrect(274, 206, 150, 50, 12, "#f3f2f1", "#c8c6c4", 1.5, shadow=True)
text(349, 238, "Azure VNets", size=16, weight="600", anchor="middle")
arrow(179, 258, 179, 320, AZURE, 2.4, dash="5 4")
text(168, 294, "VNet peering", size=12.5, color=AZURE, anchor="end", weight="600")
arrow(349, 258, 349, 320, AZURE, 2.4, dash="5 4")
text(361, 294, "Peering", size=12.5, color=AZURE, weight="600")

# ---- customer vnet ----
rrect(104, 326, 326, 326, 18, "#eef4fb", "#7f9fca", 1.8, dash="9 7")
text(128, 360, "Customer VNet1  (Fabric spoke)", size=15, color="#3a4f6b", weight="700")
person_badge(192, 448, 74)
text(192, 508, "User", size=14.5, weight="600", anchor="middle")
lock_badge(348, 448, 74)
text(348, 508, "Private Endpoint", size=14.5, weight="600", anchor="middle")
rrect(168, 586, 222, 48, 10, "#ffffff", "#c7d6ea", 1.4)
text(279, 616, "pe-subnet", size=14, color=GRAY, weight="600", anchor="middle")

# ---- private link into Fabric (label stacked to fit the narrow gap) ----
text(469, 400, "Azure", size=12.5, color=AZURE, weight="700", anchor="middle")
text(469, 417, "Private Link", size=12.5, color=AZURE, weight="700", anchor="middle")
text(469, 434, "(Workspace", size=11.5, color=AZURE, weight="600", anchor="middle")
text(469, 449, "Level)", size=11.5, color=AZURE, weight="600", anchor="middle")
arrow(390, 468, 508, 468, AZURE, 4.2)

# ---- Fabric tenant panel ----
rrect(510, 202, 872, 470, 22, TEAL_TINT, TEAL, 2.0, shadow=True)
P.append(f'<image x="542" y="216" width="38" height="38" href="{data_uri("fabric_20_color.svg")}"/>')
text(592, 246, "Fabric Tenant", size=25, color=TEAL, weight="700")

# ---- workspace A (private) ----
rrect(534, 274, 392, 356, 16, CARD, "#e4e9ef", 1.4, shadow=True)
text(560, 312, "Workspace A", size=20, weight="700")
text(560, 336, "Private \u2014 public access Disabled", size=13.5, color=GRAY, weight="600")
fabric_icon(604, 360, 64, "lakehouse_64_item.svg", "Lakehouse")
fabric_icon(730, 364, 58, "data_warehouse_32_item.svg", "Warehouse")
fabric_icon(856, 362, 62, "notebook_64_item.svg", "Notebook")
fabric_icon(612, 494, 58, "one_lake_24_color.svg", "OneLake")
fabric_icon(788, 494, 58, "spark_job_direction_32_item.svg", "Spark Job Def.")

# ---- workspace B (public) ----
rrect(966, 274, 392, 356, 16, CARD, "#e4e9ef", 1.4, shadow=True)
text(992, 312, "Workspace B", size=20, weight="700")
text(992, 336, "Public \u2014 via Entra Conditional Access", size=13.5, color=GRAY, weight="600")
fabric_icon(1056, 366, 54, "semantic_model_20_item.svg", "Semantic Model")
fabric_icon(1264, 366, 54, "report_20_item.svg", "Report")
fabric_icon(1056, 496, 58, "pipeline_48_item.svg", "Pipeline")
fabric_icon(1264, 496, 58, "kql_database_48_item.svg", "KQL Database")

# ---- private data access (one-way: private A -> public B) ----
text(946, 404, "Private", size=12, color=TEAL, weight="700", anchor="middle")
text(946, 420, "Data", size=12, color=TEAL, weight="700", anchor="middle")
text(946, 436, "Access", size=12, color=TEAL, weight="700", anchor="middle")
arrow(926, 470, 966, 470, TEAL, 3.0, marker="end")

# ---- public access ----
globe(946, 712, 40)
text(946, 772, "Public Access", size=15, color=RED, weight="700", anchor="middle")
# A: disabled (arrow up into Workspace A)
opath([(906, 694), (726, 694), (726, 632)], RED, 2.6, dash="7 5", marker="end")
rrect(738, 682, 128, 26, 7, "#ffffff", "none", 0)
text(752, 700, "\u2715  Disabled", size=14, color=RED, weight="700")
# B: enabled (arrow up into Workspace B)
opath([(986, 694), (1166, 694), (1166, 632)], GREEN, 2.6, dash="7 5", marker="end")
rrect(1000, 682, 268, 26, 7, "#ffffff", "none", 0)
text(1014, 700, "\u2713  Enabled (with Entra CA)", size=14, color=GREEN, weight="700")

# ---- right: Entra Conditional Access + client devices ----
text(1462, 300, "Entra Conditional", size=13.5, color=INK, weight="700", anchor="middle")
text(1462, 318, "Access Policies", size=13.5, color=INK, weight="700", anchor="middle")
text(1462, 336, "(Tenant Level)", size=12.5, color=GRAY, weight="600", anchor="middle")
person_badge(1430, 436, 62)
text(1430, 494, "Portal / API", size=13, color=GRAY, weight="600", anchor="middle")
text(1430, 510, "users", size=13, color=GRAY, weight="600", anchor="middle")
_clients = [(384, g_people), (448, g_wifi), (512, g_laptop), (576, g_phone)]
for cy, fn in _clients:
    fn(1524, cy, 34)
    arrow(1466, 436, 1506, cy, GRAY, 1.8, dash="4 4", marker="none")

# ============================ assemble =======================================
defs = f'''<defs>
  <filter id="soft" x="-20%" y="-20%" width="140%" height="140%">
    <feDropShadow dx="0" dy="2" stdDeviation="4" flood-color="#0b1a2b" flood-opacity="0.14"/>
  </filter>
  <linearGradient id="gAzure" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#2a8fe0"/><stop offset="1" stop-color="#0f6cbd"/>
  </linearGradient>
  <radialGradient id="gGlobe" cx="0.35" cy="0.30" r="0.85">
    <stop offset="0" stop-color="#5aa9e6"/><stop offset="1" stop-color="#2a6db0"/>
  </radialGradient>
  <marker id="mkAz" viewBox="0 0 10 10" refX="8.5" refY="5" markerWidth="6" markerHeight="6" orient="auto"><path d="M0 0L10 5L0 10z" fill="#0f6cbd"/></marker>
  <marker id="mkTe" viewBox="0 0 10 10" refX="8.5" refY="5" markerWidth="6" markerHeight="6" orient="auto"><path d="M0 0L10 5L0 10z" fill="#117865"/></marker>
  <marker id="mkGy" viewBox="0 0 10 10" refX="8.5" refY="5" markerWidth="6" markerHeight="6" orient="auto"><path d="M0 0L10 5L0 10z" fill="#5b5f66"/></marker>
  <marker id="mkRd" viewBox="0 0 10 10" refX="8.5" refY="5" markerWidth="6" markerHeight="6" orient="auto"><path d="M0 0L10 5L0 10z" fill="#c1272d"/></marker>
  <marker id="mkGn" viewBox="0 0 10 10" refX="8.5" refY="5" markerWidth="6" markerHeight="6" orient="auto"><path d="M0 0L10 5L0 10z" fill="#1a7f37"/></marker>
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
