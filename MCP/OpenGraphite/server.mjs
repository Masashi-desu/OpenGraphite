#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const serverDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(serverDir, "..", "..");
const ogkilnPath = join(repoRoot, "Scripts", "ogkiln");

let inputBuffer = Buffer.alloc(0);

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  process.stdin.on("data", (chunk) => {
    inputBuffer = Buffer.concat([inputBuffer, chunk]);
    readMessages();
  });
}

function readMessages() {
  while (true) {
    const headerEnd = inputBuffer.indexOf("\r\n\r\n");
    if (headerEnd === -1) {
      return;
    }

    const header = inputBuffer.slice(0, headerEnd).toString("utf8");
    const lengthMatch = header.match(/Content-Length:\s*(\d+)/i);
    if (!lengthMatch) {
      inputBuffer = inputBuffer.slice(headerEnd + 4);
      continue;
    }

    const contentLength = Number.parseInt(lengthMatch[1], 10);
    const bodyStart = headerEnd + 4;
    const bodyEnd = bodyStart + contentLength;
    if (inputBuffer.length < bodyEnd) {
      return;
    }

    const body = inputBuffer.slice(bodyStart, bodyEnd).toString("utf8");
    inputBuffer = inputBuffer.slice(bodyEnd);
    handleMessage(JSON.parse(body));
  }
}

function send(message) {
  const body = JSON.stringify(message);
  process.stdout.write(`Content-Length: ${Buffer.byteLength(body, "utf8")}\r\n\r\n${body}`);
}

function success(id, result) {
  send({ jsonrpc: "2.0", id, result });
}

function failure(id, code, message) {
  send({ jsonrpc: "2.0", id, error: { code, message } });
}

function handleMessage(message) {
  if (!("id" in message)) {
    return;
  }

  try {
    switch (message.method) {
      case "initialize":
        success(message.id, {
          protocolVersion: message.params?.protocolVersion ?? "2024-11-05",
          capabilities: {
            resources: {},
            tools: {}
          },
          serverInfo: {
            name: "OpenGraphite",
            version: "0.1.0"
          }
        });
        break;
      case "resources/list":
        success(message.id, { resources: resourcesList() });
        break;
      case "resources/read":
        success(message.id, { contents: [readResource(message.params?.uri)] });
        break;
      case "tools/list":
        success(message.id, { tools: toolsList() });
        break;
      case "tools/call":
        success(message.id, callTool(message.params?.name, message.params?.arguments ?? {}));
        break;
      default:
        failure(message.id, -32601, `Unknown method: ${message.method}`);
    }
  } catch (error) {
    failure(message.id, -32000, error instanceof Error ? error.message : String(error));
  }
}

function resourcesList() {
  return [
    {
      uri: "opengraphite://contract/css",
      name: "OpenGraphite Contract",
      description: "Machine-readable optional annotation/adoption policy and editable CSS declaration contract.",
      mimeType: "application/json"
    },
    {
      uri: "opengraphite://project/sample",
      name: "Sample Project",
      description: "Resolved SampleProject/OpenGraphiteSample.ogp summary.",
      mimeType: "application/json"
    },
    {
      uri: "opengraphite://project/current",
      name: "Current App Project",
      description: "Project currently opened by OpenGraphite.app, as recorded in Application Support.",
      mimeType: "application/json"
    },
    {
      uri: "opengraphite://design-tokens/sample",
      name: "Sample Design Tokens",
      description: "Design tokens from the sample project's CSS library.",
      mimeType: "application/json"
    },
    {
      uri: "opengraphite://design-tokens/current",
      name: "Current App Project Design Tokens",
      description: "Design tokens from the project currently opened by OpenGraphite.app.",
      mimeType: "application/json"
    },
    {
      uri: "opengraphite://pages/sample",
      name: "Sample Pages",
      description: "Sample project pages as resolved by ogkiln.",
      mimeType: "application/json"
    },
    {
      uri: "opengraphite://pages/current",
      name: "Current App Project Pages",
      description: "Pages from the project currently opened by OpenGraphite.app.",
      mimeType: "application/json"
    },
    {
      uri: "opengraphite://components/sample",
      name: "Sample Components",
      description: "Sample project component collections as resolved by ogkiln.",
      mimeType: "application/json"
    },
    {
      uri: "opengraphite://components/current",
      name: "Current App Project Components",
      description: "Component collections from the project currently opened by OpenGraphite.app.",
      mimeType: "application/json"
    },
    {
      uri: "opengraphite://pages/sample/home/graph",
      name: "Sample Home Graph",
      description: "OpenGraphite node graph for the sample home page.",
      mimeType: "application/json"
    },
    {
      uri: "opengraphite://pages/sample/home/html",
      name: "Sample Home HTML",
      description: "Source HTML for the sample home page.",
      mimeType: "text/html"
    },
    {
      uri: "opengraphite://components/sample/design-system/graph",
      name: "Sample Design System Component Graph",
      description: "OpenGraphite node graph for the sample design-system component canvas.",
      mimeType: "application/json"
    },
    {
      uri: "opengraphite://components/sample/design-system/html",
      name: "Sample Design System Component HTML",
      description: "Source HTML for the sample design-system component canvas.",
      mimeType: "text/html"
    }
  ];
}

function readResource(uri) {
  switch (uri) {
    case "opengraphite://contract/css":
      return textResource(uri, "application/json", readFileSync(join(repoRoot, "OpenGraphite.contract.json"), "utf8"));
    case "opengraphite://project/sample":
      return textResource(uri, "application/json", runOgkiln(["project", "inspect", "SampleProject/OpenGraphiteSample.ogp", "--json"]).stdout);
    case "opengraphite://project/current":
      return textResource(uri, "application/json", runOgkiln(["project", "current", "--json"]).stdout);
    case "opengraphite://design-tokens/sample":
      return textResource(uri, "application/json", runOgkiln(["design-token", "list", "SampleProject/OpenGraphiteSample.ogp", "--json"]).stdout);
    case "opengraphite://design-tokens/current":
      return textResource(uri, "application/json", runOgkiln(["design-token", "list", "current", "--json"]).stdout);
    case "opengraphite://pages/sample": {
      const project = JSON.parse(runOgkiln(["project", "inspect", "SampleProject/OpenGraphiteSample.ogp", "--json"]).stdout);
      return textResource(uri, "application/json", JSON.stringify(project.pages, null, 2));
    }
    case "opengraphite://pages/current": {
      const project = JSON.parse(runOgkiln(["project", "current", "--json"]).stdout);
      return textResource(uri, "application/json", JSON.stringify(project.pages, null, 2));
    }
    case "opengraphite://components/sample": {
      const project = JSON.parse(runOgkiln(["project", "inspect", "SampleProject/OpenGraphiteSample.ogp", "--json"]).stdout);
      return textResource(uri, "application/json", JSON.stringify(project.collections, null, 2));
    }
    case "opengraphite://components/current": {
      const project = JSON.parse(runOgkiln(["project", "current", "--json"]).stdout);
      return textResource(uri, "application/json", JSON.stringify(project.collections, null, 2));
    }
    case "opengraphite://pages/sample/home/graph":
      return textResource(uri, "application/json", runOgkiln(["page", "graph", "SampleProject/OpenGraphiteSample.ogp", "--page-id", "home", "--json"]).stdout);
    case "opengraphite://pages/sample/home/html":
      return textResource(uri, "text/html", readFileSync(join(repoRoot, "public", "index.html"), "utf8"));
    case "opengraphite://components/sample/design-system/graph":
      return textResource(uri, "application/json", runOgkiln(["page", "graph", "SampleProject/OpenGraphiteSample.ogp", "--component-id", "ogref:component:component-main:3bgx6phkz3jv5", "--json"]).stdout);
    case "opengraphite://components/sample/design-system/html":
      return textResource(uri, "text/html", readFileSync(join(repoRoot, "public", "_components", "design-system.html"), "utf8"));
    default:
      throw new Error(`Unknown resource: ${uri}`);
  }
}

function textResource(uri, mimeType, text) {
  return { uri, mimeType, text };
}

export function toolsList() {
  return [
    {
      name: "validate",
      description: "Validate an OpenGraphite .ogp project. projectPath may be an .ogp path or 'current'.",
      inputSchema: objectSchema({
        projectPath: { type: "string", description: ".ogp path, relative to the repository root or absolute, or 'current'." }
      }, ["projectPath"])
    },
    {
      name: "migrate_project",
      description: "Dry-run an explicit project Web-contract migration, or atomically apply the exact reviewed proposal. Dry-run is the default; apply requires proposalReference.",
      inputSchema: objectSchema({
        project: { type: "string", description: ".ogp path, relative to the repository root or absolute, or 'current'." },
        targetVersion: { type: "string", description: "Target Web contract version. Defaults to the contract migration policy target." },
        proposalReference: { type: "string", description: "Apply-only proposalReference returned by a dry-run with the same project and target." },
        apply: { type: "boolean", description: "Apply the reviewed proposal when true. Omit or false for dry-run." }
      }, ["project"])
    },
    {
      name: "get_contract",
      description: "Return the active OpenGraphite contract used by ogkiln.",
      inputSchema: objectSchema({}, [])
    },
    {
      name: "list_canvas_annotations",
      description: "List sticky-note and ink annotation summaries stored only in one Chapter or Collection canvas of an OpenGraphite .ogp project.",
      inputSchema: annotationContainerObjectSchema({
        projectPath: { type: "string", description: ".ogp path, relative to the repository root or absolute, or 'current'." },
        chapterID: { type: "string", description: "Chapter ID, internal ID, or ogref:chapter. Mutually exclusive with collectionID." },
        collectionID: { type: "string", description: "Collection ID, internal ID, or ogref:collection. Mutually exclusive with chapterID." }
      }, ["projectPath"])
    },
    {
      name: "get_canvas_annotation",
      description: "Get one complete .ogp canvas annotation, including ink stroke points. A typed ogref:annotation ID can resolve its Chapter or Collection without a separate selector.",
      inputSchema: objectSchema({
        projectPath: { type: "string", description: ".ogp path, relative to the repository root or absolute, or 'current'." },
        id: { type: "string", description: "Raw annotation internal ID or ogref:annotation:<pages|components>:<containerInternalID>:<annotationInternalID>." },
        chapterID: { type: "string", description: "Chapter selector required for a raw annotation ID. Mutually exclusive with collectionID." },
        collectionID: { type: "string", description: "Collection selector required for a raw annotation ID. Mutually exclusive with chapterID." }
      }, ["projectPath", "id"])
    },
    {
      name: "list_design_tokens",
      description: "List project-level design tokens stored as CSS custom properties in the project CSS :root rule.",
      inputSchema: objectSchema({
        projectPath: { type: "string", description: ".ogp path, relative to the repository root or absolute, or 'current'." }
      }, ["projectPath"])
    },
    {
      name: "set_design_token",
      description: "Set a project-level design token in the project CSS :root rule.",
      inputSchema: objectSchema({
        projectPath: { type: "string", description: ".ogp path, relative to the repository root or absolute, or 'current'." },
        name: { type: "string", description: "CSS custom property name, for example --color-primary." },
        value: { type: "string", description: "CSS value stored on the token." }
      }, ["projectPath", "name", "value"])
    },
    {
      name: "remove_design_token",
      description: "Remove a project-level design token from the project CSS :root rule.",
      inputSchema: objectSchema({
        projectPath: { type: "string", description: ".ogp path, relative to the repository root or absolute, or 'current'." },
        name: { type: "string", description: "CSS custom property name, for example --color-primary." }
      }, ["projectPath", "name"])
    },
    {
      name: "list_locale_typography",
      description: "List authored root and :lang() font-family declarations for one page or component without writing computed preview state.",
      inputSchema: targetObjectSchema({
        projectPath: { type: "string", description: ".ogp path, relative to the repository root or absolute, or 'current'." },
        ...pageSelectorProperties()
      }, ["projectPath"])
    },
    {
      name: "set_locale_typography",
      description: "Set the standard root or :lang() font-family declaration for one page or component while preserving CSS source provenance.",
      inputSchema: targetObjectSchema({
        projectPath: { type: "string", description: ".ogp path, relative to the repository root or absolute, or 'current'." },
        ...pageSelectorProperties(),
        locale: { type: "string", description: "Optional 'default' or a selector-safe BCP 47 tag. Omit for the root declaration." },
        value: { type: "string", description: "Complete standard CSS font-family value." }
      }, ["projectPath", "value"])
    },
    {
      name: "remove_locale_typography",
      description: "Remove the standard root or :lang() font-family declaration for one page or component while preserving surrounding source.",
      inputSchema: targetObjectSchema({
        projectPath: { type: "string", description: ".ogp path, relative to the repository root or absolute, or 'current'." },
        ...pageSelectorProperties(),
        locale: { type: "string", description: "Optional 'default' or a selector-safe BCP 47 tag. Omit for the root declaration." }
      }, ["projectPath"])
    },
    {
      name: "build_project",
      description: "Build project pages by statically expanding og-instance component references into an output directory.",
      inputSchema: objectSchema({
        projectPath: { type: "string", description: ".ogp path, relative to the repository root or absolute, or 'current'." },
        outputPath: { type: "string" }
      }, ["projectPath", "outputPath"])
    },
    {
      name: "add_project_page",
      description: "Add a page entry to the default Chapter in an OpenGraphite .ogp project.",
      inputSchema: objectSchema({
        projectPath: { type: "string", description: ".ogp path or 'current'." },
        pageID: { type: "string" },
        path: { type: "string" },
        x: { type: "number" },
        y: { type: "number" },
        width: { type: "number" },
        height: { type: "number" }
      }, ["projectPath", "pageID", "path"])
    },
    {
      name: "create_project_page",
      description: "Create a new HTML page through an OpenGraphite .ogp project and register it in the default Chapter pages.",
      inputSchema: objectSchema({
        projectPath: { type: "string", description: ".ogp path or 'current'." },
        pageID: { type: "string" },
        path: { type: "string", description: "HTML path relative to the project's htmlRoot." },
        title: { type: "string" },
        lang: { type: "string" },
        stylesheet: { type: "string" },
        bodyHTML: { type: "string" },
        overwrite: { type: "boolean" },
        x: { type: "number" },
        y: { type: "number" },
        width: { type: "number" },
        height: { type: "number" }
      }, ["projectPath", "pageID", "path", "title", "bodyHTML"])
    },
    {
      name: "place_project_page",
      description: "Update the canvas placement for an existing OpenGraphite .ogp page entry.",
      inputSchema: objectSchema({
        projectPath: { type: "string", description: ".ogp path or 'current'." },
        pageID: { type: "string" },
        name: { type: "string", description: "Canvas placement name. Empty string clears the name." },
        x: { type: "number" },
        y: { type: "number" },
        width: { type: "number" },
        height: { type: "number" },
        previewMocks: { type: "object", additionalProperties: { type: "string" } }
      }, ["projectPath", "pageID"])
    },
    {
      name: "set_project_page_document_context",
      description: "Update persistent <html> lang/dir attributes and OpenGraphite binding metadata for a project page HTML document.",
      inputSchema: objectSchema({
        projectPath: { type: "string", description: ".ogp path or 'current'." },
        pageID: { type: "string" },
        langSource: { type: "string", enum: ["literal", "binding"] },
        lang: { type: "string", description: "Literal or fallback lang attribute value." },
        langField: { type: "string", description: "Runtime field used when langSource is binding." },
        dirSource: { type: "string", enum: ["literal", "auto", "binding"] },
        dir: { type: "string", enum: ["ltr", "rtl", "auto", ""] },
        dirField: { type: "string", description: "Runtime field used when dirSource is binding." }
      }, ["projectPath", "pageID"])
    },
    {
      name: "add_project_component",
      description: "Add an existing HTML file to a component Collection in an OpenGraphite .ogp project.",
      inputSchema: objectSchema({
        projectPath: { type: "string", description: ".ogp path or 'current'." },
        collectionID: { type: "string", description: "Collection ID, internal ID, or ogref:collection. Defaults to the first/default Collection." },
        componentID: { type: "string" },
        path: { type: "string", description: "HTML path relative to the project's htmlRoot." },
        x: { type: "number" },
        y: { type: "number" },
        width: { type: "number" },
        height: { type: "number" }
      }, ["projectPath", "componentID", "path"])
    },
    {
      name: "create_project_component",
      description: "Create a new component canvas HTML file and register it in a component Collection.",
      inputSchema: objectSchema({
        projectPath: { type: "string", description: ".ogp path or 'current'." },
        collectionID: { type: "string", description: "Collection ID, internal ID, or ogref:collection. Defaults to the first/default Collection." },
        componentID: { type: "string" },
        path: { type: "string", description: "HTML path relative to the project's htmlRoot." },
        title: { type: "string" },
        lang: { type: "string" },
        stylesheet: { type: "string" },
        bodyHTML: { type: "string" },
        overwrite: { type: "boolean" }
      }, ["projectPath", "componentID", "path", "title", "bodyHTML"])
    },
    {
      name: "place_project_component",
      description: "Update the canvas placement for an existing component canvas.",
      inputSchema: objectSchema({
        projectPath: { type: "string", description: ".ogp path or 'current'." },
        componentID: { type: "string" },
        name: { type: "string", description: "Canvas placement name. Empty string clears the name." },
        x: { type: "number" },
        y: { type: "number" },
        width: { type: "number" },
        height: { type: "number" },
        previewMocks: { type: "object", additionalProperties: { type: "string" } },
        previewPlacementMocks: {
          type: "object",
          additionalProperties: {
            type: "object",
            additionalProperties: { type: "string" }
          }
        }
      }, ["projectPath", "componentID"])
    },
    {
      name: "set_project_component_document_context",
      description: "Update persistent <html> lang/dir attributes and OpenGraphite binding metadata for a component HTML document.",
      inputSchema: objectSchema({
        projectPath: { type: "string", description: ".ogp path or 'current'." },
        componentID: { type: "string" },
        langSource: { type: "string", enum: ["literal", "binding"] },
        lang: { type: "string", description: "Literal or fallback lang attribute value." },
        langField: { type: "string", description: "Runtime field used when langSource is binding." },
        dirSource: { type: "string", enum: ["literal", "auto", "binding"] },
        dir: { type: "string", enum: ["ltr", "rtl", "auto", ""] },
        dirField: { type: "string", description: "Runtime field used when dirSource is binding." }
      }, ["projectPath", "componentID"])
    },
    {
      name: "remove_project_component",
      description: "Remove a component canvas registration, optionally deleting its HTML file.",
      inputSchema: objectSchema({
        projectPath: { type: "string", description: ".ogp path or 'current'." },
        componentID: { type: "string" },
        deleteFile: { type: "boolean" }
      }, ["projectPath", "componentID"])
    },
    {
      name: "list_nodes",
      description: "Return every inspectable DOM node for a registered page or component, including standard CSS-derived layout, source/resolved visibility, annotation status, references, and locators. Optional active media conditions never mutate source.",
      inputSchema: targetObjectSchema({
        projectPath: { type: "string", description: ".ogp path or 'current'." },
        ...pageSelectorProperties(),
        activeMediaQueries: { type: "array", items: { type: "string" }, description: "Authored CSSMediaRule.conditionText values confirmed active by the rendering environment." }
      }, ["projectPath"])
    },
    {
      name: "screenshot_canvas",
      description: "Render the default or selected Chapter / Collection canvas in an OpenGraphite .ogp project to a PNG file, including .ogp-only canvas annotations.",
      inputSchema: optionalAnnotationContainerObjectSchema({
        projectPath: { type: "string", description: ".ogp path or 'current'." },
        outputPath: { type: "string" },
        chapterID: { type: "string", description: "Optional Chapter ID, internal ID, or ogref:chapter. Mutually exclusive with collectionID." },
        collectionID: { type: "string", description: "Optional Collection ID, internal ID, or ogref:collection. Mutually exclusive with chapterID." }
      }, ["projectPath", "outputPath"])
    },
    {
      name: "screenshot_page",
      description: "Render one project-registered OpenGraphite page or component canvas to a PNG file.",
      inputSchema: targetObjectSchema({
        projectPath: { type: "string", description: ".ogp path or 'current'." },
        ...pageSelectorProperties(),
        outputPath: { type: "string" },
        width: { type: "number" },
        height: { type: "number" },
        fullPage: { type: "boolean" }
      }, ["projectPath", "outputPath"])
    },
    {
      name: "screenshot_node",
      description: "Render one data-og-internal-id or ogref node from a project-registered page or component canvas to a cropped PNG file.",
      inputSchema: nodeTargetObjectSchema({
        projectPath: { type: "string", description: ".ogp path or 'current'." },
        ...pageSelectorProperties(),
        id: { type: "string" },
        outputPath: { type: "string" },
        width: { type: "number" },
        height: { type: "number" },
        padding: { type: "number" }
      }, ["projectPath", "id", "outputPath"])
    },
    {
      name: "query_nodes",
      description: "Filter every inspectable standard DOM node by optional annotation, legacy data-og-type hint, operation capabilities, tag, or text without adopting annotations. Capabilities are derived from standard DOM/CSS semantics and every requested capability must match.",
      inputSchema: targetObjectSchema({
        projectPath: { type: "string", description: ".ogp path or 'current'." },
        ...pageSelectorProperties(),
        idContains: { type: "string" },
        type: { type: "string", description: "Deprecated legacy data-og-type hint filter. It does not grant operation capability." },
        capabilities: {
          type: "array",
          items: {
            type: "string",
            enum: [
              "drag-position", "edit-control", "edit-icon", "edit-layout", "edit-link",
              "edit-media", "edit-text", "group", "receive-children", "reorder-flow", "ungroup"
            ]
          },
          description: "Operation capabilities that the node must all satisfy."
        },
        role: { type: "string" },
        tag: { type: "string" },
        textContains: { type: "string" },
        activeMediaQueries: { type: "array", items: { type: "string" }, description: "Authored CSSMediaRule.conditionText values confirmed active by the rendering environment." }
      }, ["projectPath"])
    },
    {
      name: "get_node",
      description: "Inspect one node by stable data-og-internal-id/typed ogref or a session-scoped graph reference without adopting annotations. Session references are not mutation targets.",
      inputSchema: nodeTargetObjectSchema({
        projectPath: { type: "string", description: ".ogp path or 'current'." },
        ...pageSelectorProperties(),
        id: { type: "string" },
        activeMediaQueries: { type: "array", items: { type: "string" }, description: "Authored CSSMediaRule.conditionText values confirmed active by the rendering environment." }
      }, ["projectPath", "id"])
    },
    {
      name: "adopt_node",
      description: "Preview optional OpenGraphite identity for one node or subtree by inspected reference/selector/DOM path. Dry-run is the default and returns a unified source diff plus an apply-only proposal targetReference binding the target, whole-document hash, scope, and displayID; apply requires that reference with the same normalized proposal parameters.",
      inputSchema: adoptionTargetObjectSchema({
        projectPath: { type: "string", description: ".ogp path or 'current'." },
        ...pageSelectorProperties(),
        reference: { type: "string", description: "Inspection reference for dry-run, or the apply-only proposal targetReference returned by dry-run when apply is true. A graph session reference cannot be applied directly." },
        selector: { type: "string", description: "Safe locator.selector returned by node inspection. Dry-run only." },
        domPath: { type: "string", description: "locator.domPath returned by node inspection. Dry-run only." },
        scope: { type: "string", enum: ["node", "subtree"], description: "Adopt only the target node or its inspectable subtree. Defaults to node and must match the dry-run when apply is true." },
        displayID: { type: "string", description: "Optional human-readable data-og-id proposed for the target node. Its normalized value must match the dry-run when apply is true." },
        apply: { type: "boolean", description: "When true, apply the reviewed diff using the dry-run proposal targetReference and identical normalized scope/displayID. Omit or false for dry-run." }
      }, ["projectPath"])
    },
    {
      name: "set_css_variable",
      description: "Set an editable companion CSS declaration. Requires a stable data-og-internal-id or typed ogref; explicitly adopt a session reference first.",
      inputSchema: nodeTargetObjectSchema({
        projectPath: { type: "string", description: ".ogp path or 'current'." },
        ...pageSelectorProperties(),
        id: { type: "string" },
        variable: { type: "string" },
        value: { type: "string" },
        activeMediaQueries: { type: "array", items: { type: "string" }, description: "Active authored media conditions used to update the reviewed cascade winner in place." }
      }, ["projectPath", "id", "variable", "value"])
    },
    {
      name: "remove_css_variable",
      description: "Remove an editable companion CSS declaration. Requires a stable data-og-internal-id or typed ogref; explicitly adopt a session reference first.",
      inputSchema: nodeTargetObjectSchema({
        projectPath: { type: "string", description: ".ogp path or 'current'." },
        ...pageSelectorProperties(),
        id: { type: "string" },
        variable: { type: "string" },
        activeMediaQueries: { type: "array", items: { type: "string" }, description: "Active authored media conditions used to remove the reviewed cascade winner in place." }
      }, ["projectPath", "id", "variable"])
    },
    {
      name: "set_node_attribute",
      description: "Set an editable standard HTML or OpenGraphite metadata attribute on a capability-compatible DOM target. Empty strings remain present empty attributes; use remove_node_attribute to delete the token. Requires a stable data-og-internal-id or typed ogref; explicitly adopt a session reference first.",
      inputSchema: nodeTargetObjectSchema({
        projectPath: { type: "string", description: ".ogp path or 'current'." },
        ...pageSelectorProperties(),
        id: { type: "string" },
        name: { type: "string" },
        value: { type: "string" }
      }, ["projectPath", "id", "name", "value"])
    },
    {
      name: "remove_node_attribute",
      description: "Remove an editable standard HTML or OpenGraphite metadata attribute token from a capability-compatible DOM target. This is distinct from setting an empty string. Requires a stable data-og-internal-id or typed ogref; explicitly adopt a session reference first.",
      inputSchema: nodeTargetObjectSchema({
        projectPath: { type: "string", description: ".ogp path or 'current'." },
        ...pageSelectorProperties(),
        id: { type: "string" },
        name: { type: "string" }
      }, ["projectPath", "id", "name"])
    },
    {
      name: "set_icon",
      description: "Update a Lucide icon wrapper's existing OpenGraphite icon metadata and saved markup. Plain SVG edit-icon nodes remain available to CSS stroke editing but cannot be replaced by this tool. Requires a stable data-og-internal-id or typed ogref; explicitly adopt a session reference first.",
      inputSchema: nodeTargetObjectSchema({
        projectPath: { type: "string", description: ".ogp path or 'current'." },
        ...pageSelectorProperties(),
        id: { type: "string", description: "Icon node data-og-internal-id or ogref." },
        name: { type: "string", description: "Lucide icon name, e.g. circle or star." },
        library: { type: "string", enum: ["lucide"] },
        source: { type: "string", enum: ["inline", "cdn", "library"] }
      }, ["projectPath", "id", "name"])
    },
    {
      name: "insert_icon",
      description: "Insert a Lucide icon relative to an anchor. Requires a stable data-og-internal-id or typed ogref; explicitly adopt a session anchor first.",
      inputSchema: nodeTargetObjectSchema({
        projectPath: { type: "string", description: ".ogp path or 'current'." },
        ...pageSelectorProperties(),
        id: { type: "string", description: "Anchor node data-og-internal-id or ogref." },
        position: { type: "string", enum: ["before", "after", "prepend", "append"] },
        name: { type: "string", description: "Lucide icon name, e.g. circle or star." },
        iconID: { type: "string", description: "Optional data-og-id for the new icon node." },
        library: { type: "string", enum: ["lucide"] },
        source: { type: "string", enum: ["inline", "cdn", "library"] },
        width: { type: "string", description: "Optional CSS width value." },
        height: { type: "string", description: "Optional CSS height value." }
      }, ["projectPath", "id", "position", "name"])
    },
    {
      name: "set_text_content",
      description: "Replace a node's inner content with escaped plain text. Requires a stable data-og-internal-id or typed ogref; explicitly adopt a session reference first.",
      inputSchema: nodeTargetObjectSchema({
        projectPath: { type: "string", description: ".ogp path or 'current'." },
        ...pageSelectorProperties(),
        id: { type: "string" },
        text: { type: "string" }
      }, ["projectPath", "id", "text"])
    },
    {
      name: "insert_html",
      description: "Insert an HTML fragment relative to an anchor. Requires a stable data-og-internal-id or typed ogref; explicitly adopt a session anchor first.",
      inputSchema: nodeTargetObjectSchema({
        projectPath: { type: "string", description: ".ogp path or 'current'." },
        ...pageSelectorProperties(),
        id: { type: "string" },
        position: { type: "string", enum: ["before", "after", "prepend", "append"] },
        html: { type: "string" }
      }, ["projectPath", "id", "position", "html"])
    },
    {
      name: "replace_node_html",
      description: "Replace a node subtree with an HTML fragment. Requires a stable data-og-internal-id or typed ogref; explicitly adopt a session reference first.",
      inputSchema: nodeTargetObjectSchema({
        projectPath: { type: "string", description: ".ogp path or 'current'." },
        ...pageSelectorProperties(),
        id: { type: "string" },
        html: { type: "string" }
      }, ["projectPath", "id", "html"])
    },
    {
      name: "delete_node",
      description: "Delete a node subtree. Requires a stable data-og-internal-id or typed ogref; explicitly adopt a session reference first.",
      inputSchema: nodeTargetObjectSchema({
        projectPath: { type: "string", description: ".ogp path or 'current'." },
        ...pageSelectorProperties(),
        id: { type: "string" }
      }, ["projectPath", "id"])
    },
    {
      name: "move_node",
      description: "Move a node subtree relative to a target. Both require a stable data-og-internal-id or typed ogref; explicitly adopt any session reference first.",
      inputSchema: nodeTargetObjectSchema({
        projectPath: { type: "string", description: ".ogp path or 'current'." },
        ...pageSelectorProperties(),
        id: { type: "string" },
        target: { type: "string" },
        position: { type: "string", enum: ["before", "after", "prepend", "append"] }
      }, ["projectPath", "id", "target", "position"])
    },
    {
      name: "copy_node",
      description: "Copy a node subtree and insert it relative to a target. Both require a stable data-og-internal-id or typed ogref; explicitly adopt any session reference first.",
      inputSchema: nodeTargetObjectSchema({
        projectPath: { type: "string", description: ".ogp path or 'current'." },
        ...pageSelectorProperties(),
        id: { type: "string" },
        target: { type: "string" },
        position: { type: "string", enum: ["before", "after", "prepend", "append"] },
        idPrefix: { type: "string" }
      }, ["projectPath", "id", "target", "position", "idPrefix"])
    }
  ];
}

function objectSchema(properties, required) {
  return {
    type: "object",
    properties,
    required,
    additionalProperties: false
  };
}

function targetObjectSchema(properties, required) {
  return {
    ...objectSchema(properties, required),
    oneOf: [
      { required: ["pageID"] },
      { required: ["componentID"] }
    ]
  };
}

function adoptionTargetObjectSchema(properties, required) {
  return {
    ...objectSchema(properties, required),
    allOf: [
      {
        oneOf: [
          { required: ["pageID"] },
          { required: ["componentID"] }
        ]
      },
      {
        oneOf: [
          { required: ["reference"] },
          { required: ["selector"] },
          { required: ["domPath"] }
        ]
      },
      {
        if: {
          required: ["apply"],
          properties: { apply: { const: true } }
        },
        then: { required: ["reference"] }
      }
    ]
  };
}

function annotationContainerObjectSchema(properties, required) {
  return {
    ...objectSchema(properties, required),
    oneOf: [
      { required: ["chapterID"] },
      { required: ["collectionID"] }
    ]
  };
}

function optionalAnnotationContainerObjectSchema(properties, required) {
  return {
    ...objectSchema(properties, required),
    not: { required: ["chapterID", "collectionID"] }
  };
}

function nodeTargetObjectSchema(properties, required) {
  return objectSchema(properties, required);
}

function callTool(name, args) {
  const command = commandForTool(name, args);
  const result = runOgkiln(command);
  const text = result.stdout || result.stderr;
  return {
    content: [{ type: "text", text }],
    isError: result.status !== 0
  };
}

export function commandForTool(name, args) {
  switch (name) {
    case "validate":
      return ["validate", requiredArg(args, "projectPath"), "--json"];
    case "migrate_project":
      return [
        "migrate",
        requiredArg(args, "project"),
        ...optionalFlag(args, "targetVersion", "--target-version"),
        ...optionalFlag(args, "proposalReference", "--proposal"),
        ...(args?.apply === true ? ["--apply"] : []),
        "--json"
      ];
    case "get_contract":
      return ["contract", "get", "--json"];
    case "list_canvas_annotations":
      return [
        "annotation",
        "list",
        requiredArg(args, "projectPath"),
        ...optionalFlag(args, "chapterID", "--chapter-id"),
        ...optionalFlag(args, "collectionID", "--collection-id"),
        "--json"
      ];
    case "get_canvas_annotation":
      return [
        "annotation",
        "get",
        requiredArg(args, "projectPath"),
        "--id",
        requiredArg(args, "id"),
        ...optionalFlag(args, "chapterID", "--chapter-id"),
        ...optionalFlag(args, "collectionID", "--collection-id"),
        "--json"
      ];
    case "list_design_tokens":
      return ["design-token", "list", requiredArg(args, "projectPath"), "--json"];
    case "set_design_token":
      return [
        "design-token",
        "set",
        requiredArg(args, "projectPath"),
        "--name",
        requiredArg(args, "name"),
        "--value",
        requiredArg(args, "value")
      ];
    case "remove_design_token":
      return [
        "design-token",
        "remove",
        requiredArg(args, "projectPath"),
        "--name",
        requiredArg(args, "name")
      ];
    case "list_locale_typography":
      return [
        "locale-typography",
        "list",
        requiredArg(args, "projectPath"),
        ...pageSelectorArgs(args),
        "--json"
      ];
    case "set_locale_typography":
      return [
        "locale-typography",
        "set",
        requiredArg(args, "projectPath"),
        ...pageSelectorArgs(args),
        ...optionalFlag(args, "locale", "--locale"),
        "--value",
        requiredArg(args, "value"),
        "--json"
      ];
    case "remove_locale_typography":
      return [
        "locale-typography",
        "remove",
        requiredArg(args, "projectPath"),
        ...pageSelectorArgs(args),
        ...optionalFlag(args, "locale", "--locale"),
        "--json"
      ];
    case "build_project":
      return ["build", requiredArg(args, "projectPath"), "--output", requiredArg(args, "outputPath")];
    case "add_project_page":
      return [
        "project",
        "page",
        "add",
        requiredArg(args, "projectPath"),
        "--page-id",
        requiredArg(args, "pageID"),
        "--path",
        requiredArg(args, "path"),
        ...optionalValueFlag(args, "x", "--x"),
        ...optionalValueFlag(args, "y", "--y"),
        ...optionalValueFlag(args, "width", "--width"),
        ...optionalValueFlag(args, "height", "--height")
      ];
    case "create_project_page":
      return [
        "project",
        "page",
        "create",
        requiredArg(args, "projectPath"),
        "--page-id",
        requiredArg(args, "pageID"),
        "--path",
        requiredArg(args, "path"),
        "--title",
        requiredArg(args, "title"),
        ...optionalFlag(args, "lang", "--lang"),
        ...optionalFlag(args, "stylesheet", "--stylesheet"),
        "--body-html",
        requiredArg(args, "bodyHTML"),
        ...optionalValueFlag(args, "x", "--x"),
        ...optionalValueFlag(args, "y", "--y"),
        ...optionalValueFlag(args, "width", "--width"),
        ...optionalValueFlag(args, "height", "--height"),
        ...(args?.overwrite === true ? ["--overwrite"] : []),
        "--json"
      ];
    case "place_project_page":
      return [
        "project",
        "page",
        "place",
        requiredArg(args, "projectPath"),
        "--page-id",
        requiredArg(args, "pageID"),
        ...optionalNullableStringFlag(args, "name", "--name"),
        ...optionalValueFlag(args, "x", "--x"),
        ...optionalValueFlag(args, "y", "--y"),
        ...optionalValueFlag(args, "width", "--width"),
        ...optionalValueFlag(args, "height", "--height"),
        ...optionalPreviewMockFlags(args)
      ];
    case "set_project_page_document_context":
      return [
        "project",
        "page",
        "document",
        requiredArg(args, "projectPath"),
        "--page-id",
        requiredArg(args, "pageID"),
        ...optionalFlag(args, "langSource", "--lang-source"),
        ...optionalNullableStringFlag(args, "lang", "--lang"),
        ...optionalNullableStringFlag(args, "langField", "--lang-field"),
        ...optionalFlag(args, "dirSource", "--dir-source"),
        ...optionalNullableStringFlag(args, "dir", "--dir"),
        ...optionalNullableStringFlag(args, "dirField", "--dir-field"),
        "--json"
      ];
    case "add_project_component":
      return [
        "project",
        "component",
        "add",
        requiredArg(args, "projectPath"),
        ...optionalFlag(args, "collectionID", "--collection-id"),
        "--component-id",
        requiredArg(args, "componentID"),
        "--path",
        requiredArg(args, "path"),
        ...optionalValueFlag(args, "x", "--x"),
        ...optionalValueFlag(args, "y", "--y"),
        ...optionalValueFlag(args, "width", "--width"),
        ...optionalValueFlag(args, "height", "--height")
      ];
    case "set_project_component_document_context":
      return [
        "project",
        "component",
        "document",
        requiredArg(args, "projectPath"),
        "--component-id",
        requiredArg(args, "componentID"),
        ...optionalFlag(args, "langSource", "--lang-source"),
        ...optionalNullableStringFlag(args, "lang", "--lang"),
        ...optionalNullableStringFlag(args, "langField", "--lang-field"),
        ...optionalFlag(args, "dirSource", "--dir-source"),
        ...optionalNullableStringFlag(args, "dir", "--dir"),
        ...optionalNullableStringFlag(args, "dirField", "--dir-field"),
        "--json"
      ];
    case "create_project_component":
      return [
        "project",
        "component",
        "create",
        requiredArg(args, "projectPath"),
        ...optionalFlag(args, "collectionID", "--collection-id"),
        "--component-id",
        requiredArg(args, "componentID"),
        "--path",
        requiredArg(args, "path"),
        "--title",
        requiredArg(args, "title"),
        ...optionalFlag(args, "lang", "--lang"),
        ...optionalFlag(args, "stylesheet", "--stylesheet"),
        "--body-html",
        requiredArg(args, "bodyHTML"),
        ...(args?.overwrite === true ? ["--overwrite"] : []),
        "--json"
      ];
    case "place_project_component":
      return [
        "project",
        "component",
        "place",
        requiredArg(args, "projectPath"),
        "--component-id",
        requiredArg(args, "componentID"),
        ...optionalNullableStringFlag(args, "name", "--name"),
        ...optionalValueFlag(args, "x", "--x"),
        ...optionalValueFlag(args, "y", "--y"),
        ...optionalValueFlag(args, "width", "--width"),
        ...optionalValueFlag(args, "height", "--height"),
        ...optionalPreviewMockFlags(args),
        ...optionalPreviewPlacementMockFlags(args)
      ];
    case "remove_project_component":
      return [
        "project",
        "component",
        "remove",
        requiredArg(args, "projectPath"),
        "--component-id",
        requiredArg(args, "componentID"),
        ...(args?.deleteFile === true ? ["--delete-file"] : [])
      ];
    case "list_nodes":
      return [
        "page", "graph", requiredArg(args, "projectPath"),
        ...pageSelectorArgs(args),
        ...optionalRepeatedStringFlags(args, "activeMediaQueries", "--active-media"),
        "--json"
      ];
    case "screenshot_canvas":
      return [
        "screenshot",
        "canvas",
        requiredArg(args, "projectPath"),
        "--output",
        requiredArg(args, "outputPath"),
        ...optionalFlag(args, "chapterID", "--chapter-id"),
        ...optionalFlag(args, "collectionID", "--collection-id")
      ];
    case "screenshot_page":
      return [
        "screenshot",
        "page",
        requiredArg(args, "projectPath"),
        ...pageSelectorArgs(args),
        "--output",
        requiredArg(args, "outputPath"),
        ...optionalValueFlag(args, "width", "--width"),
        ...optionalValueFlag(args, "height", "--height"),
        ...(args?.fullPage === true ? ["--full-page"] : [])
      ];
    case "screenshot_node":
      return [
        "screenshot",
        "node",
        requiredArg(args, "projectPath"),
        ...pageSelectorArgs(args),
        "--id",
        requiredArg(args, "id"),
        "--output",
        requiredArg(args, "outputPath"),
        ...optionalValueFlag(args, "width", "--width"),
        ...optionalValueFlag(args, "height", "--height"),
        ...optionalValueFlag(args, "padding", "--padding")
      ];
    case "query_nodes":
      return [
        "node",
        "query",
        requiredArg(args, "projectPath"),
        ...pageSelectorArgs(args),
        ...optionalFlag(args, "idContains", "--id-contains"),
        ...optionalFlag(args, "type", "--type"),
        ...optionalRepeatedStringFlags(args, "capabilities", "--capability"),
        ...optionalFlag(args, "role", "--role"),
        ...optionalFlag(args, "tag", "--tag"),
        ...optionalFlag(args, "textContains", "--text-contains"),
        ...optionalRepeatedStringFlags(args, "activeMediaQueries", "--active-media"),
        "--json"
      ];
    case "get_node":
      return [
        "node",
        "get",
        requiredArg(args, "projectPath"),
        ...pageSelectorArgs(args),
        "--id",
        requiredArg(args, "id"),
        ...optionalRepeatedStringFlags(args, "activeMediaQueries", "--active-media"),
        "--json"
      ];
    case "adopt_node":
      return [
        "node",
        "adopt",
        requiredArg(args, "projectPath"),
        ...pageSelectorArgs(args),
        ...adoptionLocatorArgs(args),
        ...optionalFlag(args, "scope", "--scope"),
        ...optionalFlag(args, "displayID", "--display-id"),
        ...(args?.apply === true ? ["--apply"] : []),
        "--json"
      ];
    case "set_css_variable":
      return [
        "node",
        "style",
        "set",
        requiredArg(args, "projectPath"),
        ...pageSelectorArgs(args),
        "--id",
        requiredArg(args, "id"),
        "--var",
        requiredArg(args, "variable"),
        "--value",
        requiredArg(args, "value"),
        ...optionalRepeatedStringFlags(args, "activeMediaQueries", "--active-media")
      ];
    case "remove_css_variable":
      return [
        "node",
        "style",
        "remove",
        requiredArg(args, "projectPath"),
        ...pageSelectorArgs(args),
        "--id",
        requiredArg(args, "id"),
        "--var",
        requiredArg(args, "variable"),
        ...optionalRepeatedStringFlags(args, "activeMediaQueries", "--active-media")
      ];
    case "set_node_attribute":
      return [
        "node",
        "attr",
        "set",
        requiredArg(args, "projectPath"),
        ...pageSelectorArgs(args),
        "--id",
        requiredArg(args, "id"),
        "--name",
        requiredArg(args, "name"),
        "--value",
        requiredStringArg(args, "value")
      ];
    case "remove_node_attribute":
      return [
        "node",
        "attr",
        "remove",
        requiredArg(args, "projectPath"),
        ...pageSelectorArgs(args),
        "--id",
        requiredArg(args, "id"),
        "--name",
        requiredArg(args, "name")
      ];
    case "set_icon":
      return [
        "node",
        "icon",
        "set",
        requiredArg(args, "projectPath"),
        ...pageSelectorArgs(args),
        "--id",
        requiredArg(args, "id"),
        "--name",
        requiredArg(args, "name"),
        ...optionalFlag(args, "library", "--library"),
        ...optionalFlag(args, "source", "--source"),
        "--json"
      ];
    case "insert_icon":
      return [
        "node",
        "icon",
        "insert",
        requiredArg(args, "projectPath"),
        ...pageSelectorArgs(args),
        "--id",
        requiredArg(args, "id"),
        "--position",
        requiredArg(args, "position"),
        "--name",
        requiredArg(args, "name"),
        ...optionalFlag(args, "iconID", "--icon-id"),
        ...optionalFlag(args, "library", "--library"),
        ...optionalFlag(args, "source", "--source"),
        ...optionalFlag(args, "width", "--width"),
        ...optionalFlag(args, "height", "--height"),
        "--json"
      ];
    case "set_text_content":
      return [
        "node",
        "text",
        "set",
        requiredArg(args, "projectPath"),
        ...pageSelectorArgs(args),
        "--id",
        requiredArg(args, "id"),
        "--value",
        requiredArg(args, "text")
      ];
    case "insert_html":
      return [
        "node",
        "html",
        "insert",
        requiredArg(args, "projectPath"),
        ...pageSelectorArgs(args),
        "--id",
        requiredArg(args, "id"),
        "--position",
        requiredArg(args, "position"),
        "--html",
        requiredArg(args, "html")
      ];
    case "replace_node_html":
      return [
        "node",
        "html",
        "replace",
        requiredArg(args, "projectPath"),
        ...pageSelectorArgs(args),
        "--id",
        requiredArg(args, "id"),
        "--html",
        requiredArg(args, "html")
      ];
    case "delete_node":
      return [
        "node",
        "delete",
        requiredArg(args, "projectPath"),
        ...pageSelectorArgs(args),
        "--id",
        requiredArg(args, "id")
      ];
    case "move_node":
      return [
        "node",
        "move",
        requiredArg(args, "projectPath"),
        ...pageSelectorArgs(args),
        "--id",
        requiredArg(args, "id"),
        "--target",
        requiredArg(args, "target"),
        "--position",
        requiredArg(args, "position")
      ];
    case "copy_node":
      return [
        "node",
        "copy",
        requiredArg(args, "projectPath"),
        ...pageSelectorArgs(args),
        "--id",
        requiredArg(args, "id"),
        "--target",
        requiredArg(args, "target"),
        "--position",
        requiredArg(args, "position"),
        "--id-prefix",
        requiredArg(args, "idPrefix")
      ];
    default:
      throw new Error(`Unknown tool: ${name}`);
  }
}

function pageSelectorProperties() {
  return {
    pageID: { type: "string", description: "Page reference ID. Mutually exclusive with componentID." },
    componentID: { type: "string", description: "Component canvas reference ID, e.g. ogref:component:<collectionInternalID>:<componentInternalID>. Mutually exclusive with pageID." }
  };
}

function pageSelectorArgs(args) {
  const pageID = optionalStringArg(args, "pageID");
  const componentID = optionalStringArg(args, "componentID");
  if (pageID && componentID) {
    throw new Error("Specify pageID or componentID, not both.");
  }
  if (componentID) {
    return ["--component-id", componentID];
  }
  if (pageID) {
    return ["--page-id", pageID];
  }
  if (typedNodeReference(args?.id)) {
    return [];
  }
  throw new Error("Missing required argument: pageID or componentID");
}

function typedNodeReference(value) {
  return typeof value === "string" && /^ogref:(node|component-node):/.test(value);
}

function adoptionLocatorArgs(args) {
  const candidates = [
    ["reference", "--reference"],
    ["selector", "--selector"],
    ["domPath", "--dom-path"]
  ].filter(([key]) => typeof args?.[key] === "string" && args[key].length > 0);
  if (candidates.length !== 1) {
    throw new Error("Specify exactly one adoption locator: reference, selector, or domPath.");
  }
  if (args?.apply === true && candidates[0][0] !== "reference") {
    throw new Error("Explicit adoption apply requires the proposal targetReference returned by dry-run with the same scope/displayID.");
  }
  const [key, flag] = candidates[0];
  return [flag, args[key]];
}

function optionalFlag(args, key, flag) {
  const value = args?.[key];
  if (typeof value !== "string" || value.length === 0) {
    return [];
  }
  return [flag, value];
}

function optionalNullableStringFlag(args, key, flag) {
  const value = args?.[key];
  if (value === undefined || value === null) {
    return [];
  }
  return [flag, String(value)];
}

function optionalValueFlag(args, key, flag) {
  const value = args?.[key];
  if (value === undefined || value === null || value === "") {
    return [];
  }
  return [flag, String(value)];
}

function optionalRepeatedStringFlags(args, key, flag) {
  const values = args?.[key];
  if (!Array.isArray(values)) {
    return [];
  }
  return values.flatMap((value) => {
    if (typeof value !== "string" || value.trim().length === 0) {
      return [];
    }
    return [flag, value];
  });
}

function optionalPreviewMockFlags(args) {
  const mocks = args?.previewMocks;
  if (!mocks || typeof mocks !== "object" || Array.isArray(mocks)) {
    return [];
  }
  return Object.entries(mocks).flatMap(([key, value]) => ["--preview-mock", `${key}=${String(value)}`]);
}

function optionalPreviewPlacementMockFlags(args) {
  const mocks = args?.previewPlacementMocks;
  if (!mocks || typeof mocks !== "object" || Array.isArray(mocks)) {
    return [];
  }
  return Object.entries(mocks).flatMap(([placementID, fields]) => {
    if (!fields || typeof fields !== "object" || Array.isArray(fields)) {
      return [];
    }
    return Object.entries(fields).flatMap(([key, value]) => [
      "--preview-placement-mock",
      `${placementID}:${key}=${String(value)}`
    ]);
  });
}

function optionalStringArg(args, key) {
  const value = args?.[key];
  if (typeof value !== "string" || value.length === 0) {
    return undefined;
  }
  return value;
}

function requiredArg(args, key) {
  const value = args?.[key];
  if (typeof value !== "string" || value.length === 0) {
    throw new Error(`Missing required argument: ${key}`);
  }
  return value;
}

function requiredStringArg(args, key) {
  const value = args?.[key];
  if (typeof value !== "string") {
    throw new Error(`Missing required argument: ${key}`);
  }
  return value;
}

function runOgkiln(args) {
  const result = spawnSync(ogkilnPath, args, {
    cwd: repoRoot,
    encoding: "utf8"
  });

  if (result.error) {
    throw result.error;
  }

  return {
    status: result.status ?? 1,
    stdout: result.stdout ?? "",
    stderr: result.stderr ?? ""
  };
}
