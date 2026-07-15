# OpenGraphite MCP Server

OpenGraphite MCP server exposes `.ogp`-scoped OpenGraphite resources and tools over stdio. Write tools call `Scripts/ogkiln`, so CLI and MCP operations share the same validation and diagnostics path. Canvas annotation tools read `.ogp`-only sticky notes and ink without changing HTML or CSS. Project summary resources expose Chapter / Collection Guide counts through `guideCount`; individual Guide editing remains app-owned.

## Run

```bash
node MCP/OpenGraphite/server.mjs
```

## Resources

- `opengraphite://contract/css`
- `opengraphite://project/sample`
- `opengraphite://project/current`
- `opengraphite://design-tokens/sample`
- `opengraphite://design-tokens/current`
- `opengraphite://pages/sample`
- `opengraphite://pages/current`
- `opengraphite://pages/sample/home/graph`
- `opengraphite://pages/sample/home/html`

## Tools

- `get_contract`
- `list_canvas_annotations`
- `get_canvas_annotation`
- `list_design_tokens`
- `set_design_token`
- `remove_design_token`
- `add_project_page`
- `create_project_page`
- `place_project_page`
- `validate`
- `list_nodes`
- `screenshot_canvas`
- `screenshot_page`
- `screenshot_node`
- `query_nodes`
- `get_node`
- `set_css_variable`
- `remove_css_variable`
- `set_node_attribute`
- `remove_node_attribute`
- `set_text_content`
- `insert_html`
- `replace_node_html`
- `delete_node`
- `move_node`
- `copy_node`

`list_canvas_annotations` requires exactly one Chapter or Collection selector. `get_canvas_annotation` accepts a raw annotation ID plus its selector, or a self-contained `ogref:annotation:<pages|components>:<containerInternalID>:<annotationInternalID>`. `screenshot_canvas` accepts mutually exclusive optional `chapterID` / `collectionID` selectors, defaults to the first Chapter, and composites that container's annotations in front of its WebKit card snapshots.

Tool details and argument contracts are documented in
[`Docs/specs/OpenGraphiteMCP.md`](../../Docs/specs/OpenGraphiteMCP.md). The annotation schema and Sidecar contract are defined in [`Docs/specs/CanvasAnnotations.md`](../../Docs/specs/CanvasAnnotations.md).
