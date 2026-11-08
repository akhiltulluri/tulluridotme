// Batch KaTeX renderer used by the site generator (bin/render.ml).
//
// stdin:  display \0 tex \0 display \0 tex ...   (display is "1" or "0")
// stdout: html \0 html ...                        (same order)
//
// Bad TeX renders as a red error message instead of failing the build.

import { readFileSync } from "node:fs";
import katex from "katex";

const parts = readFileSync(0, "utf8").split("\0");
const out = [];
for (let i = 0; i + 1 < parts.length; i += 2) {
  out.push(
    katex.renderToString(parts[i + 1], {
      displayMode: parts[i] === "1",
      throwOnError: false,
    })
  );
}
process.stdout.write(out.join("\0"));
