# tulluri.me

Personal site, generated with [YOCaml](https://github.com/xhtmlboi/yocaml).

Build-time tools: Python with [Pygments](https://pygments.org) (code
highlighting) and [D2](https://d2lang.com) (diagrams). If one is missing the
build still succeeds, with a warning and plain code blocks.

```sh
opam switch create . 5.4.0 --deps-only   # first time only
make serve                                 # http://localhost:8000, rebuilds on change
make build                                 # writes the site to _site/
```

## Layout

| Path                     | Becomes                         |
|--------------------------|---------------------------------|
| `content/index.md`       | `/` (about + 5 most recent posts) |
| `content/writing.md`     | `/writing/` (all posts)          |
| `content/writing/*.md`   | `/writing/<file-name>/`          |
| `content/pages/*.md`     | `/<file-name>/` (contact, …)          |
| `static/**`              | copied to the root as-is         |
| `templates/*.html`       | Jingoo templates                 |
| `bin/site.ml`            | the generator                    |

## Writing a post

```markdown
---
title: My post
date: 2026-11-08
synopsis: One line, used in the feed.
tags: [ocaml, compilers]
display_toc: true        # optional
---
```

Markdown is CommonMark plus cmarkit's extensions:

- ` ```lang ` code blocks are highlighted at build time by Pygments (`tools/highlight.py`)
- ` ```d2 ` blocks become inline SVG at build time (` ```d2 sketch ` for a hand-drawn look)
- `$inline$` and `$$display$$` math is rendered with KaTeX (client-side, only on pages with math)
- tables, footnotes, strikethrough, task lists, and raw HTML/SVG
- other images go in `static/assets/` and are linked as `/assets/…`

The only JS is `static/js/site.js`: copy buttons on code blocks, plus KaTeX on pages with math.
Drafts live in `content/drafts/`, which is never built (e.g. the favorites page). Move a file into `content/pages/` or `content/writing/` to publish it.
