# OpenGraphite Architecture

OpenGraphite treats HTML as the editable source of truth for web structure. The `.ogp` file stores project management data, page references, canvas placement, and editor-only Chapter/Collection annotations, while each `public/*.html` file remains a standalone browser-renderable artifact.

## Responsibilities

- Tag names express semantic component names.
- `data-og-*` attributes store editor-facing structure and roles.
- Companion CSS stores design values such as spacing, radius, size, and colors as standard CSS properties.
- `CSS/OpenGraphite.css` interprets `data-og-*`, editable CSS declarations, and reserved helper custom properties in both the app canvas and the browser.
- `.ogp` `chapters[].annotations[]` / `collections[].annotations[]` store sticky notes and ink in canonical canvas world coordinates; they never become DOM or CSS.

## Runtime Flow

1. `OpenGraphite.app` opens an `.ogp` file.
2. The selected page resolves to `repositoryRoot/htmlRoot/path`.
3. `WKWebView` loads the HTML file directly from disk.
4. A small bridge script enumerates `[data-og-id]` nodes and sends them to SwiftUI.
5. Layers select nodes by `data-og-id`.
6. Inspector CSS edits update the DOM and serialize companion CSS changes back to the same-named CSS file.
7. SwiftUI/AppKit renders `.ogp` annotations in a front layer above the WebView cards and saves annotation edits only to the selected Chapter or Collection.

The editor does not generate a separate export copy. The opened HTML is the file that changes for web edits; annotation edits change only the `.ogp`. Canvas screenshots composite annotations for multimodal review, while standalone HTML, CSS, browser runtime, and build output remain annotation-free. See [`specs/CanvasAnnotations.md`](specs/CanvasAnnotations.md).
