# OpenGraphite MCP Server

OpenGraphite MCP server exposes `.ogp`-scoped OpenGraphite resources and tools over stdio. Write tools call `Scripts/ogkiln`, so CLI and MCP operations share the same validation and diagnostics path. Node graph tools inspect unannotated, partially annotated, and fully annotated standard HTML without changing source; `adopt_node` is the explicit dry-run/diff/apply route for creating stable collaboration identity. Canvas annotation tools read `.ogp`-only sticky notes and ink without changing HTML or CSS. Project summary resources expose Chapter / Collection Guide counts through `guideCount`; individual Guide editing remains app-owned.

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
- `migrate_project`
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
- `adopt_node`
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

`list_nodes`, `query_nodes`, and `get_node` return annotation status, session/stable reference status, a source locator, and source-backed CSS layout/visibility resolution for ordinary DOM nodes. They do not force nodes into a single type: `capabilities` is a deterministic raw-value-sorted array of `drag-position`, `edit-control`, `edit-icon`, `edit-layout`, `edit-link`, `edit-media`, `edit-text`, `group`, `receive-children`, `reorder-flow`, and `ungroup`. `capabilityEvidence` contains the exact keys `isProjectResourceRoot`, `isNativeControl`, `isCustomElement`, `isLink`, `hasDirectText`, `hasElementChildren`, `hasMediaContent`, `hasSVGContent`, `hasMaskContent`, optional `ariaRole`, and optional `resolvedDisplay`. A pre-migration `0.1.0` classification may appear only as optional `legacyTypeHint`; the old node `type` field is absent. `query_nodes.capabilities` uses all-match semantics and maps to repeatable `--capability`; `query_nodes.type` is retained only as an exact compatibility-reader filter. OpenGraphite never generates a type annotation for new source or adoption.

`migrate_project` accepts `{ project, targetVersion?, proposalReference?, apply? }` and maps to `ogkiln migrate <project> [--target-version <version>] [--proposal <token>] [--apply] --json`. It migrates Web contract `0.1.0` to `1.0.0`; the `.ogp` schema version and Agent JSON `schemaVersion` stay unchanged. Calls default to dry-run and return `schemaVersion`, `sourceContractVersion`, `targetContractVersion`, `dryRun`, `applied`, `changed`, `proposalReference`, `diffs`, and `diagnostics`. Apply requires the proposal from a prior dry-run with the same target and fixed options (`legacyCatalogVersion: "1"`, `preserveUnknownDataAttributes: true`). The proposal binds the manifest, project CSS library, registered HTML, existing companion CSS, project-local actual linked styles/executable scripts, and recursive local `@import` resources by canonical relative path and raw-byte SHA-256, including a UTF-8 BOM. Source kind comes from character-reference-decoded HTML attributes, never the URL extension: `<style>` accepts omitted/exact-empty/ASCII-case-insensitive exact `text/css` type, a stylesheet `<link>` accepts omitted type or an HTTP-whitespace-trimmed MIME essence of `text/css` but rejects present-empty type, and `<script>` accepts exact-empty/ASCII-case-insensitive exact `module`/an exact JavaScript MIME type with `type` overriding obsolete `language`. Style/script whitespace or parameters and JSON/import-map/data-block scripts stay opaque. HTML/CSS whitespace is TAB/LF/FF/CR/SPACE, HTTP whitespace excludes FF, and NBSP/vertical-tab stay value characters. HTML non-void `/>` does not close its element, SVG/MathML self-closing does, and decimal/hex numeric references decode even without a semicolon. Extensionless resources and imports from actual embedded CSS remain in the closure; unrelated raw entities, CRLF, and BOM stay lossless. A project-local `OpenGraphite.contract.json` remains byte-for-byte tool configuration: it is neither a proposal target nor a diff/apply candidate, and `sourceContractVersion` is derived from legacy tokens in registered sources instead of that file's version.

Catalog v1 maps legacy type/layout/icon-mask to `.og-migrated-v1-*`, hidden/variant/part to standard attributes, known design custom properties to `--migrated-v1-*`, and only `codeViewerMode=preview` / `placementMode=collapsed` placement mocks to `host.variant`. It does not write preview state to source HTML. Project CSS, executable inline/linked JavaScript, and inline event handlers that read legacy input or observe a class, standard attribute, or custom property actually generated by migration are blocking. Dot/bracket/alias/destructuring and borrowed `call`/`apply` attribute access share one semantic classifier, but an exact name intersects only a destination actually generated; only dynamic names become whole-attribute evidence. Whole `dataset`/`style` evidence intersects actual removed attributes, inline-style changes, or generated custom properties. Whole-attribute/dynamic-DOM/AttributeNode evidence intersects HTML attribute changes; whole-markup evidence intersects any HTML source change including embedded CSS. External CSS changes intersect CSSOM observers, while embedded CSS changes intersect CSSOM or actual style-text observers. ID-based style/link evidence is scoped to actual CSS owners in HTML that refers to the runtime. Preview-manifest changes intersect global-preview-context `placementMocks`/whole-context alias chains or an exact/static-concatenated newly generated `host.*` field; fields/document-only access and unrelated same-named properties stay safe. Clean observers and unrelated mutations do not block. An already-present semantically equal standard destination is not generated evidence: its authored case, quoting, character references, and surrounding raw bytes are preserved while only the legacy token is removed. Ambiguous component master/slot/source placement state, unsafe roles, unknown reserved CSS, and destination conflicts are also blocking no-write results. Only a project with legacy input in registered sources is also blocked by unresolved imports, module dependency closure, external dependencies, runtime legacy readers, a missing/outside-root/unreadable discovered dependency, or the same canonical URL being classified as both CSS and runtime (`migration-resource-kind-conflict`); a clean standard project is an unchanged no-op. Load/import/module failures use `migration-project-load-failed`, `unsupported-legacy-import-reference`, and `unsupported-legacy-runtime-dependency`; blocking dry-runs return no partial proposal or diffs and surface as `isError: true`. Immediately before each candidate commit, apply revalidates raw bytes, existence, and canonical path resolution for the full proposal closure; staleness rolls back earlier commits and returns `stale-migration-proposal`. Rollback uses compare-and-swap against migration output bytes/mode, preserving a post-commit external edit and returning `migration-rollback-failed` instead of overwriting it. The server never performs its own partial retry.

`set_node_attribute` and `remove_node_attribute` accept contract-editable standard HTML attributes and retained OpenGraphite metadata only when the selected DOM tag/content model and operation capabilities support the target. A set with an empty string preserves a present empty attribute; only the explicit remove tool deletes the token. Contract-disallowed names return `disallowed-attribute`, and a semantic target mismatch returns `unsupported-node-capability`, both without writing.

Project, companion, readable local linked, and embedded stylesheets remain separate ASTs; linked/embedded sources follow document order, an unlinked project library is the first fallback, and an unlinked companion is the last. Existing inline styles remain HTML sources. Each trace candidate identifies `sourceID`, `sourceKind`, `sourceEditable`, `stylesheetOrder`, source-local `sourceOrder`, and `inherited`. Their optional `activeMediaQueries` string array is forwarded as repeatable `--active-media` conditions for `<link media>`, `<style media>`, and nested `@media`; omitted conditions are not guessed active. `layout` is derived from resolved `display` / `flex-direction` and UA defaults, while `hidden` reports the standard HTML source attribute separately from CSS `display` / `visibility`. App-only WebKit computed `content-visibility` and rendered-hidden state are not authored CLI values. Missing OpenGraphite annotation is valid and inspection never adopts it. `adopt_node` accepts exactly one inspected `reference`, `selector`, or `domPath` for dry-run and returns a unified source diff plus an apply-only proposal `targetReference`, even when the input node already has stable identity. The proposal pins the target source range/content hash, whole-document hash, and normalized `scope` / `displayID`. `apply:true` requires that returned reference with the same proposal parameters; ordinary graph session references, stale source, and changed parameters are rejected before writing.

Component masters are registered component resources whose hyphenated Custom Element host owns a direct standard `template`. Pages keep lightweight `<og-instance data-og-component="…">` references and assign light-DOM children through native named/default `slot` attributes. `OpenGraphite.runtime.js` clones the template into open Shadow DOM, while `build_project` emits the same tree as Declarative Shadow DOM. Both routes preserve slot fallback/order, host `variant`, `part`, nested components, and deterministic expansion without generating legacy component display attributes.

Placement-local preview state is written only by `place_project_component.previewPlacementMocks` to the component canvas `.ogp` `previewContext.placementMocks`. Use generic `host.<attribute>` fields such as `host.variant` / `host.aria-busy`, or `host.class` to add class tokens. Runtime resolution prefers the placement internal-ID entry, falls back to its display-ID entry when absent, and never merges both. The project runtime, App Canvas, and screenshot renderer temporarily project these values onto the generated clone's standard host attributes, classes, and ARIA so authored `:host(...)` CSS determines computed state. `data-og-*`, `on*`, `id`, `style`, `slot`, and `part` are protected from injection; source HTML and static builds remain unchanged.

Custom properties are resolved only after candidates from all stylesheet identities and inherited parent values are combined. A supported shorthand containing `var()` keeps its raw `authoredProperty` and value in the trace, then expands semantic longhand components after final substitution; an invalid expansion is node/property incomplete and read-only. CSS-wide identifier escapes are decoded only for semantics. `revert` / `revert-layer` retain the parent computed value for inherited properties, delegate non-inherited values to the HTML UA fallback, and remain node-level incomplete. The shared validator checks supported keyword, geometry, numeric/math, and grid-track grammars while keeping number, percentage, length, and length-percentage result types distinct. Invalid or unsupported authored values stay lossless, do not establish a resolved winner, and make that node/property incomplete. Syntactically valid `env()`, `anchor()`, and `anchor-size()` values also stay authored but remain headlessly unresolved and incomplete. An explicit invalid value, a top-level `;` that reaches another declaration, or top-level `!important` injection returns `invalid-css-property-value` with atomic no-write; an environment-dependent set is instead blocked as incomplete provenance when its postcondition cannot be resolved safely. For `hidden="until-found"`, authored `content-visibility:initial`, `unset`, or `visible` resolves to `visible` instead of the headless `hidden` fallback, without changing the `hidden` source intent.

Pass the same `activeMediaQueries` to `set_css_variable` or `remove_css_variable` after reviewing a responsive winner. MCP maps each condition to repeatable `--active-media`, so the shared Core keeps the winning media scope. Unreadable/external stylesheets, unresolved `@import`, malformed CSS, unsupported selectors, and source-wide unsupported layer/property rules set page/node `hasIncompleteCSSProvenance` with `incomplete-css-provenance`; inspection continues, but every CSS mutation returns `incomplete-css-provenance-write-blocked` without writing. A matching unevaluated conditional, an active-animation node in a graph containing keyframes, or a node with a headless-unresolved CSS-wide value is guarded only at that node/target; keyframes alone do not make a source incomplete. Such a write also reports `incomplete-css-node-provenance`; the page aggregate flag does not make unrelated complete nodes read-only.

Node style tools include project CSS in cascade resolution but never mutate the project's `cssLibrary`. A read-only project/linked/embedded winner can be set only through a safe node-scoped companion override with matching media scope and priority; an unsafe specificity override returns `css-specificity-override-unsafe`. Removing a winner that exists only in a read-only source returns `read-only-css-winner`; removing a longhand resolved from a shorthand returns `shorthand-css-removal-unsupported`; a failed winner postcondition returns `css-mutation-postcondition-failed`. Only the project-level design-token tools mutate the CSS library.

All other node mutation tools require a stable `data-og-internal-id` or typed `ogref`. A session reference must be explicitly adopted before it is used for style, attribute, icon, text, subtree, delete, move, or copy writes.

Tool details and argument contracts are documented in
[`Docs/specs/OpenGraphiteMCP.md`](../../Docs/specs/OpenGraphiteMCP.md). The annotation schema and Sidecar contract are defined in [`Docs/specs/CanvasAnnotations.md`](../../Docs/specs/CanvasAnnotations.md).
