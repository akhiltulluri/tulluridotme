---
title: Hello, world
date: 2026-11-08
synopsis: A first post, and a tour of what this site's Markdown can do.
tags: [meta]
---

This is the first post. It doubles as a reference for what you can write here.

## Code

Fenced blocks with a language are highlighted at build time by Pygments, which
knows OCaml, Haskell, Rocq, Lean 4, Agda, F\*, Isabelle, Rust, C, LLVM IR and
hundreds more. Hover a block to copy it:

```ocaml
type expr =
  | Int of int
  | Add of expr * expr
  | Mul of expr * expr

let rec eval = function
  | Int n -> n
  | Add (a, b) -> eval a + eval b
  | Mul (a, b) -> eval a * eval b
```

```rocq
Theorem plus_O_n : forall n : nat, 0 + n = n.
Proof. intros n. reflexivity. Qed.
```

## Math

Inline math like $\Gamma \vdash e : \tau$ and display math:

$$
\frac{\Gamma, x : \tau_1 \vdash e : \tau_2}
     {\Gamma \vdash \lambda x.\, e : \tau_1 \to \tau_2}
\;(\textsf{T-Abs})
$$

## Diagrams

A fenced block tagged `d2` is rendered to SVG at build time with
[D2](https://d2lang.com). No JavaScript needed:

```d2
direction: right
source -> parser -> "type checker" -> codegen
```

Add `sketch` after `d2` for a hand-drawn look:

```d2 sketch
direction: right
Γ: "Γ ⊢ e : τ"
Γ -> "e ⇓ v": soundness
```

For anything fancier, draw it in Excalidraw / tldraw / TikZ, export an SVG to
`static/assets/`, and reference it:

```markdown
![Pipeline](/assets/pipeline.svg)
```

## Everything else

Tables, footnotes[^1], ~~strikethrough~~ and task lists work too.

| Phase  | Input  | Output |
|--------|--------|--------|
| Parse  | text   | AST    |
| Check  | AST    | typed AST |

[^1]: Like this one.
