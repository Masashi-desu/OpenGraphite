(() => {
const componentReadyEvent = "opengraphite:components-ready";
const instanceStates = new WeakMap();
const masterStates = new WeakMap();
const generatedElements = new WeakSet();
const generatedMetadata = new WeakMap();
const slotMetadata = new WeakMap();
let runtimeStyleElement = null;
let activeRegistry = new Map();
const previewBooleanAttributes = new Set([
  "autofocus",
  "autoplay",
  "checked",
  "controls",
  "disabled",
  "hidden",
  "inert",
  "loop",
  "multiple",
  "muted",
  "open",
  "readonly",
  "required",
  "selected"
]);
const previewProtectedAttributes = new Set([
  "id",
  "part",
  "slot",
  "style"
]);

function attributeValue(element, name) {
  return element && element.getAttribute ? element.getAttribute(name) || "" : "";
}

function previewAttributeName(fieldName) {
  const prefix = "host.";
  if (typeof fieldName !== "string" || !fieldName.startsWith(prefix)) { return ""; }
  const name = fieldName.slice(prefix.length).trim().toLowerCase();
  if (!/^[a-z_:][a-z0-9_.:-]*$/.test(name)) { return ""; }
  if (name === "class") { return name; }
  if (name.startsWith("on") || name.startsWith("data-og-") || previewProtectedAttributes.has(name)) { return ""; }
  return name;
}

function previewBooleanPresence(value) {
  return !new Set(["0", "false", "no", "off"]).has(String(value).trim().toLowerCase());
}

/**
 * Applies placement-only preview state to a generated host through standard DOM state.
 * Fields use `host.<attribute>` keys; `host.class` adds class tokens and standard
 * boolean attributes use presence semantics. OpenGraphite identity/provenance
 * attributes, inline style, event handlers, slot, and part are never injectable.
 */
function applyPreviewState(host, fields) {
  if (!host || host.nodeType !== Node.ELEMENT_NODE || !fields || typeof fields !== "object") {
    return Object.freeze({ attributes: [], classes: [] });
  }

  const appliedAttributes = [];
  const appliedClasses = [];
  Object.keys(fields).sort().forEach((fieldName) => {
    const attributeName = previewAttributeName(fieldName);
    if (!attributeName) { return; }
    const value = String(fields[fieldName]);
    if (attributeName === "class") {
      value.split(/\s+/).filter(Boolean).forEach((token) => {
        try {
          host.classList.add(token);
          appliedClasses.push(token);
        } catch (_) {
          // Invalid project-defined class tokens are ignored without mutating source.
        }
      });
      return;
    }
    if (previewBooleanAttributes.has(attributeName)) {
      if (previewBooleanPresence(value)) {
        host.setAttribute(attributeName, "");
      } else {
        host.removeAttribute(attributeName);
      }
    } else {
      host.setAttribute(attributeName, value);
    }
    appliedAttributes.push(attributeName);
  });

  const result = Object.freeze({
    attributes: Object.freeze(appliedAttributes),
    classes: Object.freeze(appliedClasses)
  });
  host.dispatchEvent(new CustomEvent("opengraphite:preview-state", {
    bubbles: true,
    composed: true,
    detail: Object.freeze({ fields: Object.freeze({ ...fields }), result })
  }));
  return result;
}

function componentIDForInstance(instance) {
  return attributeValue(instance, "data-og-component");
}

function instanceID(instance, componentID) {
  return attributeValue(instance, "data-og-id") || `${componentID}-instance`;
}

function stateForInstance(instance) {
  let state = instanceStates.get(instance);
  if (state) { return state; }
  state = {
    componentError: "",
    componentID: componentIDForInstance(instance),
    expanded: false,
    generatedRoot: null,
    hostID: "",
    hostIDWasAuthored: false,
    registry: null,
    sourceNodes: []
  };
  instanceStates.set(instance, state);
  return state;
}

function componentLinks() {
  return Array.from(document.querySelectorAll('link[rel~="opengraphite-components"][href]'));
}

async function loadComponentDocument(href) {
  const url = new URL(href, document.baseURI);
  let html = null;

  try {
    const response = await fetch(url.href);
    if (response.ok) {
      html = await response.text();
    }
  } catch (_) {
    html = null;
  }

  if (html === null) {
    html = await loadTextWithXHR(url.href);
  }

  return {
    baseURL: url.href,
    document: new DOMParser().parseFromString(html, "text/html")
  };
}

function loadTextWithXHR(url) {
  return new Promise((resolve, reject) => {
    const request = new XMLHttpRequest();
    request.open("GET", url, true);
    request.onload = () => {
      if ((request.status >= 200 && request.status < 300) || request.status === 0) {
        resolve(request.responseText);
      } else {
        reject(new Error(`Unable to load OpenGraphite components: ${url}`));
      }
    };
    request.onerror = () => reject(new Error(`Unable to load OpenGraphite components: ${url}`));
    request.send();
  });
}

function directTemplate(master) {
  return Array.from(master.children || []).find((child) => {
    return (child.tagName || "").toLowerCase() === "template";
  }) || null;
}

function isComponentMaster(element) {
  if (!element || (element.tagName || "").toLowerCase() === "og-instance") { return false; }
  const componentID = attributeValue(element, "data-og-component");
  const tagName = (element.tagName || "").toLowerCase();
  return !!componentID && tagName.includes("-") && !!directTemplate(element);
}

function masterNodes(documentRoot) {
  return Array.from(documentRoot.querySelectorAll("[data-og-component]")).filter(isComponentMaster);
}

function elementTree(root, options) {
  const includeRoot = !!(options && options.includeRoot);
  const includeShadowRoots = !!(options && options.includeShadowRoots);
  const includeTemplateContents = !!(options && options.includeTemplateContents);
  const elements = [];
  const visitedRoots = new Set();

  function visit(node, isRoot) {
    if (!node || visitedRoots.has(node)) { return; }
    if (node.nodeType === Node.DOCUMENT_NODE || node.nodeType === Node.DOCUMENT_FRAGMENT_NODE) {
      visitedRoots.add(node);
      Array.from(node.childNodes || []).forEach((child) => visit(child, false));
      return;
    }
    if (node.nodeType !== Node.ELEMENT_NODE) { return; }
    if (!isRoot || includeRoot) { elements.push(node); }
    if (includeShadowRoots && node.shadowRoot) {
      visit(node.shadowRoot, false);
    }
    if (includeTemplateContents && (node.tagName || "").toLowerCase() === "template" && node.content) {
      visit(node.content, false);
    }
    Array.from(node.childNodes || []).forEach((child) => visit(child, false));
  }

  visit(root, true);
  return elements;
}

function descriptorForMaster(master, baseURL) {
  const template = directTemplate(master);
  if (!template) { return null; }
  const content = template.content.cloneNode(true);
  Array.from(content.querySelectorAll("[href],[src]")).forEach((element) => {
    ["href", "src"].forEach((attributeName) => {
      const authoredValue = element.getAttribute(attributeName);
      if (!authoredValue || authoredValue.startsWith("#") || authoredValue.startsWith("data:")) { return; }
      try {
        element.setAttribute(attributeName, new URL(authoredValue, baseURL).href);
      } catch (_) {
        // An invalid authored URL remains authored and simply fails to load in the browser.
      }
    });
  });
  return Object.freeze({
    componentID: attributeValue(master, "data-og-component"),
    content,
    master,
    template
  });
}

function addDocumentMasters(registry, componentDocument, baseURL) {
  masterNodes(componentDocument).forEach((master) => {
    const descriptor = descriptorForMaster(master, baseURL);
    if (descriptor) { registry.set(descriptor.componentID, descriptor); }
  });
}

function registryFromDocument(componentDocument, baseURL) {
  const registry = new Map();
  addDocumentMasters(registry, componentDocument, baseURL);
  return registry;
}

async function componentRegistry() {
  const registry = registryFromDocument(document, document.baseURI);
  const documents = await Promise.all(componentLinks().map((link) => loadComponentDocument(link.href)));
  documents.forEach((loaded) => addDocumentMasters(registry, loaded.document, loaded.baseURL));
  return registry;
}

function registryFromHTMLDocuments(htmlDocuments) {
  const registry = registryFromDocument(document, document.baseURI);
  htmlDocuments.forEach((source) => {
    const html = typeof source === "string" ? source : source?.html;
    if (typeof html !== "string") { return; }
    const baseURL = typeof source?.baseURL === "string" && source.baseURL
      ? source.baseURL
      : document.baseURI;
    const componentDocument = new DOMParser().parseFromString(html, "text/html");
    addDocumentMasters(registry, componentDocument, baseURL);
  });
  return registry;
}

function copyInstanceHostAttributes(instance, root) {
  Array.from(instance.attributes || []).forEach((attribute) => {
    if (["data-og-id", "data-og-internal-id", "data-og-component", "slot", "style"].includes(attribute.name)) {
      return;
    }
    root.setAttribute(attribute.name, attribute.value);
  });
  const instanceStyle = instance.getAttribute("style");
  if (instanceStyle) {
    root.style.cssText = `${root.style.cssText};${instanceStyle}`;
  }
}

function registerGeneratedTree(root, shadowRoot, instance, idPrefix, componentID) {
  const generatedTree = [root, ...elementTree(shadowRoot, { includeRoot: false, includeShadowRoots: true })];
  generatedTree.forEach((element) => {
    generatedElements.add(element);
    generatedMetadata.set(element, {
      instance,
      sourceComponent: componentID,
      sourceID: "",
      sourceInstance: idPrefix
    });
  });

  const editableNodes = generatedTree.filter((element) => element.hasAttribute("data-og-id"));
  editableNodes.forEach((element, index) => {
    const originalID = attributeValue(element, "data-og-id") || `node-${index + 1}`;
    const nextID = index === 0 ? idPrefix : `${idPrefix}-${originalID}`;
    element.setAttribute("data-og-id", nextID);
    generatedMetadata.get(element).sourceID = originalID;
  });
}

function cloneMaster(descriptor, instance, state, componentID, id, stack) {
  const root = descriptor.master.cloneNode(false);
  copyInstanceHostAttributes(instance, root);
  const shadowRoot = root.attachShadow({ mode: "open" });
  shadowRoot.appendChild(descriptor.content.cloneNode(true));
  registerGeneratedTree(root, shadowRoot, instance, id, componentID);

  state.sourceNodes.forEach((node) => {
    root.appendChild(node);
    if (node.nodeType === Node.ELEMENT_NODE) {
      slotMetadata.set(node, {
        slotName: node.getAttribute("slot") || "default",
        sourceNode: node
      });
    }
  });

  renderInstancesInRoot(shadowRoot, state.registry, stack.concat(componentID));
  return root;
}

function composedParentElement(element) {
  if (!element) { return null; }
  if (element.parentElement) { return element.parentElement; }
  const root = typeof element.getRootNode === "function" ? element.getRootNode() : null;
  return root && root.host ? root.host : null;
}

function nestedExpandedInstances(root) {
  return elementTree(root, { includeRoot: false, includeShadowRoots: true })
    .filter((element) => instanceStates.get(element)?.expanded === true);
}

function suspendInstance(instance) {
  const state = instanceStates.get(instance);
  if (!state || !state.expanded || !state.generatedRoot) { return false; }

  nestedExpandedInstances(state.generatedRoot).reverse().forEach(suspendInstance);
  state.sourceNodes.forEach((node) => instance.appendChild(node));
  state.generatedRoot.remove();
  state.generatedRoot = null;
  if (state.hostIDWasAuthored) {
    instance.setAttribute("data-og-id", state.hostID);
  } else {
    instance.removeAttribute("data-og-id");
  }
  state.expanded = false;
  return true;
}

function resumeInstance(instance) {
  const state = instanceStates.get(instance);
  if (!state || state.expanded || !state.registry) { return false; }
  renderInstance(instance, state.registry, []);
  return state.expanded;
}

function renderInstance(instance, registry, stack) {
  const componentID = componentIDForInstance(instance);
  const state = stateForInstance(instance);
  state.componentID = componentID;
  state.registry = registry;

  if (state.expanded) { suspendInstance(instance); }
  if (stack.includes(componentID)) {
    state.componentError = "component-cycle";
    return;
  }

  const descriptor = registry.get(componentID);
  if (!descriptor) {
    state.componentError = "missing-master";
    return;
  }
  state.componentError = "";

  if (state.sourceNodes.length === 0) {
    state.sourceNodes = Array.from(instance.childNodes);
    state.hostIDWasAuthored = instance.hasAttribute("data-og-id");
    state.hostID = attributeValue(instance, "data-og-id") || instanceID(instance, componentID);
  }
  if (state.hostIDWasAuthored) { instance.removeAttribute("data-og-id"); }

  state.generatedRoot = cloneMaster(
    descriptor,
    instance,
    state,
    componentID,
    state.hostID,
    stack
  );
  instance.appendChild(state.generatedRoot);
  state.expanded = true;
}

function renderInstancesInRoot(root, registry, stack) {
  elementTree(root, { includeRoot: true, includeShadowRoots: true })
    .filter((element) => (element.tagName || "").toLowerCase() === "og-instance" && componentIDForInstance(element))
    .forEach((instance) => renderInstance(instance, registry, stack));
}

function activateMaster(master, registry) {
  const componentID = attributeValue(master, "data-og-component");
  const descriptor = registry.get(componentID) || descriptorForMaster(master, document.baseURI);
  if (!descriptor) { return; }

  let shadowRoot = master.shadowRoot;
  if (!shadowRoot) {
    try {
      shadowRoot = master.attachShadow({ mode: "open" });
    } catch (_) {
      return;
    }
  }
  shadowRoot.replaceChildren(descriptor.content.cloneNode(true));
  masterStates.set(master, { componentID, shadowRoot });

  const hostID = attributeValue(master, "data-og-id") || `${componentID}-master`;
  elementTree(shadowRoot, { includeRoot: false, includeShadowRoots: true }).forEach((element) => {
    generatedElements.add(element);
    generatedMetadata.set(element, {
      instance: master,
      sourceComponent: componentID,
      sourceID: attributeValue(element, "data-og-id"),
      sourceInstance: hostID
    });
  });
  renderInstancesInRoot(shadowRoot, registry, [componentID]);
}

function activateLocalMasters(registry) {
  masterNodes(document).forEach((master) => activateMaster(master, registry));
}

function installRuntimeStyles() {
  if (runtimeStyleElement && runtimeStyleElement.isConnected) { return; }
  runtimeStyleElement = document.createElement("style");
  runtimeStyleElement.textContent = "og-instance{display:contents!important}";
  document.head.appendChild(runtimeStyleElement);
}

function suspendRuntimeStyle() {
  if (!runtimeStyleElement || !runtimeStyleElement.parentNode) { return null; }
  const location = {
    nextSibling: runtimeStyleElement.nextSibling,
    parent: runtimeStyleElement.parentNode
  };
  runtimeStyleElement.remove();
  return location;
}

function resumeRuntimeStyle(location) {
  if (!location || !runtimeStyleElement) { return; }
  location.parent.insertBefore(runtimeStyleElement, location.nextSibling);
}

function suspendI18n() {
  const i18n = window.OpenGraphiteI18n;
  if (!i18n || typeof i18n.suspend !== "function") { return null; }
  return { i18n, snapshot: i18n.suspend() };
}

function resumeI18n(suspension) {
  if (!suspension || typeof suspension.i18n.resume !== "function") { return; }
  suspension.i18n.resume(suspension.snapshot);
}

function serializeDocument() {
  const i18nSuspension = suspendI18n();
  const suspendedInstances = [];
  let runtimeStyleLocation = null;
  let serialized = "";

  try {
    elementTree(document, { includeRoot: false, includeShadowRoots: true })
      .filter((element) => instanceStates.get(element)?.expanded === true)
      .forEach((instance) => {
        if (suspendInstance(instance)) { suspendedInstances.push(instance); }
      });
    runtimeStyleLocation = suspendRuntimeStyle();
    const clone = document.documentElement.cloneNode(true);
    serialized = `<!doctype html>\n${clone.outerHTML}`;
  } finally {
    resumeRuntimeStyle(runtimeStyleLocation);
    suspendedInstances.reverse().forEach(resumeInstance);
    resumeI18n(i18nSuspension);
  }

  document.dispatchEvent(new CustomEvent("opengraphite:serialize-complete"));
  return serialized;
}

function metadataFor(element) {
  if (!element) { return null; }
  const instanceState = instanceStates.get(element);
  if (instanceState) {
    return Object.freeze({
      componentError: instanceState.componentError,
      componentID: instanceState.componentID,
      expanded: instanceState.expanded,
      generated: false,
      hostID: instanceState.hostID,
      kind: "instance",
      slotOrigin: "",
      sourceComponent: "",
      sourceID: "",
      sourceInstance: ""
    });
  }

  const generated = generatedMetadata.get(element);
  if (generated) {
    const slot = slotMetadata.get(element);
    return Object.freeze({
      componentError: "",
      componentID: generated.sourceComponent,
      expanded: true,
      generated: true,
      hostID: generated.sourceInstance,
      kind: "generated",
      slotOrigin: slot ? slot.slotName : "",
      sourceComponent: generated.sourceComponent,
      sourceID: generated.sourceID,
      sourceInstance: generated.sourceInstance
    });
  }

  const slot = slotMetadata.get(element);
  if (!slot) { return null; }
  const host = composedParentElement(element);
  const hostMetadata = generatedMetadata.get(host);
  return Object.freeze({
    componentError: "",
    componentID: hostMetadata ? hostMetadata.sourceComponent : "",
    expanded: true,
    generated: false,
    hostID: hostMetadata ? hostMetadata.sourceInstance : "",
    kind: "slot-source",
    slotOrigin: slot.slotName,
    sourceComponent: hostMetadata ? hostMetadata.sourceComponent : "",
    sourceID: attributeValue(element, "data-og-id"),
    sourceInstance: hostMetadata ? hostMetadata.sourceInstance : ""
  });
}

function isGenerated(element) {
  return !!element && generatedElements.has(element);
}

function componentError(instance) {
  const state = instanceStates.get(instance);
  return state ? state.componentError : "";
}

function isExpanded(instance) {
  const state = instanceStates.get(instance);
  return !!state && state.expanded;
}

function generatedRootFor(instance) {
  const state = instanceStates.get(instance);
  return state ? state.generatedRoot : null;
}

function instanceFor(element) {
  const metadata = generatedMetadata.get(element);
  if (metadata) { return metadata.instance; }
  if (!slotMetadata.has(element)) { return null; }
  const host = composedParentElement(element);
  return generatedMetadata.get(host)?.instance || null;
}

function hostIDFor(instance) {
  const state = instanceStates.get(instance);
  return state ? state.hostID : "";
}

function sourceIDFor(element) {
  const metadata = generatedMetadata.get(element);
  if (metadata) { return metadata.sourceID; }
  return slotMetadata.has(element) ? attributeValue(element, "data-og-id") : "";
}

function elementsForInspection() {
  return elementTree(document.body, { includeRoot: true, includeShadowRoots: true });
}

async function render() {
  installRuntimeStyles();
  activeRegistry = await componentRegistry();
  activateLocalMasters(activeRegistry);
  renderInstancesInRoot(document.body || document, activeRegistry, []);
  document.dispatchEvent(new CustomEvent(componentReadyEvent));
}

function renderComponentHTMLDocuments(htmlDocuments) {
  installRuntimeStyles();
  activeRegistry = registryFromHTMLDocuments(htmlDocuments);
  activateLocalMasters(activeRegistry);
  renderInstancesInRoot(document.body || document, activeRegistry, []);
  document.dispatchEvent(new CustomEvent(componentReadyEvent));
}

window.OpenGraphiteRuntime = Object.freeze({
  applyPreviewState,
  componentError,
  elementsForInspection,
  generatedRootFor,
  hostIDFor,
  instanceFor,
  isExpanded,
  isGenerated,
  metadataFor,
  render,
  renderComponentHTMLDocuments,
  serializeDocument,
  sourceIDFor
});

render().catch((error) => {
  document.dispatchEvent(new CustomEvent("opengraphite:components-error", { detail: String(error) }));
  console.error(error);
});
})();
