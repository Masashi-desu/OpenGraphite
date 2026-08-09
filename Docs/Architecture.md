# OpenGraphite Architecture

OpenGraphite treats HTML as the editable source of truth for web structure. The `.ogp` file stores project management data, page references, canvas placement, editor-only Chapter/Collection annotations, and canvas guides, while each `public/*.html` file remains a standalone browser-renderable artifact.

## Responsibilities

- Tag names express semantic component names.
- Optional `data-og-id` / `data-og-internal-id` store collaboration identity only when a stable cross-session reference is needed. Other retained `data-og-*` values are limited to reference, binding, policy, or provenance that standard DOM/CSS cannot reconstruct.
- Companion CSS stores design values such as spacing, radius, size, and colors as standard CSS properties. A page theme uses root `background` / `color`; shared values may use project-defined generic custom properties whose names and meanings OpenGraphite does not reserve. Locale typography uses root `font-family`, same-scope `:lang(<BCP47>)` rules, inheritance, and normal element overrides.
- Media and icon wrappers carry frame edits and optional provenance; rendered values live on the actual `img` / `video` / SVG / mask child as standard `object-fit`, `stroke-width`, and mask properties.
- Persistent flips and transforms are authored as independent standard `scale`, `rotate`, `transform`, and `transform-origin` declarations. Horizontal and vertical flips use `scale: -1 1` and `scale: 1 -1`, respectively.
- `CSS/OpenGraphite.css` provides only the distributed, source-facing rendering rules shared by the app canvas and the browser. Editor interaction state is independent of that stylesheet.
- `.ogp` `chapters[].annotations[]` / `collections[].annotations[]` store sticky notes and ink in canonical canvas world coordinates; they never become DOM or CSS.
- `.ogp` `chapters[].guides[]` / `collections[].guides[]` store canvas Guide direction and canonical world position; they never become DOM, CSS, screenshot, or build data.
- OpenGraphite.app `UserDefaults` stores only local Ruler / Guide / Grid visibility.

## Runtime Flow

1. `OpenGraphite.app` opens an `.ogp` file.
2. The selected page resolves to `repositoryRoot/htmlRoot/path`.
3. `WKWebView` loads the HTML file directly from disk.
4. A small bridge script enumerates the normal DOM, including nodes with no OpenGraphite annotation, and sends semantic labels, source locators, annotation status, and reference stability to SwiftUI.
5. Layers select annotated nodes by stable identity and unannotated nodes by a session-scoped locator. Existing standard `id` and safe authored selectors are preferred over adding attributes.
6. Inspector CSS edits follow authored selector provenance. A stable AI mutation target is created only through explicit adoption with a dry-run and source diff.
7. SwiftUI/AppKit renders `.ogp` annotations in a front layer above the WebView cards and saves annotation edits only to the selected Chapter or Collection.
8. SwiftUI/AppKit renders the local Grid behind WebView cards and Ruler / `.ogp` Guide overlays above the canvas, resolving all three from the same scroll / zoom world-coordinate transform.

Focus is separate from the Normal / Flow canvas modes. A right-click snapshots one HTML object, or targets an entire page card from its native context menu, and replaces the canvas area with a centered, finite scrolling preview; right-clicking that preview exposes the exit action. Focus and the normal canvas share one zoom input resolver for pointer-anchored `Command + scroll`, trackpad pinch, and compatible gesture events, where 100% is the target's original CSS-pixel size. During continuous zoom, Focus retains its current finite document extent to avoid repeatedly clamping the scroll origin, then contracts once to the exact overflow range when input settles. It does not create another source representation: object isolation is held in a runtime-private JavaScript object / `WeakMap` and native overlay state, while whole-page Focus renders the page canvas directly.

Selection, direct editing, drag, reorder, frame preview, and runtime expansion provenance are also session state rather than DOM source. The editor uses native overlays, `:focus`, `contenteditable`, runtime-private object references, individual `translate`, and the Web Animations API as appropriate. Drag and reorder never compose through or overwrite project-authored `scale`, `rotate`, `transform`, or `transform-origin`. These mechanisms do not depend on `OpenGraphite.css`, and their state is never serialized to authored HTML, companion CSS, or static build output.

Locale preview changes only the preview clone's standard `lang` / `dir`. WebKit computed `font-family` is the rendered observation; the authored default or `:lang(...)` declaration and its selector provenance remain the CSS write-back source.

Opening, previewing, inspecting, validating, building, or saving without edits never adds `data-og-id`, `data-og-internal-id`, or `data-og-type`. Missing annotation is valid; duplicate identity that actually exists and broken persisted references remain diagnostics. Explicit adoption revalidates the inspected source range and content hash before applying its proposed optional identity, so a stale session reference cannot silently target changed HTML.

The editor does not generate a separate export copy. The opened HTML is the file that changes for web edits; annotation and Guide edits change only the `.ogp`. Canvas screenshots composite annotations for multimodal review but omit Ruler, Guide, and Grid. Standalone HTML, CSS, browser runtime, and build output remain annotation- and canvas-aid-free. See [`specs/CanvasAnnotations.md`](specs/CanvasAnnotations.md) and [`specs/CanvasAids.md`](specs/CanvasAids.md).
