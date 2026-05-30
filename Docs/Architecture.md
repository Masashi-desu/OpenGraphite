# OpenGraphite Architecture

OpenGraphite treats HTML as the editable source of truth. The `.ogp` file stores project management data, page references, and canvas placement, while each `public/*.html` file remains a standalone browser-renderable artifact.

## Responsibilities

- Tag names express semantic component names.
- `data-og-*` attributes store editor-facing structure and roles.
- CSS variables store design values such as spacing, radius, size, and colors.
- `CSS/OpenGraphite.css` interprets `data-og-*` and `--og-*` values in both the app canvas and the browser.

## Runtime Flow

1. `OpenGraphite.app` opens an `.ogp` file.
2. The selected page resolves to `repositoryRoot/htmlRoot/path`.
3. `WKWebView` loads the HTML file directly from disk.
4. A small bridge script enumerates `[data-og-id]` nodes and sends them to SwiftUI.
5. Layers select nodes by `data-og-id`.
6. Inspector CSS variable edits update the DOM and serialize the HTML back to the same file.

The editor does not generate a separate export copy. The opened HTML is the file that changes.
