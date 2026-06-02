#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const serverDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(serverDir, "..", "..");
const ogkilnPath = join(repoRoot, "Scripts", "ogkiln");

let inputBuffer = Buffer.alloc(0);

process.stdin.on("data", (chunk) => {
  inputBuffer = Buffer.concat([inputBuffer, chunk]);
  readMessages();
});

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
      description: "Machine-readable data-og-* and --og-* contract.",
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
      description: "Sample project component canvases as resolved by ogkiln.",
      mimeType: "application/json"
    },
    {
      uri: "opengraphite://components/current",
      name: "Current App Project Components",
      description: "Component canvases from the project currently opened by OpenGraphite.app.",
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
      return textResource(uri, "application/json", JSON.stringify(project.components, null, 2));
    }
    case "opengraphite://components/current": {
      const project = JSON.parse(runOgkiln(["project", "current", "--json"]).stdout);
      return textResource(uri, "application/json", JSON.stringify(project.components, null, 2));
    }
    case "opengraphite://pages/sample/home/graph":
      return textResource(uri, "application/json", runOgkiln(["page", "graph", "SampleProject/OpenGraphiteSample.ogp", "--page-id", "home", "--json"]).stdout);
    case "opengraphite://pages/sample/home/html":
      return textResource(uri, "text/html", readFileSync(join(repoRoot, "public", "index.html"), "utf8"));
    case "opengraphite://components/sample/design-system/graph":
      return textResource(uri, "application/json", runOgkiln(["page", "graph", "SampleProject/OpenGraphiteSample.ogp", "--component-id", "design-system", "--json"]).stdout);
    case "opengraphite://components/sample/design-system/html":
      return textResource(uri, "text/html", readFileSync(join(repoRoot, "public", "_components", "design-system.html"), "utf8"));
    default:
      throw new Error(`Unknown resource: ${uri}`);
  }
}

function textResource(uri, mimeType, text) {
  return { uri, mimeType, text };
}

function toolsList() {
  return [
    {
      name: "validate",
      description: "Validate an OpenGraphite .ogp project. projectPath may be an .ogp path or 'current'.",
      inputSchema: objectSchema({
        projectPath: { type: "string", description: ".ogp path, relative to the repository root or absolute, or 'current'." }
      }, ["projectPath"])
    },
    {
      name: "get_contract",
      description: "Return the active OpenGraphite contract used by ogkiln.",
      inputSchema: objectSchema({}, [])
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
        height: { type: "number" }
      }, ["projectPath", "pageID"])
    },
    {
      name: "add_project_component",
      description: "Add an existing HTML file to the Components segment of an OpenGraphite .ogp project.",
      inputSchema: objectSchema({
        projectPath: { type: "string", description: ".ogp path or 'current'." },
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
      description: "Create a new component canvas HTML file and register it in the Components segment.",
      inputSchema: objectSchema({
        projectPath: { type: "string", description: ".ogp path or 'current'." },
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
        height: { type: "number" }
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
      description: "Return the OpenGraphite graph for a page or component canvas registered in an .ogp project.",
      inputSchema: targetObjectSchema({
        projectPath: { type: "string", description: ".ogp path or 'current'." },
        ...pageSelectorProperties()
      }, ["projectPath"])
    },
    {
      name: "screenshot_canvas",
      description: "Render the default Chapter canvas in an OpenGraphite .ogp project to a PNG file.",
      inputSchema: objectSchema({
        projectPath: { type: "string", description: ".ogp path or 'current'." },
        outputPath: { type: "string" }
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
      description: "Filter OpenGraphite nodes in a project-registered page or component canvas by id, type, role, tag, or text content.",
      inputSchema: targetObjectSchema({
        projectPath: { type: "string", description: ".ogp path or 'current'." },
        ...pageSelectorProperties(),
        idContains: { type: "string" },
        type: { type: "string" },
        role: { type: "string" },
        tag: { type: "string" },
        textContains: { type: "string" }
      }, ["projectPath"])
    },
    {
      name: "get_node",
      description: "Return a single node by data-og-internal-id or ogref.",
      inputSchema: nodeTargetObjectSchema({
        projectPath: { type: "string", description: ".ogp path or 'current'." },
        ...pageSelectorProperties(),
        id: { type: "string" }
      }, ["projectPath", "id"])
    },
    {
      name: "set_css_variable",
      description: "Set a --og-* CSS variable on a node selected by data-og-internal-id or ogref.",
      inputSchema: nodeTargetObjectSchema({
        projectPath: { type: "string", description: ".ogp path or 'current'." },
        ...pageSelectorProperties(),
        id: { type: "string" },
        variable: { type: "string" },
        value: { type: "string" }
      }, ["projectPath", "id", "variable", "value"])
    },
    {
      name: "remove_css_variable",
      description: "Remove a --og-* CSS variable from a node selected by data-og-internal-id or ogref.",
      inputSchema: nodeTargetObjectSchema({
        projectPath: { type: "string", description: ".ogp path or 'current'." },
        ...pageSelectorProperties(),
        id: { type: "string" },
        variable: { type: "string" }
      }, ["projectPath", "id", "variable"])
    },
    {
      name: "set_node_attribute",
      description: "Set an editable data-og-* attribute on a node selected by data-og-internal-id or ogref.",
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
      description: "Remove an editable data-og-* attribute from a node selected by data-og-internal-id or ogref.",
      inputSchema: nodeTargetObjectSchema({
        projectPath: { type: "string", description: ".ogp path or 'current'." },
        ...pageSelectorProperties(),
        id: { type: "string" },
        name: { type: "string" }
      }, ["projectPath", "id", "name"])
    },
    {
      name: "set_text_content",
      description: "Replace a node's inner content with escaped plain text.",
      inputSchema: nodeTargetObjectSchema({
        projectPath: { type: "string", description: ".ogp path or 'current'." },
        ...pageSelectorProperties(),
        id: { type: "string" },
        text: { type: "string" }
      }, ["projectPath", "id", "text"])
    },
    {
      name: "insert_html",
      description: "Insert an HTML fragment before, after, prepend, or append relative to an anchor node.",
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
      description: "Replace a node subtree with an HTML fragment.",
      inputSchema: nodeTargetObjectSchema({
        projectPath: { type: "string", description: ".ogp path or 'current'." },
        ...pageSelectorProperties(),
        id: { type: "string" },
        html: { type: "string" }
      }, ["projectPath", "id", "html"])
    },
    {
      name: "delete_node",
      description: "Delete a node subtree selected by data-og-internal-id or ogref.",
      inputSchema: nodeTargetObjectSchema({
        projectPath: { type: "string", description: ".ogp path or 'current'." },
        ...pageSelectorProperties(),
        id: { type: "string" }
      }, ["projectPath", "id"])
    },
    {
      name: "move_node",
      description: "Move a node subtree before, after, prepend, or append relative to a target node.",
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
      description: "Copy a node subtree, prefix copied data-og-id values, and insert it relative to a target node.",
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

function commandForTool(name, args) {
  switch (name) {
    case "validate":
      return ["validate", requiredArg(args, "projectPath"), "--json"];
    case "get_contract":
      return ["contract", "get", "--json"];
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
        ...optionalValueFlag(args, "height", "--height")
      ];
    case "add_project_component":
      return [
        "project",
        "component",
        "add",
        requiredArg(args, "projectPath"),
        "--component-id",
        requiredArg(args, "componentID"),
        "--path",
        requiredArg(args, "path"),
        ...optionalValueFlag(args, "x", "--x"),
        ...optionalValueFlag(args, "y", "--y"),
        ...optionalValueFlag(args, "width", "--width"),
        ...optionalValueFlag(args, "height", "--height")
      ];
    case "create_project_component":
      return [
        "project",
        "component",
        "create",
        requiredArg(args, "projectPath"),
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
        ...optionalValueFlag(args, "height", "--height")
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
      return ["page", "graph", requiredArg(args, "projectPath"), ...pageSelectorArgs(args), "--json"];
    case "screenshot_canvas":
      return [
        "screenshot",
        "canvas",
        requiredArg(args, "projectPath"),
        "--output",
        requiredArg(args, "outputPath")
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
        ...optionalFlag(args, "role", "--role"),
        ...optionalFlag(args, "tag", "--tag"),
        ...optionalFlag(args, "textContains", "--text-contains"),
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
        requiredArg(args, "value")
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
        requiredArg(args, "variable")
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
        requiredArg(args, "value")
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
    componentID: { type: "string", description: "Component canvas reference ID. Mutually exclusive with pageID." }
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
