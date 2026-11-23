#!/usr/bin/env python3
# Sistemdeki lupdate QML okuyamadığı için kaynak metinleri burada topluyoruz.
# Var olan çeviriler korunur, yeni metinler "unfinished" olarak eklenir.
import html, pathlib, re, sys
import xml.etree.ElementTree as ET

app = pathlib.Path(__file__).resolve().parent.parent
ts = app / "i18n" / "pinna_en.ts"
old = {}
if ts.exists():
    for m in ET.parse(ts).getroot().iter("message"):
        t = m.find("translation")
        if t is not None and t.text and t.get("type") != "unfinished":
            old[m.find("source").text] = t.text

pat = re.compile(r'\b(?:qsTr|tr)\("((?:[^"\\]|\\.)*)"')
contexts = {}
for f in sorted(list((app / "qml").glob("*.qml")) + list((app / "src").glob("*.cpp"))):
    name = f.stem if f.suffix == ".qml" else {"backend": "Backend", "tray": "Tray"}.get(f.stem, f.stem)
    for s in pat.findall(f.read_text()):
        s = s.encode().decode("unicode_escape").encode("latin-1").decode()
        contexts.setdefault(name, [])
        if s not in contexts[name]:
            contexts[name].append(s)

out = ['<?xml version="1.0" encoding="utf-8"?>', "<!DOCTYPE TS>", '<TS version="2.1" language="en_US" sourcelanguage="tr_TR">']
missing = 0
for ctx, msgs in contexts.items():
    out.append(f"<context>\n    <name>{ctx}</name>")
    for s in msgs:
        tr = old.get(s)
        missing += tr is None
        t = f"<translation>{html.escape(tr, False)}</translation>" if tr else '<translation type="unfinished"></translation>'
        out.append(f"    <message>\n        <source>{html.escape(s, False)}</source>\n        {t}\n    </message>")
    out.append("</context>")
out.append("</TS>")
ts.write_text("\n".join(out) + "\n")
print(f"{ts.name}: {sum(map(len, contexts.values()))} metin, {missing} çevrilmemiş", file=sys.stderr)
