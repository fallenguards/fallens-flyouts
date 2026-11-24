"""Writes what changed in each version, from CHANGELOG.md, into UI/Welcome.lua (W.CHANGES), for the window
an update's line in chat opens. Run from the repo root: python3 tools/changes.py
tools/tests/flyouts_test.lua holds the two the same."""
import re
import sys

LOG, OUT = "CHANGELOG.md", "UI/Welcome.lua"
BEGIN = "-- BEGIN generated: changes (tools/changes.py, from CHANGELOG.md)"
END = "-- END generated: changes"
WIDTH = 96


def parse(text):
    entries, entry, part = [], None, None
    for line in text.replace("\r\n", "\n").split("\n"):
        head = re.match(r"^## \[([^\]]+)\](?: - (\S+))?", line)
        if head:
            entry = {"version": head.group(1), "date": head.group(2) or "", "parts": []}
            entries.append(entry)
            part = None
            continue
        sub = re.match(r"^### (.+)$", line)
        if sub and entry is not None:
            part = {"name": sub.group(1).strip(), "items": []}
            entry["parts"].append(part)
            continue
        item = re.match(r"^- (.+)$", line)
        if item and part is not None:
            part["items"].append(item.group(1).replace("`", "").strip())
    return entries


def quote(s):
    assert all(ord(c) < 128 for c in s), "not plain text: " + s[:60]
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def chunks(s):
    out, line = [], ""
    for word in s.split(" "):
        if line and len(line) + 1 + len(word) > WIDTH:
            out.append(line + " ")
            line = word
        else:
            line = word if not line else line + " " + word
    out.append(line)
    return out


def lua(entries):
    lines = ["W.CHANGES = {"]
    for e in entries:
        lines.append("    { version = %s, date = %s, parts = {" % (quote(e["version"]), quote(e["date"])))
        for p in e["parts"]:
            lines.append("        { name = %s, items = {" % quote(p["name"]))
            for item in p["items"]:
                pieces = chunks(item)
                for i, piece in enumerate(pieces):
                    tail = "," if i == len(pieces) - 1 else " .."
                    lines.append("            " + ("" if i == 0 else "    ") + quote(piece) + tail)
            lines.append("        } },")
        lines.append("    } },")
    lines.append("}")
    return "\n".join(lines)


def main():
    root = sys.argv[1].rstrip("/") + "/" if len(sys.argv) > 1 else ""
    entries = parse(open(root + LOG, encoding="utf-8").read())
    raw = open(root + OUT, encoding="utf-8", newline="").read()
    nl = "\r\n" if "\r\n" in raw else "\n"
    text = raw.replace("\r\n", "\n")
    a, b = text.index(BEGIN) + len(BEGIN), text.index(END)
    text = text[:a] + "\n" + lua(entries) + "\n" + text[b:]
    open(root + OUT, "w", encoding="utf-8", newline="").write(text.replace("\n", nl))
    print("written: %d versions into %s" % (len(entries), OUT))


if __name__ == "__main__":
    main()
