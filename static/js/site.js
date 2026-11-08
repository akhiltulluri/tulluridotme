// Progressive enhancement only; every page works without JS.
// Highlighting, diagrams and math are rendered at build time (bin/render.ml).
// All that's left here: the light/dark toggle and copy buttons.

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
})();
