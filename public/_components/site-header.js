(() => {
  const initializedHosts = new WeakSet();

  function navigationLabels(open) {
    const language = (document.documentElement.lang || "ja").toLowerCase();
    if (language.startsWith("ja")) {
      return open
        ? { label: "ナビゲーションメニューを閉じる", title: "メニューを閉じる" }
        : { label: "ナビゲーションメニューを開く", title: "メニューを開く" };
    }
    return open
      ? { label: "Close navigation menu", title: "Close menu" }
      : { label: "Open navigation menu", title: "Open menu" };
  }

  function generatedSiteHeaderHosts() {
    const hosts = new Set(document.querySelectorAll('site-header[data-og-component="site-header"]'));
    const runtime = window.OpenGraphiteRuntime;
    if (runtime && typeof runtime.generatedRootFor === "function") {
      document.querySelectorAll('og-instance[data-og-component="site-header"]').forEach((instance) => {
        const host = runtime.generatedRootFor(instance);
        if (host) { hosts.add(host); }
      });
    }
    return Array.from(hosts);
  }

  function initializeSiteHeader(host) {
    if (!host || initializedHosts.has(host) || !host.shadowRoot) { return; }

    const shell = host.shadowRoot.querySelector(".site-header-shell");
    const brand = host.shadowRoot.querySelector(".site-header-brand");
    const navigation = host.shadowRoot.querySelector(".site-header-nav");
    const toggle = host.shadowRoot.querySelector(".site-header-menu-toggle");
    if (!shell || !brand || !navigation || !toggle) { return; }

    initializedHosts.add(host);
    let measurementFrame = 0;

    function setMenuOpen(open) {
      const wasOpen = host.classList.contains("site-header-menu-open");
      const nextOpen = !!open && host.classList.contains("site-header-compact");
      host.classList.toggle("site-header-menu-open", nextOpen);
      toggle.setAttribute("aria-expanded", String(nextOpen));
      const labels = navigationLabels(nextOpen);
      toggle.setAttribute("aria-label", labels.label);
      toggle.setAttribute("title", labels.title);
      if (wasOpen && !nextOpen) { scheduleMeasurement(); }
    }

    function measureNavigation() {
      measurementFrame = 0;
      host.classList.add("site-header-measuring");

      const shellStyle = getComputedStyle(shell);
      const availableWidth = shell.clientWidth
        - (parseFloat(shellStyle.paddingLeft) || 0)
        - (parseFloat(shellStyle.paddingRight) || 0);
      const gap = parseFloat(shellStyle.columnGap || shellStyle.gap) || 0;
      const requiredWidth = brand.getBoundingClientRect().width
        + navigation.getBoundingClientRect().width
        + gap;
      const compact = host.classList.contains("site-header-menu-open")
        || Math.ceil(requiredWidth) > Math.floor(availableWidth);

      host.classList.toggle("site-header-compact", compact);
      host.classList.remove("site-header-measuring");
      if (!compact) { setMenuOpen(false); }
    }

    function scheduleMeasurement() {
      if (measurementFrame) { cancelAnimationFrame(measurementFrame); }
      measurementFrame = requestAnimationFrame(measureNavigation);
    }

    toggle.addEventListener("click", () => {
      setMenuOpen(!host.classList.contains("site-header-menu-open"));
    });

    host.addEventListener("keydown", (event) => {
      if (event.key !== "Escape" || !host.classList.contains("site-header-menu-open")) { return; }
      setMenuOpen(false);
      toggle.focus();
    });

    navigation.addEventListener("click", (event) => {
      if (event.composedPath().some((node) => node instanceof HTMLAnchorElement)) {
        setMenuOpen(false);
      }
    });

    document.addEventListener("pointerdown", (event) => {
      if (!host.classList.contains("site-header-menu-open") || event.composedPath().includes(host)) { return; }
      setMenuOpen(false);
    });

    new ResizeObserver(scheduleMeasurement).observe(shell);
    new MutationObserver(scheduleMeasurement).observe(host, {
      childList: true,
      characterData: true,
      subtree: true
    });
    new MutationObserver(() => setMenuOpen(host.classList.contains("site-header-menu-open"))).observe(
      document.documentElement,
      { attributes: true, attributeFilter: ["lang"] }
    );

    if (document.fonts && document.fonts.ready) {
      document.fonts.ready.then(scheduleMeasurement);
    }
    setMenuOpen(false);
    scheduleMeasurement();
  }

  function initializeAllSiteHeaders() {
    generatedSiteHeaderHosts().forEach(initializeSiteHeader);
  }

  document.addEventListener("DOMContentLoaded", initializeAllSiteHeaders);
  document.addEventListener("opengraphite:components-ready", initializeAllSiteHeaders);
})();
