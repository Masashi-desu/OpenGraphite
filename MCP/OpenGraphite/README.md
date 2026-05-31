# OpenGraphite MCP Server

OpenGraphite MCP server exposes `.ogp`-scoped OpenGraphite resources and tools over stdio. Write tools call `Scripts/ogkiln`, so CLI and MCP operations share the same validation and diagnostics path.

## Run

```bash
node MCP/OpenGraphite/server.mjs
```

## Resources

- `opengraphite://contract/css`
- `opengraphite://project/sample`
- `opengraphite://project/current`
- `opengraphite://pages/sample`
- `opengraphite://pages/current`
- `opengraphite://pages/sample/home/graph`
- `opengraphite://pages/sample/home/html`

## Tools

- `get_contract`
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

Tool details and argument contracts are documented in
[`Docs/specs/OpenGraphiteMCP.md`](../../Docs/specs/OpenGraphiteMCP.md).
