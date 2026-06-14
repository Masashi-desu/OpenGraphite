const fallbackLocale = "ja";

function previewField(name) {
  const context = window.__OPENGRAPHITE_PREVIEW_CONTEXT__ || {};
  const fields = context.fields || {};
  if (!Object.prototype.hasOwnProperty.call(fields, name)) {
    return { found: false, value: "" };
  }
  return { found: true, value: String(fields[name]) };
}

function selectedLanguage() {
  const mock = previewField("selectedLanguage");
  if (mock.found) { return mock.value; }
  return document.documentElement.lang || fallbackLocale;
}

const i18n = window.i18n || {
  init(config) {
    window.__OPENGRAPHITE_I18N_CONFIG__ = config;
    return config;
  }
};

const runtimeConfig = i18n.init({
  lng: selectedLanguage(),
  fallbackLng: "ja",
  backend: {
    loadPath: "/locales/{{lng}}.json"
  }
});

function resolvedLoadPath(language) {
  return runtimeConfig.backend.loadPath.replace("{{lng}}", language);
}

function resolvedLocaleURL(language) {
  const path = resolvedLoadPath(language);
  if (document.location.protocol === "file:" && path.startsWith("/")) {
    return new URL(`.${path}`, document.baseURI);
  }
  return new URL(path, document.baseURI);
}

async function loadLocale(language) {
  const url = resolvedLocaleURL(language);
  try {
    const response = await fetch(url.href);
    if (response.ok) { return await response.json(); }
  } catch (_) {}
  return await new Promise((resolve) => {
    const request = new XMLHttpRequest();
    request.open("GET", url.href, true);
    request.onload = () => {
      if ((request.status >= 200 && request.status < 300) || request.status === 0) {
        try { resolve(JSON.parse(request.responseText)); } catch (_) { resolve({}); }
      } else {
        resolve({});
      }
    };
    request.onerror = () => resolve({});
    request.send();
  });
}

function elementsIncludingTemplateContent(root) {
  const elements = [];
  function visit(node) {
    if (!node) { return; }
    if (node.nodeType === Node.ELEMENT_NODE) {
      elements.push(node);
      if (node.tagName && node.tagName.toLowerCase() === "template") {
        Array.from(node.content.childNodes).forEach(visit);
      }
    }
    Array.from(node.childNodes || []).forEach(visit);
  }
  visit(root);
  return elements;
}

function textVariantAttributeForLocale(locale) {
  const normalizedLocale = String(locale || "").trim().toLowerCase().replace(/_/g, "-");
  if (!/^[a-z0-9-]+$/.test(normalizedLocale)) {
    return "";
  }
  if (normalizedLocale.split("-")[0] === "en") {
    return "data-og-text-variant-eng";
  }
  return `data-og-text-variant-${normalizedLocale}`;
}

function localeFontVariableNames(locale) {
  const normalizedLocale = String(locale || "")
    .trim()
    .toLowerCase()
    .replace(/_/g, "-")
    .replace(/[^a-z0-9-]/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-|-$/g, "");
  if (!normalizedLocale) { return []; }
  const primaryLocale = normalizedLocale.split("-")[0];
  const names = [`--og-font-family-${normalizedLocale}`];
  if (primaryLocale && primaryLocale !== normalizedLocale) {
    names.push(`--og-font-family-${primaryLocale}`);
  }
  if (normalizedLocale === "eng") {
    names.push("--og-font-family-en");
  } else if (primaryLocale === "en") {
    names.push("--og-font-family-eng");
  }
  return Array.from(new Set(names));
}

function applyLocaleFont(locale) {
  const variableNames = localeFontVariableNames(locale);
  const pageRoots = document.querySelectorAll('[data-og-type="page"], [data-og-role="page-preview"]');
  pageRoots.forEach((pageRoot) => {
    const computedStyle = window.getComputedStyle(pageRoot);
    let fontFamily = "";
    for (const variableName of variableNames) {
      fontFamily = computedStyle.getPropertyValue(variableName).trim();
      if (fontFamily) { break; }
    }
    if (fontFamily) {
      pageRoot.style.setProperty("--og-active-font-family", fontFamily);
    } else {
      pageRoot.style.removeProperty("--og-active-font-family");
    }
  });
}

async function applyI18n() {
  const language = selectedLanguage();
  const resources = await loadLocale(language);
  const variantAttribute = textVariantAttributeForLocale(language);
  document.documentElement.lang = language || fallbackLocale;
  applyLocaleFont(language || fallbackLocale);
  elementsIncludingTemplateContent(document.documentElement).forEach((element) => {
    const key = element.getAttribute("data-i18n-key");
    if (!key) { return; }
    if (!element.hasAttribute("data-og-runtime-fallback-html")) {
      element.setAttribute("data-og-runtime-fallback-html", element.innerHTML);
    }
    const fallbackHTML = element.getAttribute("data-og-runtime-fallback-html") || "";
    const variantHTML = variantAttribute ? element.getAttribute(variantAttribute) : null;
    const value = Object.prototype.hasOwnProperty.call(resources, key) ? resources[key] : variantHTML !== null ? variantHTML : fallbackHTML;
    element.innerHTML = typeof value === "string" ? value : fallbackHTML;
  });
}

window.OpenGraphiteI18n = { apply: applyI18n };

document.addEventListener("DOMContentLoaded", () => { applyI18n(); });
document.addEventListener("opengraphite:components-ready", () => { applyI18n(); });
document.addEventListener("opengraphite:serialize-complete", () => { applyI18n(); });
