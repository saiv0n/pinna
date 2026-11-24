#!/usr/bin/env python3
# The system lupdate cannot read QML, so source strings are collected here.
# Updates every app/i18n/pinna_<lang>.ts; "update.py de" starts a new language.
# Existing translations are kept, new strings are added as "unfinished".
import html, pathlib, re, sys
import xml.etree.ElementTree as ET

app = pathlib.Path(__file__).resolve().parent.parent
langs = sorted({p.stem[len("pinna_"):] for p in (app / "i18n").glob("pinna_*.ts")} | set(sys.argv[1:]))

pat = re.compile(r'\b(?:qsTr|tr)\("((?:[^"\\]|\\.)*)"')
contexts = {}
for f in sorted(list((app / "qml").glob("*.qml")) + list((app / "src").glob("*.cpp"))):
    name = f.stem if f.suffix == ".qml" else {"backend": "Backend", "tray": "Tray", "shortcuts": "Shortcuts"}.get(f.stem, f.stem)
    for s in pat.findall(f.read_text()):
        s = s.encode().decode("unicode_escape").encode("latin-1").decode()
        contexts.setdefault(name, [])
        if s not in contexts[name]:
            contexts[name].append(s)

# error messages from the service are translated by the app under the "Daemon" context
crates = app.parent / "crates" / "linux" / "src"
codes = re.compile(r'"(?:not-connected|invalid|no-device|bluetooth-off|unreachable|busy|pair-failed|audio): ((?:[^"\\]|\\.)*)"')
for f in sorted(crates.glob("*.rs")):
    for s in codes.findall(f.read_text()):
        if re.fullmatch(r"\{\w*\}", s):
            continue
        contexts.setdefault("Daemon", [])
        if s not in contexts["Daemon"]:
            contexts["Daemon"].append(s)

# notifications the service sends, through t("...") in crates/linux
notify = re.compile(r'\bt\("((?:[^"\\]|\\.)*)"\)')
for f in sorted(crates.glob("*.rs")):
    for s in notify.findall(f.read_text()):
        contexts.setdefault("Notify", [])
        if s not in contexts["Notify"]:
            contexts["Notify"].append(s)

for lang in langs:
    ts = app / "i18n" / f"pinna_{lang}.ts"
    old = {}
    if ts.exists():
        for m in ET.parse(ts).getroot().iter("message"):
            t = m.find("translation")
            if t is not None and t.text and t.get("type") != "unfinished":
                old[m.find("source").text] = t.text
    out = ['<?xml version="1.0" encoding="utf-8"?>', "<!DOCTYPE TS>", f'<TS version="2.1" language="{lang}" sourcelanguage="en_US">']
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
    print(f"{ts.name}: {sum(map(len, contexts.values()))} strings, {missing} untranslated", file=sys.stderr)
