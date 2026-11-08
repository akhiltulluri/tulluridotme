# tulluri.me

Personal site, generated with [YOCaml](https://github.com/xhtmlboi/yocaml).

Build-time tools: Python with [Pygments](https://pygments.org) (code
highlighting), Node with [KaTeX](https://katex.org) (math; `npm ci`) and
[D2](https://d2lang.com) (diagrams). If one is missing the build still
succeeds, with a warning and a plain-text fallback.

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
- `$inline$`, `$$display$$` and ` ```math ` are typeset at build time by KaTeX (`tools/katex.mjs`)
- tables, footnotes, strikethrough, task lists, and raw HTML/SVG
- other images go in `static/assets/` and are linked as `/assets/…`

The only JS is `static/js/site.js` (~2 KB): the light/dark toggle and copy buttons.
Without JS the page follows the system theme and code can still be selected.
Drafts live in `content/drafts/`, which is never built (e.g. the favorites page). Move a file into `content/pages/` or `content/writing/` to publish it.

## Deploying

Pushing to `main` runs `.github/workflows/deploy.yml`, which installs OCaml,
Pygments, KaTeX and D2, builds the site and publishes `_site/` to GitHub Pages.
`static/CNAME` sets the custom domain (`tulluri.me`).
