"""Subset Noto Serif CJK TC Bold to the characters used in the game's scripts.

Usage:  python tools/subset_title_font.py <path/to/NotoSerifCJKtc-Bold.otf>
Source: https://github.com/notofonts/noto-cjk (Serif/OTF/TraditionalChinese)
Re-run whenever UI text in *.gd changes so new characters get included.
"""
import pathlib
import sys

from fontTools import subset

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "fonts" / "NotoSerifTC-Bold-subset.otf"

chars = set(chr(c) for c in range(0x20, 0x7F))  # printable ASCII
chars |= set("，。、！？：；「」『』（）《》…·‹›—～")
for gd in ROOT.glob("*.gd"):
    for ch in gd.read_text(encoding="utf-8"):
        if ord(ch) > 0x7F:
            chars.add(ch)

opts = subset.Options()
opts.layout_features = ["*"]
opts.name_IDs = ["*"]
opts.notdef_outline = True
font = subset.load_font(sys.argv[1], opts)
sub = subset.Subsetter(opts)
sub.populate(text="".join(sorted(chars)))
sub.subset(font)
subset.save_font(font, str(OUT), opts)
print(f"{len(chars)} chars -> {OUT.name} ({OUT.stat().st_size // 1024} KB)")
