"""Package the Discovery Bay build into a ready-to-open Roblox place file.

Emits ../DiscoveryBay.rbxlx containing:
  Workspace (StreamingEnabled = true)
  ServerScriptService
    ModuleScript "DiscoveryBayData"   (full data module)
    Script       "DiscoveryBayBuild"  (the generator)
    ModuleScript "README - HOW TO BUILD"

The user opens the file in Studio and runs one command-bar line.
"""

import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

data_src = open(os.path.join(ROOT, "DiscoveryBayData.luau"), encoding="utf-8").read()
build_src = open(os.path.join(ROOT, "build.luau"), encoding="utf-8").read()
shop_src = open(os.path.join(ROOT, "DiscoveryBayShop.luau"), encoding="utf-8").read()
client_src = open(os.path.join(ROOT, "DiscoveryBayClient.luau"), encoding="utf-8").read()

readme_src = """--[[
====================================================================
 DISCOVERY BAY, CA
====================================================================
 EASIEST: just press PLAY. The town builds itself in ~10 seconds
 and you spawn at the plaza on Discovery Bay Blvd.
 (A Play-mode build disappears when you press Stop.)

 TO MAKE IT PERMANENT (so it opens already built):
 1. In edit mode (not playing), open the Command Bar
    (menu bar: Window or View -> Command Bar).
 2. Paste this line and press Ctrl+Enter:

 loadstring(game.ServerScriptService.DiscoveryBayBuild.Source)()

 3. Wait for "[DiscoveryBay] DONE" in Output, then Ctrl+S to save.

 Re-running is always safe: it deletes the previous town and
 rebuilds identically. Settings (scale, trees, boats, region) are
 in the CONFIG table at the top of DiscoveryBayBuild.
====================================================================
]]
return true
"""


def cdata(text):
    # CDATA cannot contain "]]>" — split it across sections if it ever appears
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def script_item(class_name, name, source, ref):
    return f"""    <Item class="{class_name}" referent="RBX{ref}">
      <Properties>
        <string name="Name">{name}</string>
        <ProtectedString name="Source">{cdata(source)}</ProtectedString>
      </Properties>
    </Item>"""


xml = f"""<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">
  <Item class="Workspace" referent="RBX1">
    <Properties>
      <bool name="StreamingEnabled">true</bool>
    </Properties>
  </Item>
  <Item class="ServerScriptService" referent="RBX2">
{script_item("ModuleScript", "DiscoveryBayData", data_src, 3)}
{script_item("Script", "DiscoveryBayBuild", build_src, 4)}
{script_item("Script", "DiscoveryBayShop", shop_src, 6)}
{script_item("ModuleScript", "README - HOW TO BUILD", readme_src, 5)}
  </Item>
  <Item class="StarterPlayer" referent="RBX7">
    <Item class="StarterPlayerScripts" referent="RBX8">
{script_item("LocalScript", "DiscoveryBayClient", client_src, 9)}
    </Item>
  </Item>
</roblox>
"""

out = os.path.join(ROOT, "DiscoveryBay.rbxlx")
with open(out, "w", encoding="utf-8") as f:
    f.write(xml)
print(f"wrote {out} ({os.path.getsize(out)/1024:.0f} KB)")

# validate well-formedness + that sources survived intact
import xml.etree.ElementTree as ET

tree = ET.parse(out)
sources = {}
for item in tree.iter("Item"):
    name, src = None, None
    props = item.find("Properties")
    if props is None:
        continue
    for p in props:
        if p.get("name") == "Name":
            name = p.text
        if p.get("name") == "Source":
            src = p.text or ""
    if name and src is not None:
        sources[name] = src

assert sources["DiscoveryBayData"] == data_src, "data source mangled"
assert sources["DiscoveryBayBuild"] == build_src, "build source mangled"
assert sources["DiscoveryBayShop"] == shop_src, "shop source mangled"
assert sources["DiscoveryBayClient"] == client_src, "client source mangled"
print("XML valid; all four script sources round-trip byte-identical.")
