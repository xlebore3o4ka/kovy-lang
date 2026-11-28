/* Kovy docs viewer — theme, mobile navigation, search and page utilities. */
(() => {
  "use strict";

  const root = document.documentElement.dataset.root || "";
  const body = document.body;

  /* ----------------------------------------------------------------------
     Theme
     ---------------------------------------------------------------------- */

  const themeButton = document.querySelector(".theme-toggle");
  const themeStorageKey = "kovy-theme";

  themeButton?.addEventListener("click", () => {
    const current = document.documentElement.dataset.theme === "light" ? "light" : "dark";
    const next = current === "dark" ? "light" : "dark";
    document.documentElement.dataset.theme = next;
    try {
      localStorage.setItem(themeStorageKey, next);
    } catch {
      /* storage can be unavailable when opened from file:// */
    }
  });

  /* ----------------------------------------------------------------------
     Mobile sidebar
     ---------------------------------------------------------------------- */

  const menuToggle = document.querySelector(".menu-toggle");
  const sidebarBackdrop = document.querySelector("[data-close-sidebar]");

  function setSidebar(open) {
    body.classList.toggle("sidebar-open", open);
    menuToggle?.setAttribute("aria-expanded", String(open));
  }

  menuToggle?.addEventListener("click", () => {
    setSidebar(!body.classList.contains("sidebar-open"));
  });

  sidebarBackdrop?.addEventListener("click", () => setSidebar(false));

  window.addEventListener("resize", () => {
    if (window.innerWidth > 960) setSidebar(false);
  });

  /* ----------------------------------------------------------------------
     Copy code
     ---------------------------------------------------------------------- */

  async function copyText(text) {
    try {
      if (navigator.clipboard?.writeText) {
        await navigator.clipboard.writeText(text);
        return true;
      }
    } catch {
      /* fall through to the old API */
    }

    const textarea = document.createElement("textarea");
    textarea.value = text;
    textarea.setAttribute("readonly", "");
    textarea.style.position = "fixed";
    textarea.style.opacity = "0";
    document.body.appendChild(textarea);
    textarea.select();
    let ok = false;
    try {
      ok = document.execCommand("copy");
    } catch {
      ok = false;
    }
    textarea.remove();
    return ok;
  }

  document.addEventListener("click", async (event) => {
    const button = event.target.closest(".code-copy");
    if (!button) return;
    const code = button.closest(".codeblock")?.querySelector("code");
    if (!code) return;

    const original = button.textContent;
    const ok = await copyText(code.textContent);
    button.textContent = ok ? "Copied" : "Failed";
    button.classList.toggle("is-copied", ok);
    window.setTimeout(() => {
      button.textContent = original;
      button.classList.remove("is-copied");
    }, 1500);
  });

  /* ----------------------------------------------------------------------
     Toast + heading links
     ---------------------------------------------------------------------- */

  let toastTimer = 0;

  function showToast(message) {
    let toast = document.getElementById("kovy-toast");
    if (!toast) {
      toast = document.createElement("div");
      toast.id = "kovy-toast";
      toast.className = "toast";
      toast.setAttribute("role", "status");
      toast.setAttribute("aria-live", "polite");
      document.body.append(toast);
    }
    toast.textContent = message;
    toast.classList.add("is-visible");
    window.clearTimeout(toastTimer);
    toastTimer = window.setTimeout(() => toast.classList.remove("is-visible"), 1800);
  }

  const docBody = document.querySelector(".doc-body");

  if (docBody) {
    docBody.querySelectorAll("h2[id], h3[id], h4[id]").forEach((heading) => {
      const label = heading.textContent.trim();
      const anchor = document.createElement("a");
      anchor.className = "heading-anchor";
      anchor.href = `#${heading.id}`;
      anchor.setAttribute("aria-label", `Copy link to “${label}”`);
      anchor.innerHTML =
        '<svg viewBox="0 0 20 20" aria-hidden="true"><path d="M8.5 11.5a3.5 3.5 0 0 0 5 0l3-3a3.5 3.5 0 0 0-5-5l-1.2 1.2"/><path d="M11.5 8.5a3.5 3.5 0 0 0-5 0l-3 3a3.5 3.5 0 0 0 5 5l1.2-1.2"/></svg>';
      anchor.addEventListener("click", async (event) => {
        event.preventDefault();
        const url = `${location.origin}${location.pathname}${location.search}#${heading.id}`;
        const ok = await copyText(url);
        history.replaceState(null, "", `#${heading.id}`);
        if (ok) showToast("Link copied");
        else {
          location.hash = heading.id;
          showToast("Link is in the address bar");
        }
      });
      heading.append(anchor);
    });
  }

  /* ----------------------------------------------------------------------
     Back to top
     ---------------------------------------------------------------------- */

  const backToTop = document.createElement("button");
  backToTop.className = "back-to-top";
  backToTop.type = "button";
  backToTop.setAttribute("aria-label", "Back to top");
  backToTop.innerHTML =
    '<svg viewBox="0 0 20 20" aria-hidden="true"><path d="M10 16V5"/><path d="m5 9.5 5-5 5 5"/></svg>';
  backToTop.addEventListener("click", () => {
    window.scrollTo({ top: 0, behavior: "smooth" });
  });
  document.body.append(backToTop);

  let backToTopVisible = false;
  const updateBackToTop = () => {
    const visible = window.scrollY > 700;
    if (visible !== backToTopVisible) {
      backToTopVisible = visible;
      backToTop.classList.toggle("is-visible", visible);
    }
  };
  window.addEventListener("scroll", updateBackToTop, { passive: true });
  updateBackToTop();

  /* ----------------------------------------------------------------------
     Search
     ---------------------------------------------------------------------- */

  const searchIndex = Array.isArray(window.KOVY_SEARCH_INDEX) ? window.KOVY_SEARCH_INDEX : [];
  const overlay = document.getElementById("searchOverlay");
  const searchPanel = overlay?.querySelector(".search-panel");
  const searchInput = document.getElementById("searchInput");
  const resultsElement = document.getElementById("searchResults");
  const openButtons = document.querySelectorAll("[data-open-search]");
  const closeButtons = document.querySelectorAll("[data-close-search]");

  const quickLinks = [
    {
      t: "Hello world",
      s: "The shortest complete program",
      u: "guides/hello-world.html",
      g: "Guides",
      x: "",
    },
    {
      t: "Language overview",
      s: "Types, program shape, execution model",
      u: "language/overview.html",
      g: "Language",
      x: "",
    },
    {
      t: "Canonical grammar",
      s: "Every production in the language",
      u: "language/grammar.html",
      g: "Language",
      x: "",
    },
    {
      t: "Keyword reference",
      s: "All 19 reserved words",
      u: "reference/keywords.html",
      g: "Reference",
      x: "",
    },
    {
      t: "Error catalogue",
      s: "Every diagnostic emitted by the compiler",
      u: "errors/index.html",
      g: "Errors",
      x: "",
    },
    {
      t: "Pointers and allocation",
      s: "alloc, dereference, address-of, arithmetic",
      u: "language/pointers.html",
      g: "Language",
      x: "",
    },
    {
      t: "RPN interpreter walkthrough",
      s: "A larger complete program",
      u: "guides/rpn.html",
      g: "Guides",
      x: "",
    },
  ];

  let selectedIndex = 0;
  let currentResults = [];
  let lastTrigger = null;
  let activeSearchGroup = "all";
  const searchFilters = [...document.querySelectorAll("[data-search-group]")];

  function escapeHtml(value) {
    return String(value)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#39;");
  }

  function escapeRegExp(value) {
    return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  }

  function highlight(value, tokens) {
    let output = escapeHtml(value);
    if (!tokens.length) return output;
    const pattern = tokens
      .filter(Boolean)
      .sort((a, b) => b.length - a.length)
      .map((token) => escapeRegExp(escapeHtml(token)))
      .join("|");
    if (!pattern) return output;
    output = output.replace(new RegExp(`(${pattern})`, "gi"), "<mark>$1</mark>");
    return output;
  }

  function tokenize(query) {
    return query
      .toLowerCase()
      .split(/\s+/)
      .map((token) => token.trim())
      .filter(Boolean);
  }

  function scoreEntry(entry, tokens, query) {
    const title = entry.t.toLowerCase();
    const section = (entry.s || "").toLowerCase();
    const body = (entry.x || "").toLowerCase();
    let score = 0;
    let matched = 0;

    for (const token of tokens) {
      let tokenScore = 0;
      if (title.includes(token)) tokenScore += title.startsWith(token) ? 18 : 12;
      if (section.includes(token)) tokenScore += 7;
      const position = body.indexOf(token);
      if (position >= 0) tokenScore += position < 80 ? 5 : 3;
      if (tokenScore > 0) {
        matched += 1;
        score += tokenScore;
      }
    }

    if (!matched) return { score: -1, matched: 0 };
    const phrase = query.toLowerCase();
    if (title.includes(phrase)) score += 18;
    if (section.includes(phrase)) score += 8;
    return { score, matched };
  }

  function makeSnippet(entry, tokens) {
    const text = (entry.x || "").replace(/\s+/g, " ").trim();
    if (!text) return "";
    const lower = text.toLowerCase();
    let position = -1;
    for (const token of tokens) {
      const found = lower.indexOf(token);
      if (found >= 0 && (position < 0 || found < position)) position = found;
    }
    if (position < 0) position = 0;

    let start = Math.max(0, position - 70);
    let end = Math.min(text.length, start + 210);
    if (start > 0) {
      const space = text.indexOf(" ", start);
      if (space >= 0 && space < position) start = space + 1;
    }
    if (end < text.length) {
      const space = text.lastIndexOf(" ", end);
      if (space > position) end = space;
    }

    return `${start > 0 ? "…" : ""}${text.slice(start, end).trim()}${end < text.length ? "…" : ""}`;
  }

  function search(query) {
    const tokens = tokenize(query);
    if (!tokens.length) return [];
    return searchIndex
      .filter((entry) => activeSearchGroup === "all" || entry.g === activeSearchGroup)
      .map((entry) => ({ entry, ...scoreEntry(entry, tokens, query) }))
      .filter((result) => result.matched > 0)
      .sort((a, b) => b.matched - a.matched || b.score - a.score)
      .slice(0, 14)
      .map(({ entry }) => entry);
  }

  function setSearchGroup(group) {
    activeSearchGroup = group;
    searchFilters.forEach((button) => {
      const active = button.dataset.searchGroup === group;
      button.classList.toggle("is-active", active);
      button.setAttribute("aria-pressed", String(active));
    });
    if (searchInput) renderResults(searchInput.value);
  }

  function setSelected(nextIndex, scroll = false) {
    if (!currentResults.length) return;
    selectedIndex = (nextIndex + currentResults.length) % currentResults.length;
    const items = [...resultsElement.querySelectorAll(".search-result")];
    items.forEach((item, index) => {
      const selected = index === selectedIndex;
      item.classList.toggle("is-selected", selected);
      item.setAttribute("aria-selected", String(selected));
    });
    if (scroll) {
      items[selectedIndex]?.scrollIntoView({ block: "nearest" });
    }
  }

  function renderResults(query) {
    const clean = query.trim();
    const tokens = tokenize(clean);
    const isQuickLinks = clean.length === 0;
    const pool = isQuickLinks
      ? quickLinks.filter(
          (entry) => activeSearchGroup === "all" || entry.g === activeSearchGroup
        )
      : search(clean);
    currentResults = pool;
    selectedIndex = 0;

    const groupLabel =
      activeSearchGroup === "all" ? "the full reference" : activeSearchGroup;
    const intro = isQuickLinks
      ? activeSearchGroup === "all"
        ? '<div class="search-empty"><strong>Quick links</strong>Start typing to search the full reference.</div>'
        : `<div class="search-empty"><strong>${escapeHtml(groupLabel)}</strong>Start typing to search this section.</div>`
      : "";

    if (!currentResults.length) {
      resultsElement.innerHTML =
        intro +
        `<div class="search-empty"><strong>No matches</strong>Nothing found for “${escapeHtml(clean)}” in ${escapeHtml(groupLabel)}.</div>`;
      return;
    }

    resultsElement.innerHTML =
      intro +
      currentResults
        .map((entry, index) => {
          const section = entry.s ? `<div class="search-result-section">${highlight(entry.s, tokens)}</div>` : "";
          const snippet = isQuickLinks ? "" : makeSnippet(entry, tokens);
          const snippetHtml = snippet
            ? `<div class="search-result-snippet">${highlight(snippet, tokens)}</div>`
            : "";
          return (
            `<a class="search-result${index === 0 ? " is-selected" : ""}" role="option" aria-selected="${index === 0}" ` +
            `data-result-index="${index}" href="${root}${entry.u}">` +
            `<div class="search-result-top">` +
            `<span class="search-result-title">${highlight(entry.t, tokens)}</span>` +
            `<span class="search-result-group">${escapeHtml(entry.g || "")}</span>` +
            `</div>${section}${snippetHtml}</a>`
          );
        })
        .join("");
  }

  function openSearch(trigger, initialQuery = "") {
    if (!overlay) return;
    lastTrigger = trigger || null;
    overlay.hidden = false;
    body.classList.add("search-open");
    searchInput.value = initialQuery;
    renderResults(initialQuery);
    window.setTimeout(() => searchInput?.focus(), 20);
  }

  function closeSearch() {
    if (!overlay) return;
    overlay.hidden = true;
    body.classList.remove("search-open");
    if (lastTrigger instanceof HTMLElement) lastTrigger.focus();
  }

  openButtons.forEach((button) => {
    button.addEventListener("click", () => openSearch(button));
  });

  closeButtons.forEach((button) => {
    button.addEventListener("click", closeSearch);
  });

  searchInput?.addEventListener("input", () => {
    renderResults(searchInput.value);
  });

  searchFilters.forEach((button) => {
    button.addEventListener("click", () => {
      setSearchGroup(button.dataset.searchGroup || "all");
      searchInput?.focus();
    });
  });

  resultsElement?.addEventListener("click", (event) => {
    if (event.target.closest(".search-result")) closeSearch();
  });

  document.addEventListener("keydown", (event) => {
    const isSearchOpen = overlay && !overlay.hidden;

    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
      event.preventDefault();
      if (isSearchOpen) {
        closeSearch();
      } else {
        openSearch(document.activeElement);
      }
      return;
    }

    if (
      event.key === "/" &&
      !isSearchOpen &&
      !event.metaKey &&
      !event.ctrlKey &&
      !event.altKey &&
      !["INPUT", "TEXTAREA", "SELECT"].includes(document.activeElement?.tagName || "")
    ) {
      event.preventDefault();
      openSearch(document.activeElement);
      return;
    }

    if (event.key === "Escape") {
      if (isSearchOpen) {
        closeSearch();
      } else if (body.classList.contains("sidebar-open")) {
        setSidebar(false);
      }
      return;
    }

    if (isSearchOpen && event.key === "Tab" && searchPanel) {
      const focusables = [
        ...searchPanel.querySelectorAll(
          'a[href], button:not([disabled]), input, [tabindex]:not([tabindex="-1"])'
        ),
      ].filter((element) => element.offsetParent !== null);
      if (focusables.length) {
        const first = focusables[0];
        const last = focusables[focusables.length - 1];
        if (event.shiftKey && document.activeElement === first) {
          event.preventDefault();
          last.focus();
        } else if (!event.shiftKey && document.activeElement === last) {
          event.preventDefault();
          first.focus();
        }
      }
      return;
    }

    if (!isSearchOpen || document.activeElement !== searchInput) return;

    if (event.key === "ArrowDown") {
      event.preventDefault();
      setSelected(selectedIndex + 1, true);
    } else if (event.key === "ArrowUp") {
      event.preventDefault();
      setSelected(selectedIndex - 1, true);
    } else if (event.key === "Enter") {
      event.preventDefault();
      const selected = currentResults[selectedIndex];
      if (selected) {
        closeSearch();
        window.location.href = root + selected.u;
      }
    }
  });

  /* ----------------------------------------------------------------------
     Sidebar state: open groups and scroll position survive navigation
     ---------------------------------------------------------------------- */

  const sidebar = document.querySelector(".sidebar");
  const activeNavLink = sidebar?.querySelector(".nav-link.is-active");
  const navGroups = sidebar ? [...sidebar.querySelectorAll("details.nav-group")] : [];
  const navStateKey = "kovy-nav-state";
  const activeGroup = activeNavLink?.closest("details.nav-group") || null;

  let savedNavState = null;
  try {
    savedNavState = JSON.parse(localStorage.getItem(navStateKey) || "null");
  } catch {
    savedNavState = null;
  }

  if (sidebar) {
    // A page inside a group always reveals that group, even if it was closed.
    navGroups.forEach((group) => {
      const key = group.dataset.group;
      const savedOpen = savedNavState?.open?.[key];
      if (group === activeGroup) group.open = true;
      else if (typeof savedOpen === "boolean") group.open = savedOpen;
    });

    const saveNavState = () => {
      const open = {};
      navGroups.forEach((group) => {
        if (group.dataset.group) open[group.dataset.group] = group.open;
      });
      try {
        localStorage.setItem(
          navStateKey,
          JSON.stringify({
            open,
            scrollTop: Math.round(sidebar.scrollTop),
          })
        );
      } catch {
        /* storage can be unavailable when opened from file:// */
      }
    };

    let saveTimer = 0;
    const scheduleSave = () => {
      window.clearTimeout(saveTimer);
      saveTimer = window.setTimeout(saveNavState, 120);
    };

    // Restore the previous position. Only adjust it when the current page is
    // completely outside the visible part of the tree.
    const restoreScroll = () => {
      if (typeof savedNavState?.scrollTop === "number") {
        sidebar.scrollTop = savedNavState.scrollTop;
      }
      if (!activeNavLink) return;

      const sidebarRect = sidebar.getBoundingClientRect();
      const linkRect = activeNavLink.getBoundingClientRect();
      if (linkRect.top < sidebarRect.top + 36 || linkRect.bottom > sidebarRect.bottom - 36) {
        sidebar.scrollTop = Math.max(
          0,
          sidebar.scrollTop +
            (linkRect.top - sidebarRect.top) -
            sidebarRect.height / 2 +
            linkRect.height / 2
        );
      }
    };

    restoreScroll();
    window.requestAnimationFrame(restoreScroll);

    navGroups.forEach((group) => {
      group.addEventListener("toggle", scheduleSave);
    });
    sidebar.addEventListener("scroll", scheduleSave, { passive: true });
    sidebar.addEventListener("click", (event) => {
      if (event.target.closest("a")) saveNavState();
    });
    window.addEventListener("pagehide", saveNavState);
  }

  /* ----------------------------------------------------------------------
     Deep-linked search: /?q=diagnostic
     ---------------------------------------------------------------------- */

  const initialQuery = new URLSearchParams(window.location.search).get("q");
  if (initialQuery) openSearch(null, initialQuery);

  /* ----------------------------------------------------------------------
     TOC scroll spy
     ---------------------------------------------------------------------- */

  document.querySelectorAll(".toc-mobile").forEach((details) => {
    details.addEventListener("click", (event) => {
      if (event.target.closest("a")) details.open = false;
    });
  });

  const tocLinks = [...document.querySelectorAll(".toc-link")];
  if (tocLinks.length) {
    // The same heading can be linked from the desktop TOC and the mobile
    // "On this page" block, so group links by target instead of treating
    // every link as a separate target.
    const targetById = new Map();
    tocLinks.forEach((link) => {
      const href = link.getAttribute("href") || "";
      const id = href.startsWith("#") ? href.slice(1) : "";
      const element = id ? document.getElementById(id) : null;
      if (!element) return;
      let target = targetById.get(id);
      if (!target) {
        target = { element, links: [] };
        targetById.set(id, target);
      }
      target.links.push(link);
    });
    const targets = [...targetById.values()];

    let ticking = false;

    const updateToc = () => {
      ticking = false;
      if (!targets.length) return;
      const anchor = window.scrollY + 132;
      let active = targets[0];
      for (const target of targets) {
        if (target.element.offsetTop <= anchor) active = target;
        else break;
      }
      if (window.innerHeight + window.scrollY >= document.documentElement.scrollHeight - 8) {
        active = targets[targets.length - 1];
      }
      targets.forEach((target) => {
        const selected = target === active;
        target.links.forEach((link) => {
          link.classList.toggle("is-active", selected);
          if (selected) link.setAttribute("aria-current", "location");
          else link.removeAttribute("aria-current");
        });
      });
    };

    window.addEventListener(
      "scroll",
      () => {
        if (!ticking) {
          ticking = true;
          window.requestAnimationFrame(updateToc);
        }
      },
      { passive: true }
    );
    updateToc();
  }
})();