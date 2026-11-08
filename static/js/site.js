// Progressive enhancement only; every page works without JS.
// Highlighting and diagrams are rendered at build time (bin/render.ml).

(function () {
  // --- Light/dark toggle -----------------------------------------------------
  // Default follows the OS. Clicking flips the current look and remembers it.
  const root = document.documentElement;
  const toggle = document.querySelector(".mode-toggle");
  const systemDark = window.matchMedia("(prefers-color-scheme: dark)");
  const isDark = () =>
    root.dataset.theme ? root.dataset.theme === "dark" : systemDark.matches;
  // Icons are swapped by CSS; only the accessible label needs updating.
  const label = () =>
    toggle.setAttribute(
      "aria-label",
      isDark() ? "Switch to light mode" : "Switch to dark mode"
    );
  if (toggle) {
    toggle.hidden = false;
    label();
    toggle.addEventListener("click", () => {
      const next = isDark() ? "light" : "dark";
      root.dataset.theme = next;
      try {
        localStorage.setItem("mode", next);
      } catch (e) {}
      label();
    });
    systemDark.addEventListener("change", label);
  }

  // --- Copy buttons on code blocks ------------------------------------------
  if (navigator.clipboard) {
    document.querySelectorAll("main pre > code").forEach((code) => {
      const pre = code.parentElement;
      const wrap = document.createElement("div");
      wrap.className = "code-block";
      pre.replaceWith(wrap);
      wrap.appendChild(pre);

      const btn = document.createElement("button");
      btn.className = "copy";
      btn.type = "button";
      btn.textContent = "copy";
      btn.addEventListener("click", () => {
        navigator.clipboard.writeText(code.innerText).then(
          () => {
            btn.textContent = "copied";
            setTimeout(() => (btn.textContent = "copy"), 1500);
          },
          () => (btn.textContent = "failed")
        );
      });
      wrap.appendChild(btn);
    });
  }

  // --- Math: $inline$ / $$display$$ (cmarkit emits \( \) and \[ \]) ---------
  // Only fetched on pages that contain math. auto-render skips <pre>/<code>.
  const KATEX = "https://cdn.jsdelivr.net/npm/katex@0.16.9/dist";
  const main = document.querySelector("main");
  const text = main ? main.textContent : "";
  if (text.includes("\\(") || text.includes("\\[")) {
    const css = document.createElement("link");
    css.rel = "stylesheet";
    css.href = KATEX + "/katex.min.css";
    document.head.appendChild(css);
    const load = (src) =>
      new Promise((ok, err) => {
        const s = document.createElement("script");
        s.src = src;
        s.onload = ok;
        s.onerror = err;
        document.head.appendChild(s);
      });
    load(KATEX + "/katex.min.js")
      .then(() => load(KATEX + "/contrib/auto-render.min.js"))
      .then(() =>
        renderMathInElement(main, {
          delimiters: [
            { left: "\\[", right: "\\]", display: true },
            { left: "\\(", right: "\\)", display: false },
          ],
          throwOnError: false,
        })
      );
  }
})();
