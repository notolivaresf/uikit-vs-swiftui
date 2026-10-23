#!/usr/bin/env python3
"""Render the two Round 4 share images from the numbers in docs/round4-results.md.

HTML + headless Google Chrome, 1600 px wide at 2x (3200 px PNG). No outside services.
Run from anywhere: python3 docs/share/render_round4_share.py
"""
import html
import pathlib
import subprocess
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# metric, better ("low"/"high"), unit label, six values in doc order
# order: AppKit Swift Opus, AppKit Swift Sol, AppKit ObjC Opus, AppKit ObjC Sol, SwiftUI Opus, SwiftUI Sol
# a value is (text, number or None, flag) where flag is "" or "*" (check failed) or "-" (not measured)
ND = ("–", None, "-")


def v(text, num=None, star=False):
    return (text, num if num is not None else float(text.replace(",", "")), "*" if star else "")


ROWS = [
    ("Cold launch, median of 3 (ms)", "low",
     [v("699"), v("753"), v("688"), ("803", 803.0, ""), v("763"), v("919")],
     {3: "one sample 5,132"}),
    ("First 40 rows, cold (ms)", "low", [v("270"), v("279"), v("209"), v("312"), v("345"), v("520")], {}),
    ("First 40 rows, repeated (ms)", "low", [v("244"), v("265"), v("202"), v("263"), v("407"), v("493")], {}),
    ("Jump to message 2,500 (ms)", "low", [v("32"), v("33"), v("15"), v("22"), v("66"), v("407", star=True)], {}),
    ("Load older (ms)", "low", [v("23"), v("13"), v("9"), v("8"), v("8"), v("170", star=True)], {}),
    ("Text size at the bottom (ms)", "low", [v("25"), v("16"), v("9"), v("10"), v("24"), v("112")], {}),
    ("Text size mid-list (ms)", "low", [v("25"), v("26"), v("10"), v("22"), v("67"), v("152")], {}),
    ("Peak memory (MB)", "low", [v("107.5"), v("132.9"), v("102.9"), v("122.1"), v("216.9"), ND], {}),
    ("Stream CPU (s)", "low", [v("7.2"), v("8.9"), v("6.1"), v("8.7"), v("9.2"), ND], {}),
    ("App size (MB)", "low", [v("1.26"), v("0.99"), v("1.16"), v("1.01"), v("1.68"), v("3.08")], {}),
    ("Fling fps (Instruments)", "high", [v("91.0"), v("82.9"), v("97.9"), v("87.8"), v("57.3"), v("68.4")], {}),
    ("Fling hitch time (ms)", "low", [v("1,758"), v("1,150"), v("1,108"), v("1,800"), v("3,142"), v("1,733")], {}),
    ("Stream hitch time (ms)", "low", [v("242"), v("492"), v("308"), v("3,533"), v("3,800"), v("9,983")], {}),
    ("Resize hitch time (ms)", "low", [v("8"), v("8"), v("8"), v("8"), v("8"), ND], {}),
    ("Checks passed (of 13)", "high", [v("9"), v("9"), v("9"), v("9"), v("9"), v("5")], {}),
]
WALL = ["14 min 16 s", "13 min 49 s", "13 min 41 s", "20 min 45 s", "17 min 18 s", "17 min 1 s"]
# doc order of wall-time table is different; mapped to column order above:
# AppKit Swift Opus 14:16, Swift Sol 13:49, ObjC Opus 13:41, ObjC Sol 20:45, SwiftUI Opus 17:18, SwiftUI Sol 17:01

CSS = """
*{box-sizing:border-box;margin:0;padding:0}
html,body{width:1600px;background:#fff;color:#16181d;font-family:-apple-system,"SF Pro Display","Helvetica Neue",Helvetica,Arial,sans-serif}
.wrap{padding:64px 72px 56px}
h1{font-size:60px;font-weight:700;letter-spacing:-1px}
.sub{font-size:28px;color:#4a5160;margin-top:14px;line-height:1.35}
table{width:100%;border-collapse:collapse;margin-top:40px}
th{font-size:26px;font-weight:600;text-align:right;padding:14px 16px;border-bottom:3px solid #16181d;vertical-align:bottom;line-height:1.2}
th:first-child,td:first-child{text-align:left}
th small{display:block;font-size:20px;font-weight:500;color:#6b7280;margin-top:4px}
td{font-size:30px;text-align:right;padding:15px 16px;border-bottom:1px solid #e4e7ec;font-variant-numeric:tabular-nums;white-space:nowrap}
td:first-child{font-size:28px;color:#16181d;white-space:normal}
td.best{background:#e3f4ea;color:#0b5a2b;font-weight:700}
td.nm{color:#8a919e}
td small{display:block;font-size:19px;color:#6b7280;font-weight:400;white-space:normal;line-height:1.15}
td.best small{color:#3d7a57}
tr.grp td{border-bottom:none}
.foot{font-size:23px;color:#5b6270;margin-top:28px;line-height:1.4}
"""


def fmt_cell(val, note, best):
    text, _, flag = val
    cls = "best" if best else ("nm" if flag == "-" else "")
    out = html.escape(text) + ("*" if flag == "*" else "")
    if note:
        out += "<small>%s</small>" % html.escape(note)
    return '<td class="%s">%s</td>' % (cls, out)


def page(title, sub, head, body, foot):
    return ("<!doctype html><meta charset=utf-8><style>%s</style><div class=wrap><h1>%s</h1><div class=sub>%s</div>"
            "<table><thead><tr>%s</tr></thead><tbody>%s</tbody></table><div class=foot>%s</div></div>"
            % (CSS, title, sub, head, body, foot))


def image1():
    head = "<th>Metric</th><th>AppKit<small>range over 4 builds</small></th><th>SwiftUI<small>by Opus</small></th><th>SwiftUI<small>by Sol</small></th>"
    body = ""
    for name, better, vals, notes in ROWS:
        ak = vals[:4]
        nums = [x[1] for x in ak]
        lo, hi = min(nums), max(nums)
        ak_text = "{0}–{1}".format(*[next(x[0] for x in ak if x[1] == n) for n in (lo, hi)]) if lo != hi else ak[0][0]
        ak_star = any(x[2] == "*" for x in ak)
        so, ss = vals[4], vals[5]
        # best side: compare AppKit's better end with SwiftUI numbers
        ak_best = lo if better == "low" else hi
        cands = {"ak": ak_best}
        if so[1] is not None:
            cands["so"] = so[1]
        if ss[1] is not None:
            cands["ss"] = ss[1]
        vals_sorted = sorted(cands.values(), reverse=(better == "high"))
        winner = None
        if len(vals_sorted) > 1 and vals_sorted[0] != vals_sorted[1]:
            winner = [k for k, x in cands.items() if x == vals_sorted[0]][0]
        ak_note = notes.get(3)
        # show footnote for the ObjC Sol launch sample inside the AppKit cell
        ak_cell = fmt_cell((ak_text, 0, "*" if ak_star else ""), "ObjC Sol: one sample 5,132" if ak_note else "", winner == "ak")
        body += "<tr><td>%s</td>%s%s%s</tr>" % (html.escape(name), ak_cell,
                                                 fmt_cell(so, "", winner == "so"), fmt_cell(ss, "", winner == "ss"))
    sub = ("Round 4: the same Mac chat app built six times, from one spec. Opus and Sol are the AI models that wrote each build. "
           "Xcode 27.1, MacBook Pro M1 Max.")
    foot = ("One fast pass per build; differences under about 10-15% are noise. * check failed. – not measured. "
            "Green = better side. AppKit range covers Swift and Objective-C, each written by Opus and by Sol. "
            "SwiftUI Sol's stream hitch comes from a failed run and is not trustworthy.")
    return page("AppKit vs SwiftUI", sub, head, body, foot)


def image2():
    cols = [("AppKit", "Swift · Opus"), ("AppKit", "Swift · Sol"), ("AppKit", "Objective-C · Opus"),
            ("AppKit", "Objective-C · Sol"), ("SwiftUI", "Opus"), ("SwiftUI", "Sol")]
    head = "<th>Metric</th>" + "".join("<th>%s<small>%s</small></th>" % (a, b) for a, b in cols)
    body = ""
    for name, better, vals, notes in ROWS:
        nums = [(i, x[1]) for i, x in enumerate(vals) if x[1] is not None]
        bestv = (min if better == "low" else max)(n for _, n in nums)
        winners = {i for i, n in nums if n == bestv}
        if len(winners) > 2:
            winners = set()
        body += "<tr><td>%s</td>%s</tr>" % (html.escape(name), "".join(
            fmt_cell(x, notes.get(i, ""), i in winners) for i, x in enumerate(vals)))
    body += "<tr><td>Wall time per pass</td>%s</tr>" % "".join('<td style="font-size:24px">%s</td>' % w for w in WALL)
    sub = ("Round 4: all six builds of the same Mac chat app. Opus and Sol are the AI models that wrote each build. "
           "Xcode 27.1, MacBook Pro M1 Max.")
    foot = "One fast pass per build; differences under about 10-15% are noise. * check failed. – not measured. Green = best in the row."
    return page("All six runs", sub, head, body, foot)


def render(doc, out, height):
    with tempfile.NamedTemporaryFile("w", suffix=".html", delete=False) as f:
        f.write(doc)
        path = f.name
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=2",
                    "--window-size=1600,%d" % height, "--screenshot=%s" % out, "file://" + path], check=True,
                   capture_output=True)


if __name__ == "__main__":
    import sys
    h1 = int(sys.argv[1]) if len(sys.argv) > 1 else 1500
    h2 = int(sys.argv[2]) if len(sys.argv) > 2 else 1500
    render(image1(), str(HERE / "round4-appkit-vs-swiftui.png"), h1)
    render(image2(), str(HERE / "round4-all-runs.png"), h2)
