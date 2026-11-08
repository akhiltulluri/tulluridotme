"""Batch syntax highlighter used by the site generator (bin/render.ml).

stdin:  lang \0 code \0 lang \0 code ...
stdout: html \0 html ...      (one fragment per input block, same order)

Unknown languages fall back to HTML-escaped plain text.
"""

import sys
from html import escape

from pygments import highlight
from pygments.formatters import HtmlFormatter
from pygments.lexers import get_lexer_by_name
from pygments.util import ClassNotFound

ALIASES = {"rocq": "coq", "lean": "lean4", "sh": "bash", "shell": "bash"}

formatter = HtmlFormatter(nowrap=True)

parts = sys.stdin.buffer.read().decode("utf-8").split("\0")
out = []
for lang, code in zip(parts[0::2], parts[1::2]):
    try:
        lexer = get_lexer_by_name(
            ALIASES.get(lang, lang), stripnl=False, ensurenl=False
        )
    except ClassNotFound:
        out.append(escape(code, quote=False))
        continue
    out.append(highlight(code, lexer, formatter))

sys.stdout.buffer.write("\0".join(out).encode("utf-8"))
