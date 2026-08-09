import assert from "node:assert/strict";
import test from "node:test";

import { commandForTool, toolsList } from "./server.mjs";

test("project migration defaults to dry-run and apply requires its proposal", () => {
  const tool = new Map(toolsList().map((item) => [item.name, item])).get("migrate_project");
  assert.ok(tool, "migrate_project must be listed");
  assert.deepEqual(tool.inputSchema.required, ["project"]);
  assert.equal(tool.inputSchema.properties.apply.type, "boolean");
  assert.deepEqual(
    commandForTool("migrate_project", { project: "Example.ogp" }),
    ["migrate", "Example.ogp", "--json"]
  );
  assert.deepEqual(
    commandForTool("migrate_project", {
      project: "Example.ogp",
      targetVersion: "1.0.0",
      proposalReference: "ogref-session:migration:abc",
      apply: true
    }),
    [
      "migrate", "Example.ogp",
      "--target-version", "1.0.0",
      "--proposal", "ogref-session:migration:abc",
      "--apply", "--json"
    ]
  );
  assert.deepEqual(
    commandForTool("migrate_project", { project: "Example.ogp", apply: true }),
    ["migrate", "Example.ogp", "--apply", "--json"]
  );
});

test("locale typography tools expose page/component target schemas", () => {
  const tools = new Map(toolsList().map((tool) => [tool.name, tool]));

  for (const name of [
    "list_locale_typography",
    "set_locale_typography",
    "remove_locale_typography"
  ]) {
    const tool = tools.get(name);
    assert.ok(tool, `${name} must be listed`);
    assert.deepEqual(tool.inputSchema.oneOf, [
      { required: ["pageID"] },
      { required: ["componentID"] }
    ]);
  }
  assert.deepEqual(
    tools.get("set_locale_typography").inputSchema.required,
    ["projectPath", "value"]
  );
});

test("locale typography tools delegate to the matching ogkiln commands", () => {
  assert.deepEqual(
    commandForTool("list_locale_typography", {
      projectPath: "Example.ogp",
      pageID: "home"
    }),
    ["locale-typography", "list", "Example.ogp", "--page-id", "home", "--json"]
  );
  assert.deepEqual(
    commandForTool("set_locale_typography", {
      projectPath: "Example.ogp",
      componentID: "card",
      locale: "fr-CA",
      value: "Marianne, sans-serif"
    }),
    [
      "locale-typography", "set", "Example.ogp",
      "--component-id", "card",
      "--locale", "fr-CA",
      "--value", "Marianne, sans-serif",
      "--json"
    ]
  );
  assert.deepEqual(
    commandForTool("remove_locale_typography", {
      projectPath: "Example.ogp",
      pageID: "home"
    }),
    ["locale-typography", "remove", "Example.ogp", "--page-id", "home", "--json"]
  );
  assert.throws(
    () => commandForTool("list_locale_typography", { projectPath: "Example.ogp" }),
    /pageID or componentID/
  );
});

test("standard rendering properties keep MCP and ogkiln style parity", () => {
  const tools = new Map(toolsList().map((tool) => [tool.name, tool]));
  const setStyle = tools.get("set_css_variable");
  const removeStyle = tools.get("remove_css_variable");

  assert.ok(setStyle, "set_css_variable must remain available for standard CSS properties");
  assert.ok(removeStyle, "remove_css_variable must remain available for standard CSS properties");
  assert.deepEqual(
    commandForTool("set_css_variable", {
      projectPath: "Example.ogp",
      pageID: "home",
      id: "media-wrapper",
      variable: "object-fit",
      value: "cover"
    }),
    [
      "node", "style", "set", "Example.ogp",
      "--page-id", "home",
      "--id", "media-wrapper",
      "--var", "object-fit",
      "--value", "cover"
    ]
  );
  assert.deepEqual(
    commandForTool("remove_css_variable", {
      projectPath: "Example.ogp",
      componentID: "icon-card",
      id: "icon-wrapper",
      variable: "stroke-width"
    }),
    [
      "node", "style", "remove", "Example.ogp",
      "--component-id", "icon-card",
      "--id", "icon-wrapper",
      "--var", "stroke-width"
    ]
  );
  assert.deepEqual(
    commandForTool("set_css_variable", {
      projectPath: "Example.ogp",
      pageID: "home",
      id: "flip-card",
      variable: "scale",
      value: "-1 1"
    }),
    [
      "node", "style", "set", "Example.ogp",
      "--page-id", "home",
      "--id", "flip-card",
      "--var", "scale",
      "--value", "-1 1"
    ]
  );
  assert.deepEqual(
    commandForTool("remove_css_variable", {
      projectPath: "Example.ogp",
      componentID: "card",
      id: "flip-card",
      variable: "scale"
    }),
    [
      "node", "style", "remove", "Example.ogp",
      "--component-id", "card",
      "--id", "flip-card",
      "--var", "scale"
    ]
  );
});

test("standard layout inspection and active media keep MCP and ogkiln parity", () => {
  const tools = new Map(toolsList().map((tool) => [tool.name, tool]));

  for (const name of [
    "list_nodes",
    "query_nodes",
    "get_node",
    "set_css_variable",
    "remove_css_variable"
  ]) {
    const property = tools.get(name)?.inputSchema?.properties?.activeMediaQueries;
    assert.equal(property?.type, "array", `${name} must accept active media conditions`);
    assert.equal(property?.items?.type, "string");
  }
  assert.match(tools.get("list_nodes").description, /standard CSS-derived layout/i);
  assert.match(tools.get("set_node_attribute").description, /standard HTML/i);
  assert.match(tools.get("remove_node_attribute").description, /standard HTML/i);

  assert.deepEqual(
    commandForTool("list_nodes", {
      projectPath: "Example.ogp",
      pageID: "home",
      activeMediaQueries: ["(max-width: 720px)", "(prefers-reduced-motion: reduce)"]
    }),
    [
      "page", "graph", "Example.ogp",
      "--page-id", "home",
      "--active-media", "(max-width: 720px)",
      "--active-media", "(prefers-reduced-motion: reduce)",
      "--json"
    ]
  );
  assert.deepEqual(
    commandForTool("set_css_variable", {
      projectPath: "Example.ogp",
      componentID: "card",
      id: "panel",
      variable: "flex-direction",
      value: "row",
      activeMediaQueries: ["(max-width: 720px)"]
    }),
    [
      "node", "style", "set", "Example.ogp",
      "--component-id", "card",
      "--id", "panel",
      "--var", "flex-direction",
      "--value", "row",
      "--active-media", "(max-width: 720px)"
    ]
  );
  assert.deepEqual(
    commandForTool("remove_css_variable", {
      projectPath: "Example.ogp",
      pageID: "home",
      id: "panel",
      variable: "flex-direction",
      activeMediaQueries: ["(max-width: 720px)"]
    }),
    [
      "node", "style", "remove", "Example.ogp",
      "--page-id", "home",
      "--id", "panel",
      "--var", "flex-direction",
      "--active-media", "(max-width: 720px)"
    ]
  );
});

test("capability queries keep MCP and ogkiln parity while type stays a legacy hint", () => {
  const tools = new Map(toolsList().map((tool) => [tool.name, tool]));
  const query = tools.get("query_nodes");

  assert.equal(query.inputSchema.properties.capabilities.type, "array");
  assert.deepEqual(query.inputSchema.properties.capabilities.items.enum, [
    "drag-position", "edit-control", "edit-icon", "edit-layout", "edit-link",
    "edit-media", "edit-text", "group", "receive-children", "reorder-flow", "ungroup"
  ]);
  assert.match(query.inputSchema.properties.type.description, /legacy data-og-type hint/i);
  assert.match(query.inputSchema.properties.type.description, /does not grant/i);
  assert.deepEqual(
    commandForTool("query_nodes", {
      projectPath: "Example.ogp",
      componentID: "card",
      type: "frame",
      capabilities: ["edit-layout", "receive-children"]
    }),
    [
      "node", "query", "Example.ogp",
      "--component-id", "card",
      "--type", "frame",
      "--capability", "edit-layout",
      "--capability", "receive-children",
      "--json"
    ]
  );
});

test("attribute set preserves empty values while remove stays an explicit command", () => {
  const tools = new Map(toolsList().map((tool) => [tool.name, tool]));
  assert.match(tools.get("set_node_attribute").description, /empty strings remain present/i);
  assert.match(tools.get("set_node_attribute").description, /capability-compatible/i);
  assert.match(tools.get("remove_node_attribute").description, /distinct from setting an empty string/i);
  assert.match(tools.get("set_icon").description, /existing OpenGraphite icon metadata/i);
  assert.deepEqual(
    commandForTool("set_node_attribute", {
      projectPath: "Example.ogp", pageID: "home", id: "image", name: "alt", value: ""
    }),
    [
      "node", "attr", "set", "Example.ogp", "--page-id", "home",
      "--id", "image", "--name", "alt", "--value", ""
    ]
  );
  assert.deepEqual(
    commandForTool("remove_node_attribute", {
      projectPath: "Example.ogp", pageID: "home", id: "image", name: "alt"
    }),
    [
      "node", "attr", "remove", "Example.ogp", "--page-id", "home",
      "--id", "image", "--name", "alt"
    ]
  );
});

test("component preview placement mocks map generic host fields and empty values", () => {
  const tools = new Map(toolsList().map((tool) => [tool.name, tool]));
  const placeComponent = tools.get("place_project_component");

  assert.ok(placeComponent, "place_project_component must be listed");
  assert.deepEqual(
    placeComponent.inputSchema.properties.previewPlacementMocks,
    {
      type: "object",
      additionalProperties: {
        type: "object",
        additionalProperties: { type: "string" }
      }
    }
  );
  assert.deepEqual(
    commandForTool("place_project_component", {
      projectPath: "Example.ogp",
      componentID: "component-internal",
      previewPlacementMocks: {
        "code-placement-internal": { "host.variant": "code" },
        "preview-placement-internal": { "host.variant": "preview", "host.class": "" },
        "loading-placement-internal": {
          "host.class": "is-loading",
          "host.aria-busy": "true"
        },
        "collapsed-placement-internal": { "host.variant": "collapsed" }
      }
    }),
    [
      "project", "component", "place", "Example.ogp",
      "--component-id", "component-internal",
      "--preview-placement-mock", "code-placement-internal:host.variant=code",
      "--preview-placement-mock", "preview-placement-internal:host.variant=preview",
      "--preview-placement-mock", "preview-placement-internal:host.class=",
      "--preview-placement-mock", "loading-placement-internal:host.class=is-loading",
      "--preview-placement-mock", "loading-placement-internal:host.aria-busy=true",
      "--preview-placement-mock", "collapsed-placement-internal:host.variant=collapsed"
    ]
  );
});

test("progressive adoption tool exposes one resource selector and one inspected locator", () => {
  const tools = new Map(toolsList().map((tool) => [tool.name, tool]));
  const adopt = tools.get("adopt_node");

  assert.ok(adopt, "adopt_node must be listed");
  assert.deepEqual(adopt.inputSchema.required, ["projectPath"]);
  assert.deepEqual(adopt.inputSchema.allOf, [
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
  ]);
  assert.deepEqual(adopt.inputSchema.properties.scope.enum, ["node", "subtree"]);
  assert.equal(adopt.inputSchema.properties.apply.type, "boolean");
  assert.match(adopt.description, /targetReference/);
  assert.match(adopt.inputSchema.properties.selector.description, /dry-run only/i);
  assert.match(adopt.inputSchema.properties.domPath.description, /dry-run only/i);

  for (const name of [
    "set_css_variable",
    "remove_css_variable",
    "set_node_attribute",
    "remove_node_attribute",
    "set_icon",
    "insert_icon",
    "set_text_content",
    "insert_html",
    "replace_node_html",
    "delete_node",
    "move_node",
    "copy_node"
  ]) {
    const mutation = tools.get(name);
    assert.ok(mutation, `${name} must be listed`);
    assert.match(mutation.description, /stable/i);
    assert.match(mutation.description, /data-og-internal-id/i);
    assert.match(mutation.description, /typed ogref/i);
    assert.match(mutation.description, /session/i);
    assert.match(mutation.description, /adopt/i);
  }
});

test("progressive adoption delegates dry-run and explicit apply to the shared CLI route", () => {
  assert.deepEqual(
    commandForTool("adopt_node", {
      projectPath: "Example.ogp",
      pageID: "home",
      reference: "ogref-session:node:document:path:content",
      scope: "subtree",
      displayID: "hero"
    }),
    [
      "node", "adopt", "Example.ogp",
      "--page-id", "home",
      "--reference", "ogref-session:node:document:path:content",
      "--scope", "subtree",
      "--display-id", "hero",
      "--json"
    ]
  );
  assert.deepEqual(
    commandForTool("adopt_node", {
      projectPath: "Example.ogp",
      componentID: "card",
      reference: "ogref-session:adoption:document:path:content:proposal",
      apply: true
    }),
    [
      "node", "adopt", "Example.ogp",
      "--component-id", "card",
      "--reference", "ogref-session:adoption:document:path:content:proposal",
      "--apply",
      "--json"
    ]
  );
  assert.throws(
    () => commandForTool("adopt_node", {
      projectPath: "Example.ogp",
      pageID: "home"
    }),
    /exactly one adoption locator/
  );
  assert.throws(
    () => commandForTool("adopt_node", {
      projectPath: "Example.ogp",
      pageID: "home",
      selector: "#hero",
      domPath: "html/body/main"
    }),
    /exactly one adoption locator/
  );
  assert.throws(
    () => commandForTool("adopt_node", {
      projectPath: "Example.ogp",
      pageID: "home",
      selector: "#hero",
      apply: true
    }),
    /targetReference returned by dry-run/
  );
});
