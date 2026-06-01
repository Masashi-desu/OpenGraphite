(() => {
const componentReadyEvent = "opengraphite:components-ready";

function attributeValue(element, name) {
  return element.getAttribute(name) || "";
}

function componentLinks() {
  return Array.from(document.querySelectorAll('link[rel="opengraphite-components"][href]'));
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

  return new DOMParser().parseFromString(html, "text/html");
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

function masterNodes(documentRoot) {
  return Array.from(documentRoot.querySelectorAll('[data-og-component][data-og-component-kind="master"]'));
}

function componentIDForInstance(instance) {
  return attributeValue(instance, "data-og-component");
}

function instanceID(instance, componentID) {
  return attributeValue(instance, "data-og-id") || `${componentID}-instance`;
}

function sourceTemplateFor(instance) {
  let template = Array.from(instance.children).find((child) => {
    return child.tagName && child.tagName.toLowerCase() === "template" &&
      child.getAttribute("data-og-instance-source") === "true";
  });

  if (!template) {
    template = document.createElement("template");
    template.setAttribute("data-og-instance-source", "true");
    while (instance.firstChild) {
      template.content.appendChild(instance.firstChild);
    }
    instance.appendChild(template);
  }

  return template;
}

function slottedSourceMap(template) {
  const map = new Map();
  template.content.childNodes.forEach((node) => {
    if (node.nodeType !== Node.ELEMENT_NODE) { return; }
    const slotName = node.getAttribute("slot") || "default";
    if (!map.has(slotName)) {
      map.set(slotName, []);
    }
    map.get(slotName).push(node);
  });
  return map;
}

function assignedHTML(map, slotName, fallbackHTML) {
  const assignedNodes = map.get(slotName) || [];
  if (assignedNodes.length === 0) {
    return fallbackHTML;
  }
  return assignedNodes.map((node) => node.innerHTML || node.textContent || "").join("");
}

function applySlots(root, sourceMap) {
  root.querySelectorAll("[data-og-slot]").forEach((slotTarget) => {
    const slotName = attributeValue(slotTarget, "data-og-slot") || "default";
    slotTarget.innerHTML = assignedHTML(sourceMap, slotName, slotTarget.innerHTML);
    slotTarget.setAttribute("data-og-slot-origin", slotName);
  });
}

function rewriteGeneratedIDs(root, idPrefix, componentID) {
  const editableNodes = [];
  if (root.hasAttribute("data-og-id")) {
    editableNodes.push(root);
  }
  editableNodes.push(...root.querySelectorAll("[data-og-id]"));

  editableNodes.forEach((element, index) => {
    const originalID = attributeValue(element, "data-og-id") || `node-${index + 1}`;
    const part = attributeValue(element, "data-og-part");
    const nextID = part === "root" || index === 0 ? idPrefix : `${idPrefix}-${originalID}`;
    element.setAttribute("data-og-id", nextID);
    element.setAttribute("data-og-source-component", componentID);
    element.setAttribute("data-og-source-instance", idPrefix);
    element.setAttribute("data-og-generated", "true");
  });
}

function cloneMaster(master, instance, componentID, id) {
  const root = master.cloneNode(true);
  root.setAttribute("data-og-generated", "true");
  root.removeAttribute("data-og-component-kind");
  if (instance.getAttribute("style")) {
    root.style.cssText = `${root.style.cssText};${instance.getAttribute("style")}`;
  }
  applySlots(root, slottedSourceMap(sourceTemplateFor(instance)));
  rewriteGeneratedIDs(root, id, componentID);
  return root;
}

function removeGeneratedContent(instance) {
  Array.from(instance.children).forEach((child) => {
    if (child.getAttribute("data-og-generated") === "true") {
      child.remove();
    }
  });
}

function copyGeneratedSlotsBack(instance) {
  const sourceTemplate = Array.from(instance.children).find((child) => {
    return child.tagName && child.tagName.toLowerCase() === "template" &&
      child.getAttribute("data-og-instance-source") === "true";
  });
  if (!sourceTemplate) { return; }

  const sourceMap = slottedSourceMap(sourceTemplate);
  instance.querySelectorAll('[data-og-generated="true"] [data-og-slot-origin]').forEach((generatedSlot) => {
    const slotName = attributeValue(generatedSlot, "data-og-slot-origin") || "default";
    const sourceNode = (sourceMap.get(slotName) || [])[0];
    if (!sourceNode) { return; }
    sourceNode.innerHTML = generatedSlot.innerHTML;
  });

  const generatedRoot = Array.from(instance.children).find((child) => {
    return child.getAttribute("data-og-generated") === "true";
  });
  if (generatedRoot && generatedRoot.getAttribute("style")) {
    instance.setAttribute("style", generatedRoot.getAttribute("style"));
  }
}

function restoreInstanceSource(instance) {
  copyGeneratedSlotsBack(instance);
  const sourceTemplate = Array.from(instance.children).find((child) => {
    return child.tagName && child.tagName.toLowerCase() === "template" &&
      child.getAttribute("data-og-instance-source") === "true";
  });
  if (!sourceTemplate) { return; }

  removeGeneratedContent(instance);
  const restoredNodes = Array.from(sourceTemplate.content.cloneNode(true).childNodes);
  sourceTemplate.remove();
  restoredNodes.forEach((node) => {
    instance.appendChild(node);
  });

  const hostID = attributeValue(instance, "data-og-host-id");
  if (hostID) {
    instance.setAttribute("data-og-id", hostID);
  }
  instance.removeAttribute("data-og-host-id");
  instance.removeAttribute("data-og-expanded");
}

function stripRuntimeAttributes(root) {
  const runtimeAttributeNames = [
    "data-og-selected",
    "data-og-editing",
    "data-og-expanded",
    "data-og-generated",
    "data-og-component-error",
    "data-og-host-id",
    "data-og-instance-source",
    "data-og-source-component",
    "data-og-source-instance",
    "data-og-slot-origin",
    "contenteditable",
    "spellcheck"
  ];
  const elements = [root, ...root.querySelectorAll("*")];
  elements.forEach((element) => {
    runtimeAttributeNames.forEach((name) => element.removeAttribute(name));
    element.style.removeProperty("--og-edit-width");
    element.style.removeProperty("--og-edit-min-height");
  });
}

function serializeDocument() {
  document.querySelectorAll("og-instance[data-og-expanded]").forEach(copyGeneratedSlotsBack);
  const clone = document.documentElement.cloneNode(true);
  clone.querySelectorAll("og-instance[data-og-expanded]").forEach(restoreInstanceSource);
  stripRuntimeAttributes(clone);
  return `<!doctype html>\n${clone.outerHTML}`;
}

async function componentRegistry() {
  const registry = new Map();
  const documents = await Promise.all(componentLinks().map((link) => loadComponentDocument(link.href)));
  documents.forEach((componentDocument) => {
    masterNodes(componentDocument).forEach((master) => {
      registry.set(attributeValue(master, "data-og-component"), master);
    });
  });
  return registry;
}

function registryFromHTMLDocuments(htmlDocuments) {
  const registry = new Map();
  htmlDocuments.forEach((html) => {
    const componentDocument = new DOMParser().parseFromString(html, "text/html");
    masterNodes(componentDocument).forEach((master) => {
      registry.set(attributeValue(master, "data-og-component"), master);
    });
  });
  return registry;
}

function renderInstances(registry) {
  document.querySelectorAll("og-instance[data-og-component]").forEach((instance) => {
    const componentID = componentIDForInstance(instance);
    const master = registry.get(componentID);
    if (!master) {
      instance.setAttribute("data-og-component-error", "missing-master");
      return;
    }

    const hostID = attributeValue(instance, "data-og-id") ||
      attributeValue(instance, "data-og-host-id") ||
      instanceID(instance, componentID);
    if (hostID) {
      instance.setAttribute("data-og-host-id", hostID);
      instance.removeAttribute("data-og-id");
    }

    removeGeneratedContent(instance);
    instance.appendChild(cloneMaster(master, instance, componentID, hostID));
    instance.setAttribute("data-og-expanded", "true");
  });
}

function installRuntimeStyles() {
  if (document.getElementById("opengraphite-runtime-style")) { return; }
  const style = document.createElement("style");
  style.id = "opengraphite-runtime-style";
  style.textContent = [
    'og-instance[data-og-expanded="true"]{display:contents!important}',
    'og-instance[data-og-expanded="true"]>template{display:none!important}'
  ].join("");
  document.head.appendChild(style);
}

async function render() {
  installRuntimeStyles();
  const registry = await componentRegistry();
  renderInstances(registry);
  document.dispatchEvent(new CustomEvent(componentReadyEvent));
}

function renderComponentHTMLDocuments(htmlDocuments) {
  installRuntimeStyles();
  renderInstances(registryFromHTMLDocuments(htmlDocuments));
  document.dispatchEvent(new CustomEvent(componentReadyEvent));
}

window.OpenGraphiteRuntime = {
  render,
  renderComponentHTMLDocuments,
  serializeDocument
};

render().catch((error) => {
  document.dispatchEvent(new CustomEvent("opengraphite:components-error", { detail: String(error) }));
  console.error(error);
});
})();
