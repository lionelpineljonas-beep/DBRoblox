"""Static check for use-before-declaration of top-level locals in the Luau sources.

In Lua, a function body that references a local declared LATER in the file silently
captures a (nil) global instead — no syntax error, just a runtime crash. This burned
us once (addProductDisplay referenced productPart before its declaration); this check
makes the whole bug class impossible to ship again.
"""

import re
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FILES = ["build.luau", "DiscoveryBayShop.luau", "DiscoveryBayClient.luau"]

# names provided by Roblox / Lua itself
BUILTINS = set("""
game workspace script math string table task Instance Vector3 Vector2 CFrame Color3
UDim UDim2 Enum Random RaycastParams TweenInfo print warn pcall ipairs pairs type
tostring tonumber os assert error select unpack require next
""".split())

fail = False
for fname in FILES:
    path = os.path.join(ROOT, fname)
    src = open(path, encoding="utf-8").read()
    lines = src.splitlines()

    # strip comments and strings so identifiers inside them don't count
    def clean(line):
        line = re.sub(r'"(?:[^"\\]|\\.)*"', '""', line)
        line = re.sub(r"'(?:[^'\\]|\\.)*'", "''", line)
        line = re.sub(r"--.*$", "", line)
        return line

    cleaned = [clean(l) for l in lines]
    # long strings/comments: crude removal of [[...]] spans line-by-line is unsafe;
    # skip lines inside [[ ]] blocks
    in_long = False
    for i, l in enumerate(cleaned):
        if in_long:
            if "]]" in l:
                cleaned[i] = l.split("]]", 1)[1]
                in_long = False
            else:
                cleaned[i] = ""
        if "[[" in cleaned[i] and "]]" not in cleaned[i].split("[[", 1)[1]:
            cleaned[i] = cleaned[i].split("[[", 1)[0]
            in_long = True

    # top-level local declarations (column 0) are what we verify; declarations at ANY
    # indentation also count as "the name exists from here on" so legitimate
    # function-locals that shadow a later top-level name aren't false positives
    decls = {}
    earliest = {}
    for i, l in enumerate(cleaned):
        stripped = l.lstrip()
        m = re.match(r"local function ([A-Za-z_]\w*)", stripped)
        if m:
            earliest.setdefault(m.group(1), i)
            if lines[i].startswith("local"):
                decls.setdefault(m.group(1), i)
        m = re.match(r"local ([A-Za-z_]\w*(?:\s*,\s*[A-Za-z_]\w*)*)\s*=", stripped)
        if m:
            for name in re.split(r"\s*,\s*", m.group(1)):
                earliest.setdefault(name, i)
                if lines[i].startswith("local"):
                    decls.setdefault(name, i)

    for name, decl_line in decls.items():
        if name in BUILTINS:
            continue
        first_seen = min(decl_line, earliest.get(name, decl_line))
        pat = re.compile(r"(?<![\w.:])" + re.escape(name) + r"(?![\w])")
        for i in range(first_seen):
            for m in pat.finditer(cleaned[i]):
                rest = cleaned[i][m.end():]
                if re.match(r"\s*=[^=]", rest):
                    continue  # table key or assignment target, not a value reference
                print(f"{fname}:{i + 1}: uses '{name}' before its declaration at line {decl_line + 1}")
                print(f"    {lines[i].strip()}")
                fail = True
                break

if fail:
    print("\nSCOPE CHECK FAILED")
    sys.exit(1)
print("scope check OK: no top-level local is referenced before its declaration")
