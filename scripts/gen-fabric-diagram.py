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

# ---- title + subtitle ----
cells.append('<mxCell id="title" value="Workspace-level Private Link for Microsoft Fabric" style="text;html=1;fontSize=26;fontStyle=1;align=left;fontColor=#242424;" vertex="1" parent="1"><mxGeometry x="60" y="24" width="1100" height="34" as="geometry"/></mxCell>')
cells.append('<mxCell id="subtitle" value="Perimeter network security: private inbound access + private data access" style="text;html=1;fontSize=15;align=left;fontColor=#0f6cbd;" vertex="1" parent="1"><mxGeometry x="62" y="62" width="1100" height="24" as="geometry"/></mxCell>')

# ---- sources ----
cells.append('<mxCell id="onprem" value="On-prem" style="rounded=1;whiteSpace=wrap;html=1;fontSize=12;fontStyle=1;fillColor=#f3f2f1;strokeColor=#8a8886;" vertex="1" parent="1"><mxGeometry x="70" y="120" width="130" height="44" as="geometry"/></mxCell>')
cells.append('<mxCell id="azvnets" value="Azure VNets" style="rounded=1;whiteSpace=wrap;html=1;fontSize=12;fontStyle=1;fillColor=#f3f2f1;strokeColor=#8a8886;" vertex="1" parent="1"><mxGeometry x="215" y="120" width="130" height="44" as="geometry"/></mxCell>')

# ---- customer vnet (fabric spoke) ----
cells.append('<mxCell id="custvnet" value="Customer VNet1 (Fabric spoke)" style="rounded=1;whiteSpace=wrap;html=1;verticalAlign=top;fontSize=12;fontStyle=1;dashed=1;dashPattern=8 6;strokeWidth=2;fillColor=#eef6fc;strokeColor=#6c8ebf;spacingTop=6;" vertex="1" parent="1"><mxGeometry x="50" y="220" width="360" height="300" as="geometry"/></mxCell>')
cells.append(az_icon("user", "User", "identity/Users.svg", 90, 320))
cells.append(az_icon("pe", "Private Endpoint", "networking/Private_Link.svg", 250, 320))
cells.append('<mxCell id="lock" value="&#128274;" style="text;html=1;fontSize=20;align=center;" vertex="1" parent="1"><mxGeometry x="302" y="302" width="26" height="26" as="geometry"/></mxCell>')
cells.append(az_icon("vneticon", "pe-subnet", "networking/Virtual_Networks.svg", 256, 430, 40, 40, 10))

# ---- right-side identity + clients ----
cells.append(az_icon("entra", "Entra Conditional Access&#10;Policies (Tenant Level)", "identity/Azure_Active_Directory.svg", 1476, 250, 48, 48, 11))
cells.append(az_icon("euser", "Portal / API users&#10;(browser, Teams, apps)", "identity/Users.svg", 1476, 405, 48, 48, 11))

# ---- fabric tenant ----
cells.append('<mxCell id="fabric" value="Fabric Tenant" style="rounded=1;whiteSpace=wrap;html=1;verticalAlign=top;fontSize=16;fontStyle=1;fillColor=#e9f4fb;strokeColor=#0f6cbd;strokeWidth=3;spacingLeft=44;spacingTop=8;" vertex="1" parent="1"><mxGeometry x="440" y="150" width="960" height="400" as="geometry"/></mxCell>')
cells.append(icon("flogo", "", "fabric_20_color.svg", 452, 156, 30, 30))

# ---- workspace A (private) ----
cells.append('<mxCell id="wsA" value="Workspace A &#8212; public access Disabled (private)" style="rounded=1;whiteSpace=wrap;html=1;verticalAlign=top;fontSize=13;fontStyle=1;fillColor=#ffffff;strokeColor=#a19f9d;spacingTop=6;" vertex="1" parent="1"><mxGeometry x="470" y="205" width="390" height="300" as="geometry"/></mxCell>')
cells.append(icon("a_lh", "Lakehouse", "lakehouse_64_item.svg", 500, 262))
cells.append(icon("a_wh", "Warehouse", "data_warehouse_32_item.svg", 630, 262))
cells.append(icon("a_nb", "Notebook", "notebook_64_item.svg", 760, 262))
cells.append(icon("a_ol", "OneLake", "one_lake_24_color.svg", 500, 372))
cells.append(icon("a_sj", "Spark Job Definition", "spark_job_direction_32_item.svg", 650, 372))
cells.append('<mxCell id="a_note" value="Closed from the public internet; Spark runs in a managed VNet" style="text;html=1;fontSize=10;fontStyle=2;fontColor=#605e5c;align=left;" vertex="1" parent="1"><mxGeometry x="490" y="462" width="360" height="30" as="geometry"/></mxCell>')

# ---- private data access (between A and B) ----
cells.append('<mxCell id="e_sda_l" value="Private&#10;Data&#10;Access" style="text;html=1;fontSize=11;fontColor=#0f6cbd;fontStyle=1;align=center;" vertex="1" parent="1"><mxGeometry x="866" y="320" width="86" height="54" as="geometry"/></mxCell>')

# ---- workspace B (public via Entra CA) ----
cells.append('<mxCell id="wsB" value="Workspace B &#8212; public via Entra Conditional Access" style="rounded=1;whiteSpace=wrap;html=1;verticalAlign=top;fontSize=13;fontStyle=1;fillColor=#ffffff;strokeColor=#a19f9d;spacingTop=6;" vertex="1" parent="1"><mxGeometry x="960" y="205" width="410" height="300" as="geometry"/></mxCell>')
cells.append(icon("b_sm", "Semantic Model", "semantic_model_20_item.svg", 1000, 262))
cells.append(icon("b_rp", "Report", "report_20_item.svg", 1180, 262))
cells.append(icon("b_pl", "Pipeline", "pipeline_48_item.svg", 1000, 372))
cells.append(icon("b_kql", "KQL Database", "kql_database_48_item.svg", 1180, 372))

# ---- public access globe ----
cells.append('<mxCell id="pub" value="Public Access" style="shape=cloud;whiteSpace=wrap;html=1;fillColor=#fde7e9;strokeColor=#d13438;fontSize=12;fontStyle=1;" vertex="1" parent="1"><mxGeometry x="815" y="620" width="170" height="96" as="geometry"/></mxCell>')

# ---- edges ----
cells.append('<mxCell id="e_onprem" style="edgeStyle=orthogonalEdgeStyle;rounded=1;html=1;strokeColor=#0f6cbd;strokeWidth=2;dashed=1;endArrow=classic;" edge="1" parent="1" source="onprem" target="custvnet"><mxGeometry relative="1" as="geometry"/></mxCell>')
cells.append('<mxCell id="e_onprem_l" value="VNet peering" style="text;html=1;fontSize=10;fontColor=#0f6cbd;" vertex="1" parent="1"><mxGeometry x="58" y="184" width="120" height="18" as="geometry"/></mxCell>')
cells.append('<mxCell id="e_peer" style="edgeStyle=orthogonalEdgeStyle;rounded=1;html=1;strokeColor=#0f6cbd;strokeWidth=2;dashed=1;endArrow=classic;" edge="1" parent="1" source="azvnets" target="custvnet"><mxGeometry relative="1" as="geometry"/></mxCell>')
cells.append('<mxCell id="e_peer_l" value="Peering" style="text;html=1;fontSize=10;fontColor=#0f6cbd;" vertex="1" parent="1"><mxGeometry x="240" y="184" width="90" height="18" as="geometry"/></mxCell>')
cells.append('<mxCell id="e_user" style="edgeStyle=orthogonalEdgeStyle;rounded=1;html=1;strokeColor=#323130;strokeWidth=2;endArrow=classic;" edge="1" parent="1" source="user" target="pe"><mxGeometry relative="1" as="geometry"/></mxCell>')
cells.append('<mxCell id="e_pl" style="edgeStyle=orthogonalEdgeStyle;rounded=1;html=1;strokeColor=#0f6cbd;strokeWidth=3;endArrow=classic;" edge="1" parent="1" source="pe" target="wsA"><mxGeometry relative="1" as="geometry"/></mxCell>')
cells.append('<mxCell id="e_pl_l" value="Azure Private Link&#10;(Workspace Level)" style="text;html=1;fontSize=11;fontColor=#0f6cbd;fontStyle=1;align=center;" vertex="1" parent="1"><mxGeometry x="352" y="250" width="120" height="34" as="geometry"/></mxCell>')
cells.append('<mxCell id="e_sda" style="edgeStyle=orthogonalEdgeStyle;rounded=1;html=1;strokeColor=#0f6cbd;strokeWidth=2;startArrow=classic;endArrow=classic;dashed=1;" edge="1" parent="1" source="wsA" target="wsB"><mxGeometry relative="1" as="geometry"/></mxCell>')
cells.append('<mxCell id="e_pubA" style="edgeStyle=orthogonalEdgeStyle;rounded=1;html=1;strokeColor=#d13438;strokeWidth=2;dashed=1;endArrow=none;" edge="1" parent="1" source="wsA" target="pub"><mxGeometry relative="1" as="geometry"/></mxCell>')
cells.append('<mxCell id="e_pubA_l" value="&#10005; Disabled" style="text;html=1;fontSize=12;fontColor=#d13438;fontStyle=1;" vertex="1" parent="1"><mxGeometry x="640" y="560" width="120" height="18" as="geometry"/></mxCell>')
cells.append('<mxCell id="e_pubB" style="edgeStyle=orthogonalEdgeStyle;rounded=1;html=1;strokeColor=#107c10;strokeWidth=2;dashed=1;endArrow=none;" edge="1" parent="1" source="wsB" target="pub"><mxGeometry relative="1" as="geometry"/></mxCell>')
cells.append('<mxCell id="e_pubB_l" value="&#10003; Enabled (with Entra Conditional Access)" style="text;html=1;fontSize=12;fontColor=#107c10;fontStyle=1;" vertex="1" parent="1"><mxGeometry x="1010" y="560" width="320" height="18" as="geometry"/></mxCell>')
cells.append('<mxCell id="e_euser" style="edgeStyle=orthogonalEdgeStyle;rounded=1;html=1;strokeColor=#605e5c;strokeWidth=2;endArrow=classic;" edge="1" parent="1" source="euser" target="entra"><mxGeometry relative="1" as="geometry"/></mxCell>')
cells.append('<mxCell id="e_entra" style="edgeStyle=orthogonalEdgeStyle;rounded=1;html=1;strokeColor=#605e5c;strokeWidth=2;endArrow=classic;" edge="1" parent="1" source="entra" target="wsB"><mxGeometry relative="1" as="geometry"/></mxCell>')

# ---- bottom captions ----
cells.append('<mxCell id="cap1" value="Selected workspaces can be protected with Private Links and closed from the public internet." style="rounded=1;whiteSpace=wrap;html=1;fontSize=11;align=center;verticalAlign=middle;fillColor=#eef6fc;strokeColor=#c7e0f4;" vertex="1" parent="1"><mxGeometry x="60" y="775" width="470" height="70" as="geometry"/></mxCell>')
cells.append('<mxCell id="cap2" value="A secure connection between public and private workspaces uses private data access." style="rounded=1;whiteSpace=wrap;html=1;fontSize=11;align=center;verticalAlign=middle;fillColor=#eef6fc;strokeColor=#c7e0f4;" vertex="1" parent="1"><mxGeometry x="555" y="775" width="470" height="70" as="geometry"/></mxCell>')
cells.append('<mxCell id="cap3" value="Public workspaces are secured through Entra Conditional Access policies (for example, Power BI)." style="rounded=1;whiteSpace=wrap;html=1;fontSize=11;align=center;verticalAlign=middle;fillColor=#eef6fc;strokeColor=#c7e0f4;" vertex="1" parent="1"><mxGeometry x="1050" y="775" width="490" height="70" as="geometry"/></mxCell>')

body = "\n        ".join(cells)
xml = (
    '<mxfile host="app.diagrams.net">\n'
    '  <diagram name="FabricPrivateLink" id="fab-1">\n'
    '    <mxGraphModel dx="1422" dy="820" grid="0" gridSize="10" guides="1" '
    'tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" '
    'pageWidth="1620" pageHeight="900" math="0" shadow="0">\n'
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
