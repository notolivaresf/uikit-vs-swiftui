"""Turns runs/screens-v2/row-ids.json into `kind:id:words;kind:id:words` for ScreensV2.testRows
(TEST_RUNNER_UVS_ROWS). `words` are the first words the test looks for to read the row's frame.

Accepts {"rows": {...}} or {"kind": id}, {"kind": {"id": id, "words": ...}}, or [{"kind": k, "id": id}, ...].
"""
import json, re, sys

# First words per id from the reference lane (18 Oct), used when the file gives none.
WORDS = {
    49962: "Quick summary", 49963: "can you look at the flaky test", 49964: "Deploying now.",
    49966: "It was the cache key.", 49968: "Thanks, I will review it", 49969: "the demo is moved",
    49970: "Nice!", 49971: "This is the query I used.", 49972: "budget.xlsx", 49973: "🎉🎉",
    49974: "Shipped! Thank you everybody", 49979: "Review thanks plan.",
}

data = json.load(open(sys.argv[1]))
if isinstance(data, dict) and isinstance(data.get("rows"), (dict, list)):
    data = data["rows"]
pairs = []
if isinstance(data, dict):
    for k, v in data.items():
        words = None
        if isinstance(v, dict):
            words = v.get("words")
            v = v.get("id", v.get("message_id"))
        if isinstance(v, int) or (isinstance(v, str) and v.isdigit()):
            pairs.append((k, int(v), words))
else:
    for item in data:
        pairs.append((item.get("kind") or item.get("name"), int(item.get("id", item.get("message_id"))), item.get("words")))
out = []
for k, v, words in pairs:
    k = re.sub(r"[^a-z0-9-]+", "-", str(k).lower()).strip("-")
    words = (words or WORDS.get(v, "")).replace(";", " ").replace(":", " ")
    out.append(f"{k}:{v}:{words}")
print(";".join(out))
