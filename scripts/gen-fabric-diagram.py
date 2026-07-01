#!/usr/bin/env python3
"""Generate docs/diagrams/05-fabric-private-link.drawio.

Fabric item icons = official Microsoft Fabric icons (docs/diagrams/icons/fabric),
embedded as self-contained data URIs. Azure-side icons use the draw.io built-in
Azure2 library. Re-run after changing layout or icons, then render:
    python3 scripts/gen-fabric-diagram.py && ./scripts/render-diagrams.sh
"""
import base64
import pathlib
import urllib.parse

ROOT = pathlib.Path(__file__).resolve().parents[1]
ICONS = ROOT / "docs" / "diagrams" / "icons" / "fabric"
OUT = ROOT / "docs" / "diagrams" / "05-fabric-private-link.drawio"


def data_uri(svg_file: str) -> str:
    raw = (ICONS / svg_file).read_text(encoding="utf-8")
    # keep from first <svg to end; drop xml declaration/doctype
    idx = raw.find("<svg")
    svg = raw[idx:] if idx >= 0 else raw
    enc = urllib.parse.quote(svg, safe="")
    return "data:image/svg+xml," + enc


def icon(cell_id, label, svg_file, x, y, w=48, h=48, fs=11):
    style = (
        "image;html=1;verticalLabelPosition=bottom;labelPosition=center;"
        f"verticalAlign=top;align=center;fontSize={fs};image={data_uri(svg_file)};"
    )
    return (
        f'<mxCell id="{cell_id}" value="{label}" style="{style}" vertex="1" '
        f'parent="1"><mxGeometry x="{x}" y="{y}" width="{w}" height="{h}" '
        f'as="geometry"/></mxCell>'
    )


def az_icon(cell_id, label, az_path, x, y, w=48, h=48, fs=11):
    style = (
        "image;html=1;verticalLabelPosition=bottom;labelPosition=center;"
        f"verticalAlign=top;align=center;fontSize={fs};image=img/lib/azure2/{az_path};"
    )
    return (
        f'<mxCell id="{cell_id}" value="{label}" style="{style}" vertex="1" '
        f'parent="1"><mxGeometry x="{x}" y="{y}" width="{w}" height="{h}" '
        f'as="geometry"/></mxCell>'
    )


cells = []

# title
cells.append('<mxCell id="title" value="Microsoft Fabric — Workspace-level Private Link (private inbound access)" style="text;html=1;fontSize=18;fontStyle=1;align=center;" vertex="1" parent="1"><mxGeometry x="500" y="16" width="900" height="30" as="geometry"/></mxCell>')

# sources
cells.append('<mxCell id="onprem" value="On-prem" style="rounded=1;whiteSpace=wrap;html=1;fontSize=12;fontStyle=1;fillColor=#f5f5f5;strokeColor=#666666;" vertex="1" parent="1"><mxGeometry x="60" y="70" width="130" height="46" as="geometry"/></mxCell>')
cells.append('<mxCell id="azvnets" value="Azure VNets" style="rounded=1;whiteSpace=wrap;html=1;fontSize=12;fontStyle=1;fillColor=#f5f5f5;strokeColor=#666666;" vertex="1" parent="1"><mxGeometry x="210" y="70" width="130" height="46" as="geometry"/></mxCell>')

# customer vnet (fabric spoke)
cells.append('<mxCell id="custvnet" value="Customer VNet (Fabric spoke)" style="rounded=0;whiteSpace=wrap;html=1;verticalAlign=top;fontSize=12;fontStyle=1;dashed=1;dashPattern=8 8;strokeWidth=2;fillColor=#dae8fc;strokeColor=#6c8ebf;" vertex="1" parent="1"><mxGeometry x="40" y="190" width="420" height="300" as="geometry"/></mxCell>')
cells.append(az_icon("user", "User", "identity/Users.svg", 80, 290))
cells.append(az_icon("pe", "Private Endpoint", "networking/Private_Link.svg", 250, 290))
cells.append('<mxCell id="lock" value="🔒" style="text;html=1;fontSize=18;align=center;" vertex="1" parent="1"><mxGeometry x="300" y="278" width="24" height="24" as="geometry"/></mxCell>')
cells.append(az_icon("vneticon", "pe-subnet", "networking/Virtual_Networks.svg", 256, 400, 40, 40, 10))

# right-side identity
cells.append(az_icon("euser", "Portal / API user", "identity/Users.svg", 1790, 250))
cells.append(az_icon("entra", "Entra Conditional Access&#10;(Tenant Level)", "identity/Azure_Active_Directory.svg", 1660, 250))

# fabric tenant
cells.append('<mxCell id="fabric" value="Fabric Tenant" style="rounded=0;whiteSpace=wrap;html=1;verticalAlign=top;fontSize=16;fontStyle=1;fillColor=#eef6ff;strokeColor=#2f7ed8;strokeWidth=3;" vertex="1" parent="1"><mxGeometry x="560" y="110" width="1060" height="430" as="geometry"/></mxCell>')
cells.append(icon("flogo", "", "fabric_20_color.svg", 700, 118, 30, 30))

# workspace A
cells.append('<mxCell id="wsA" value="Workspace A  (public access Disabled)" style="rounded=0;whiteSpace=wrap;html=1;verticalAlign=top;fontSize=13;fontStyle=1;fillColor=#ffffff;strokeColor=#888888;" vertex="1" parent="1"><mxGeometry x="600" y="180" width="450" height="320" as="geometry"/></mxCell>')
cells.append(icon("a_lh", "Lakehouse", "lakehouse_64_item.svg", 630, 245))
cells.append(icon("a_wh", "Warehouse", "data_warehouse_32_item.svg", 770, 245))
cells.append(icon("a_nb", "Notebook", "notebook_64_item.svg", 910, 245))
cells.append(icon("a_ol", "OneLake", "one_lake_24_color.svg", 630, 350))
cells.append(icon("a_sj", "Spark Job Definition", "spark_job_direction_32_item.svg", 800, 350))
cells.append('<mxCell id="a_note" value="Spark runs in a managed VNet when private link + block-public is on" style="text;html=1;fontSize=10;fontStyle=2;fontColor=#666666;align=left;" vertex="1" parent="1"><mxGeometry x="620" y="450" width="420" height="30" as="geometry"/></mxCell>')

# workspace B
cells.append('<mxCell id="wsB" value="Workspace B  (public access Enabled via Entra CA)" style="rounded=0;whiteSpace=wrap;html=1;verticalAlign=top;fontSize=13;fontStyle=1;fillColor=#ffffff;strokeColor=#888888;" vertex="1" parent="1"><mxGeometry x="1120" y="180" width="450" height="320" as="geometry"/></mxCell>')
cells.append(icon("b_sm", "Semantic Model", "semantic_model_20_item.svg", 1160, 245))
cells.append(icon("b_rp", "Report", "report_20_item.svg", 1320, 245))
cells.append(icon("b_pl", "Pipeline", "pipeline_48_item.svg", 1160, 350))
cells.append(icon("b_kql", "KQL Database", "kql_database_48_item.svg", 1320, 350))

# public access
cells.append('<mxCell id="pub" value="Public Access" style="shape=cloud;whiteSpace=wrap;html=1;fillColor=#f8cecc;strokeColor=#b85450;fontSize=12;fontStyle=1;" vertex="1" parent="1"><mxGeometry x="1010" y="620" width="160" height="90" as="geometry"/></mxCell>')

# edges
cells.append('<mxCell id="e_onprem" style="edgeStyle=orthogonalEdgeStyle;html=1;strokeColor=#5C6BC0;strokeWidth=2;dashed=1;endArrow=classic;fontSize=10;" edge="1" parent="1" source="onprem" target="custvnet"><mxGeometry relative="1" as="geometry"/></mxCell>')
cells.append('<mxCell id="e_onprem_l" value="ExpressRoute / VPN" style="text;html=1;fontSize=10;fontColor=#5C6BC0;" vertex="1" parent="1"><mxGeometry x="40" y="140" width="130" height="18" as="geometry"/></mxCell>')
cells.append('<mxCell id="e_peer" style="edgeStyle=orthogonalEdgeStyle;html=1;strokeColor=#00897B;strokeWidth=2;dashed=1;endArrow=classic;fontSize=10;" edge="1" parent="1" source="azvnets" target="custvnet"><mxGeometry relative="1" as="geometry"/></mxCell>')
cells.append('<mxCell id="e_peer_l" value="Peering" style="text;html=1;fontSize=10;fontColor=#00897B;" vertex="1" parent="1"><mxGeometry x="230" y="140" width="90" height="18" as="geometry"/></mxCell>')
cells.append('<mxCell id="e_user" style="edgeStyle=orthogonalEdgeStyle;html=1;strokeColor=#0078D4;strokeWidth=2;endArrow=classic;" edge="1" parent="1" source="user" target="pe"><mxGeometry relative="1" as="geometry"/></mxCell>')
cells.append('<mxCell id="e_pl" style="edgeStyle=orthogonalEdgeStyle;html=1;strokeColor=#0078D4;strokeWidth=3;endArrow=classic;flowAnimation=1;" edge="1" parent="1" source="pe" target="wsA"><mxGeometry relative="1" as="geometry"/></mxCell>')
cells.append('<mxCell id="e_pl_l" value="Azure Private Link (Workspace Level)" style="text;html=1;fontSize=11;fontColor=#0078D4;fontStyle=1;" vertex="1" parent="1"><mxGeometry x="330" y="250" width="260" height="18" as="geometry"/></mxCell>')
cells.append('<mxCell id="e_sda" style="edgeStyle=orthogonalEdgeStyle;html=1;strokeColor=#2f7ed8;strokeWidth=2;startArrow=classic;endArrow=classic;" edge="1" parent="1" source="wsA" target="wsB"><mxGeometry relative="1" as="geometry"/></mxCell>')
cells.append('<mxCell id="e_sda_l" value="Secure Data Access" style="text;html=1;fontSize=11;fontColor=#2f7ed8;" vertex="1" parent="1"><mxGeometry x="1010" y="150" width="150" height="18" as="geometry"/></mxCell>')
cells.append('<mxCell id="e_pubA" style="edgeStyle=orthogonalEdgeStyle;html=1;strokeColor=#C62828;strokeWidth=2;dashed=1;endArrow=none;" edge="1" parent="1" source="wsA" target="pub"><mxGeometry relative="1" as="geometry"/></mxCell>')
cells.append('<mxCell id="e_pubA_l" value="✖ Disabled" style="text;html=1;fontSize=11;fontColor=#C62828;fontStyle=1;" vertex="1" parent="1"><mxGeometry x="820" y="560" width="120" height="18" as="geometry"/></mxCell>')
cells.append('<mxCell id="e_pubB" style="edgeStyle=orthogonalEdgeStyle;html=1;strokeColor=#43A047;strokeWidth=2;dashed=1;endArrow=none;" edge="1" parent="1" source="wsB" target="pub"><mxGeometry relative="1" as="geometry"/></mxCell>')
cells.append('<mxCell id="e_pubB_l" value="✔ Enabled with Entra Conditional Access" style="text;html=1;fontSize=11;fontColor=#43A047;fontStyle=1;" vertex="1" parent="1"><mxGeometry x="1190" y="560" width="290" height="18" as="geometry"/></mxCell>')
cells.append('<mxCell id="e_euser" style="edgeStyle=orthogonalEdgeStyle;html=1;strokeColor=#F57C00;strokeWidth=2;endArrow=classic;" edge="1" parent="1" source="euser" target="entra"><mxGeometry relative="1" as="geometry"/></mxCell>')
cells.append('<mxCell id="e_entra" style="edgeStyle=orthogonalEdgeStyle;html=1;strokeColor=#F57C00;strokeWidth=2;endArrow=classic;" edge="1" parent="1" source="entra" target="wsB"><mxGeometry relative="1" as="geometry"/></mxCell>')

body = "\n        ".join(cells)
xml = (
    '<mxfile host="app.diagrams.net">\n'
    '  <diagram name="FabricPrivateLink" id="fab-1">\n'
    '    <mxGraphModel dx="1422" dy="820" grid="0" gridSize="10" guides="1" '
    'tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" '
    'pageWidth="1880" pageHeight="820" math="0" shadow="0">\n'
    "      <root>\n"
    '        <mxCell id="0"/>\n'
    '        <mxCell id="1" parent="0"/>\n'
    f"        {body}\n"
    "      </root>\n"
    "    </mxGraphModel>\n"
    "  </diagram>\n"
    "</mxfile>\n"
)
OUT.write_text(xml, encoding="utf-8")
print(f"wrote {OUT}  ({len(xml)} bytes)")
