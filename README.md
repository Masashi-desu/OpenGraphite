# OpenGraphite

OpenGraphite is a macOS SwiftUI design editor that treats HTML as the editable source of truth, not as an export artifact. Edits made in `OpenGraphite.app` are reflected directly in the opened HTML file, and that HTML can be used as the web deliverable.

## Artifacts

- `OpenGraphite.app`: macOS SwiftUI app generated from `project.yml`
- `CSS/OpenGraphite.css`: distributable CSS library for project design tokens and narrowly scoped OpenGraphite affordances
- `OpenGraphite.contract.json`: machine-readable Web contract `1.0.0`, optional annotation/adoption policy, operation `capabilityPolicy`, editable CSS declarations, and explicit `0.1.0` migration policy
- `public/OpenGraphite.runtime.js`: optional runtime that expands `<og-instance>` references into open Shadow DOM from registered Custom Element `<template>` masters
- `public/*.css`: companion CSS files that hold page-specific design values for same-named HTML files
- `Scripts/ogkiln`: CLI for repository-backed inspection, validation, and node-level HTML edits
- `MCP/OpenGraphite/server.mjs`: OpenGraphite MCP server backed by `ogkiln`
- `SampleProject/OpenGraphiteSample.ogp`: sample project file
- `public/index.html`: standalone OpenGraphite introduction page
- `project.yml`: XcodeGen source of truth
- `Docs/Architecture.md`: design notes
- `Docs/specs/DesignPhilosophy.md`: design philosophy and decision principles
- `Docs/specs/SourceOfTruthContract.md`: cross-cutting source-of-truth contract for `data-og-*`, editable CSS declarations, runtime, preview, and resources
- `Docs/specs/CanvasAnnotations.md`: `.ogp`-only sticky-note, ink, Sidecar input, and agent-access contract
- `Docs/specs/CanvasObjectReferences.md`: `.ogp` canvas-level editable object-reference contract
- `Docs/specs/CanvasAids.md`: ruler, `.ogp` guide, grid, coordinate, and persistence contract
- `Docs/specs/AgentInterface.md`: CLI, MCP, JSON graph, and external-sync contract
- `Docs/rules/TutorialSynchronizationStandards.md`: required synchronization rule for user-facing feature changes and `Tutorials` sample resources

## Model

HTML is the canonical structure and reference document. The same-named companion CSS is the writable home for new node-scoped overrides, while inspection also respects authored project, linked, embedded, and inline CSS. OpenGraphite can inspect ordinary HTML without any OpenGraphite annotation:

```html
<main id="landing-page">
  <article class="hero-card">
    <h1>OpenGraphite</h1>
  </article>
</main>
```

When AI and people need a stable cross-session node reference, optional collaboration identity can be adopted explicitly:

```html
<HeroSection
  data-og-id="hero"
  data-og-internal-id="hero-node">
  <MainTitle data-og-id="title">
    OpenGraphite
  </MainTitle>
</HeroSection>
```

```css
[data-og-internal-id="hero-node"] {
  display: flex;
  flex-direction: column;
  gap: 32px;
  padding: 64px;
  border-radius: 24px;
}
```

OpenGraphite reads tag names, standard IDs, classes, attributes, DOM structure, and authored CSS as normal Web source. `data-og-id` and `data-og-internal-id` are optional AI-collaboration identity, not a loading requirement; retained `data-og-*` is limited to reference, binding, editing policy, or provenance that the standard Web implementation cannot reconstruct. Composite masters are hyphenated Custom Element hosts with a direct `<template>` in project `collections[].components[]`; pages keep the OpenGraphite-specific `<og-instance data-og-component>` reference while content projection and styling use standard named/default `slot`, host `variant`, `part`, Shadow DOM, and `::part()`. Relative `href` / `src` values inside a component template resolve against that component master source file in browser runtime, file Canvas preview, and screenshot rendering. Browser runtime creates open Shadow DOM and static build emits equivalent Declarative Shadow DOM. Component canvases can also contain `<og-placement>` nodes that reference another component node and display multiple preview states side by side while keeping edits synchronized to the source component. Placement-specific preview mocks live only in the `.ogp` canvas `previewContext.placementMocks`: `host.<attribute>` and `host.class` temporarily project standard host attributes, classes, and ARIA onto the generated preview clone, and project-authored `:host(...)` CSS determines its computed state without changing source HTML. The Sample project keeps code / preview / loading / collapsed examples synchronized with this contract.

Node operations are capability-based rather than a single stored type. Graph nodes return a deterministic raw-value-sorted `capabilities` array containing any supported combination of `drag-position`, `edit-control`, `edit-icon`, `edit-layout`, `edit-link`, `edit-media`, `edit-text`, `group`, `receive-children`, `reorder-flow`, and `ungroup`. `capabilityEvidence` reports the exact standard-Web facts behind that decision as `isProjectResourceRoot`, `isNativeControl`, `isCustomElement`, `isLink`, `hasDirectText`, `hasElementChildren`, `hasMediaContent`, `hasSVGContent`, `hasMaskContent`, optional `ariaRole`, and optional `resolvedDisplay`. A pre-migration `0.1.0` `data-og-type` value is exposed only as optional `legacyTypeHint`; OpenGraphite never generates it for new source, adoption, runtime output, or static builds, and `OpenGraphite.css` has no type-based reset or visual defaults. Removing that legacy input requires the explicit project migration described below; ordinary open, inspection, validation, build, and save never rewrite it.

Nodes without a unique `data-og-internal-id` appear in Canvas, Layers, Inspector, CLI, and MCP inspection with session-scoped references; a partial annotation that already has a unique internal ID can be stable. Existing standard `id` and safe selectors are preferred. Opening, previewing, validating, building, or saving without edits never adds OpenGraphite attributes. A stable reference is added only through explicit adoption, which first returns a dry-run and unified source diff. Its apply-only proposal reference binds the target locator, whole-document hash, and normalized scope/display ID; apply rejects graph session references, changed source, and changed proposal parameters. Missing annotation is valid; duplicate identity that exists and broken persisted references remain diagnostics.

Page themes use standard `background` and `color` declarations on the document or page root. Shared values can use project-defined CSS Custom Properties such as `--color-accent`; OpenGraphite exposes their values and dependencies without reserving token names or theme meanings.

Locale typography uses a standard root `font-family`, same-scope `:lang(<BCP47>)` rules, CSS inheritance, and element-level overrides. Preview changes only the clone's standard `lang` / `dir`, while the Inspector keeps authored selector provenance separate from the WebKit computed font.

Media rendering values live on the actual Web elements: `object-fit` on `img` / `video`, `stroke-width` on SVG, and `mask-image` / `-webkit-mask-image` on a mask child. Icon library, name, and source annotations remain optional provenance on the wrapper.

Persistent flips use the standard individual `scale` property: `scale: -1 1` flips horizontally and `scale: 1 -1` flips vertically. Authored `scale`, `rotate`, `transform`, and `transform-origin` remain independent standard CSS declarations and compose according to the browser's transform model. Drag and reorder previews use session-only `translate` or the Web Animations API and never overwrite those authored declarations or persist to source.

Layout and visibility also remain standard Web source. Flex, Grid, Block, and mixed flow/positioned layouts are derived from `display`, `flex-direction`, grid properties, and each child's `position`/inset declarations; responsive results follow authored `@media` rules. Persistent HTML hiding uses `hidden`, while authored `display` and `visibility` remain CSS declarations with their source provenance. `data-og-text-source` remains optional binding metadata but never selects text wrapping; projects set `overflow-wrap` in ordinary CSS.

Source inspection keeps the project CSS library, same-named companion CSS, each readable local linked stylesheet, and each embedded `<style>` as separate lossless sources; linked/embedded sources follow browser document order, while an unlinked project library is the first fallback and an unlinked companion is the last. Existing inline `style` remains an HTML source. Trace candidates expose source identity, kind, editability, stylesheet/declaration order, and inheritance separately from App-only WebKit computed values. Custom properties are resolved only after candidates from every source and inherited parent values are combined, so a reference supplied by another sheet or ancestor is not falsely marked incomplete. A supported shorthand containing `var()` keeps its raw shorthand provenance and is expanded into semantic longhand components only after that final substitution; an invalid expansion makes only the affected node/property read-only. CSS-wide identifier escapes are decoded for semantics while authored spelling stays lossless. `revert` / `revert-layer` do not reuse an earlier candidate from the same author origin: inherited properties retain the parent's computed value, non-inherited author values are omitted so HTML UA fallback remains available, and that node/property is read-only. The shared headless validator covers supported keyword, geometry, numeric/math, and grid-track grammars. An authored value that fails a supported-property grammar stays byte-exact, does not establish a resolved winner, and makes the matching node/property incomplete. Syntactically valid `env()`, `anchor()`, and `anchor-size()` values also stay authored but remain unresolved and incomplete because their environment cannot be inferred headlessly. A setter value that fails the grammar, reaches another declaration with a top-level `;`, or injects top-level `!important` returns `invalid-css-property-value` with atomic no-write; an environment-dependent value is accepted as syntax but is likewise not written when its postcondition cannot be resolved safely. For `hidden="until-found"`, the headless UA fallback is `content-visibility:hidden`, while authored `initial`, `unset`, or `visible` resolves to `visible` without changing the `hidden` source intent. Active `<link media>`, `<style media>`, and nested `@media` conditions must be supplied consistently to headless inspection and mutation. External or unreadable stylesheets, unresolved `@import`, malformed CSS, unsupported selectors, and source-wide unsupported layer/property rules leave known-source inspection available with `incomplete-css-provenance` but make all CSS mutation read-only. A matching unevaluated conditional, an active-animation node in a graph containing keyframes, or a headless-unresolved CSS-wide value is read-only only for that node/target; keyframes alone do not make a source incomplete.

Editor-only sticky notes and ink live in `chapters[].annotations[]` or `collections[].annotations[]` in the `.ogp`. They render in front of the HTML cards, support pen, eraser, and lasso multi-selection tools, can be read through the CLI/MCP interface, and are intentionally excluded from source HTML, CSS, browser runtime, and build output.

Canvas-level editable object references live in `chapters[].references[]` or `collections[].references[]`. A Pages or Components canvas can reference any non-page-root node through its typed `ogref:node` or `ogref:component-node` ID, including a node from the other segment. The placement remains a top-level editor viewport while edits write through to the referenced HTML and companion CSS; it never nests a clone inside another HTML object. The referenced WebKit border box is scaled uniformly into the saved maximum bounds, while the card body, selection chrome, hit area, and displayed dimensions shrink to the actual rendered footprint instead of exposing unused bounds as object whitespace. Focused references suppress the source page's root document scrolling and scroll indicators while preserving explicit overflow scrolling inside the referenced subtree. Placement add, move, and delete operations, plus HTML and companion-CSS edits made through a reference viewport, participate in the same conflict-safe Undo / Redo timeline as other editor changes.

Rulers, guides, and grids are editor preview aids. Visibility remains local in app `UserDefaults`, while guide positions live in the selected Chapter or Collection's `.ogp` `guides[]`; none of these aids modify HTML, CSS, runtime, screenshots, or build output.

## Build

Install XcodeGen, then run:

```bash
./Scripts/build.sh
```

The script runs:

```bash
xcodegen generate
xcodebuild -project OpenGraphite.xcodeproj -scheme OpenGraphite -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

`OpenGraphite.xcodeproj` is generated output. Keep `project.yml` as the source of truth.

## Test

Tests use Swift Testing (`@Suite` / `@Test`) and follow
`Docs/rules/TestingStandards.md`.

```bash
./Scripts/test.sh
```

## Quality Gate

Run the required quality gate before completing code or project-configuration changes:

```bash
./Scripts/quality_gate.sh
```

The gate regenerates `OpenGraphite.xcodeproj` from `project.yml`, runs the Swift Testing suite, builds `ogkiln`, validates the sample project, and checks that tutorial HTML, companion CSS, and `Tutorials` manifest registration remain structurally synchronized.

## Tutorial Synchronization

User-observable feature additions, changes, and removals must update the corresponding `Tutorials` learning canvas in the same change. Prefer updating the most specific existing lesson; add a new lesson when the feature introduces an independent user goal or workflow. Keep page lessons under `public/tutorial-*.html`, component lessons under `public/_components/tutorial-components-*.html`, and register each lesson with its same-named companion CSS in the Sample `.ogp`.

Editor-only teaching examples must keep their normal ownership: sticky notes and ink in `.ogp` `annotations[]`, Guide positions in `.ogp` `guides[]`, and preview mocks in the target canvas `previewContext`. Do not duplicate them into tutorial HTML or CSS.

The complete scope, exceptions, workflow, and completion criteria are defined in `Docs/rules/TutorialSynchronizationStandards.md`. Run the structural check directly with:

```bash
./Scripts/validate_tutorial_sync.sh
```

## Agent Interface

Inspect and edit project-registered OpenGraphite HTML with `ogkiln`. The CLI edits only pages registered under chapters or component canvases registered under collections in the target `.ogp`; use `current` to target the project currently opened by `OpenGraphite.app`.

```bash
./Scripts/ogkiln project create --root ../MySite --output ../MySite/OpenGraphiteProject.ogp --json
./Scripts/ogkiln migrate ../LegacySite/OpenGraphiteProject.ogp --target-version 1.0.0 --json
./Scripts/ogkiln migrate ../LegacySite/OpenGraphiteProject.ogp --target-version 1.0.0 --proposal '<proposal-reference-from-dry-run>' --apply --json
./Scripts/ogkiln project inspect SampleProject/OpenGraphiteSample.ogp --json
./Scripts/ogkiln project current --json
./Scripts/ogkiln annotation list SampleProject/OpenGraphiteSample.ogp --chapter-id main --json
./Scripts/ogkiln annotation get SampleProject/OpenGraphiteSample.ogp --id ogref:annotation:pages:<chapter-internal-id>:<annotation-internal-id> --json
./Scripts/ogkiln design-token list SampleProject/OpenGraphiteSample.ogp --json
./Scripts/ogkiln design-token set SampleProject/OpenGraphiteSample.ogp --name --color-accent --value '#f5f7f8'
./Scripts/ogkiln locale-typography list SampleProject/OpenGraphiteSample.ogp --page-id home --json
./Scripts/ogkiln project page create SampleProject/OpenGraphiteSample.ogp --page-id tutorial --path tutorial.html --title Tutorial --body-file tutorial.body.html --x 2960 --y 0
./Scripts/ogkiln project page add SampleProject/OpenGraphiteSample.ogp --page-id archive --path archive.html --x 4440 --y 0
./Scripts/ogkiln project page place SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:2opic2blumreb --name Desktop --x 3040 --y 0
./Scripts/ogkiln project component create SampleProject/OpenGraphiteSample.ogp --collection-id component-main --component-id shared-ui --path _components/shared-ui.html --title 'Shared UI' --body-file shared-ui.body.html
./Scripts/ogkiln project component place SampleProject/OpenGraphiteSample.ogp --component-id ogref:component:component-main:dssystemcomp01 --name Desktop --width 1180 --height 1900
./Scripts/ogkiln project component remove SampleProject/OpenGraphiteSample.ogp --component-id <shared-ui-internal-id> --delete-file
./Scripts/ogkiln screenshot canvas SampleProject/OpenGraphiteSample.ogp --chapter-id main --output screenshots/canvas.png
./Scripts/ogkiln screenshot page SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:2opic2blumreb --output screenshots/docs.png
./Scripts/ogkiln screenshot node SampleProject/OpenGraphiteSample.ogp --id ogref:node:1gibtxulofmr0:2opic2blumreb:fb1954bc9811 --output screenshots/doc-cli.png
./Scripts/ogkiln build SampleProject/OpenGraphiteSample.ogp --output dist
./Scripts/ogkiln page graph SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --json
./Scripts/ogkiln page graph SampleProject/OpenGraphiteSample.ogp --component-id ogref:component:component-main:dssystemcomp01 --json
./Scripts/ogkiln page graph SampleProject/OpenGraphiteSample.ogp --page-id tutorial-objects --json
./Scripts/ogkiln page graph SampleProject/OpenGraphiteSample.ogp --page-id tutorial-auto-layout --active-media '(max-width: 760px)' --json
./Scripts/ogkiln node adopt SampleProject/OpenGraphiteSample.ogp --page-id tutorial-objects --reference '<session-reference-from-graph>' --scope node --json
./Scripts/ogkiln node adopt SampleProject/OpenGraphiteSample.ogp --page-id tutorial-objects --reference '<target-reference-from-dry-run>' --scope node --apply --json
./Scripts/ogkiln validate SampleProject/OpenGraphiteSample.ogp --json
./Scripts/ogkiln node query SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --capability edit-link --capability edit-text --text-contains Docs --json
./Scripts/ogkiln node get SampleProject/OpenGraphiteSample.ogp --id ogref:node:1gibtxulofmr0:kl1xxsgkiuue:3aefceddb042 --active-media '(prefers-reduced-motion: reduce)' --json
./Scripts/ogkiln node style set SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --id 3aefceddb042 --var gap --value 32px
./Scripts/ogkiln node style set SampleProject/OpenGraphiteSample.ogp --page-id tutorial-auto-layout --id tutlayhrow0002 --var flex-direction --value column --active-media '(max-width: 760px)'
./Scripts/ogkiln node style remove SampleProject/OpenGraphiteSample.ogp --page-id tutorial-auto-layout --id tutlayhrow0002 --var flex-direction --active-media '(max-width: 760px)'
./Scripts/ogkiln node text set SampleProject/OpenGraphiteSample.ogp --component-id ogref:component:component-main:dssystemcomp01 --id 57d89af48b12 --value 'Availability-ready card'
./Scripts/ogkiln node text set SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --id eace7f6a5b08 --value 'OpenGraphite'
./Scripts/ogkiln node html insert SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --id 72222bd6f11e --position prepend --html '<Header data-og-id="site-header"></Header>'
./Scripts/ogkiln node move SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --id efeaffcc2273 --target 3aefceddb042 --position after
./Scripts/ogkiln node copy SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --id d9778be9a854 --target b01aee52375f --position append --id-prefix copy-
```

Use the same repeatable `--active-media` conditions for graph inspection and `node style set/remove`; MCP exposes the equivalent `activeMediaQueries` array on list/query/get and `set_css_variable` / `remove_css_variable`. Page/node payloads expose `hasIncompleteCSSProvenance`; source-wide incompleteness blocks all style mutation, while node-level conditional/animation/CSS-wide incompleteness blocks only that target. A blocked write returns `incomplete-css-provenance-write-blocked` without writing, with `incomplete-css-node-provenance` also identifying a node-level guard. Direct inline/companion winners can be minimally updated, while a read-only project/linked/embedded winner can only receive a safe companion override; an unsafe specificity override returns `css-specificity-override-unsafe`. Removing a winner that exists only in a read-only source returns `read-only-css-winner`, removing a longhand resolved from a shorthand returns `shorthand-css-removal-unsupported`, and a failed winner verification returns `css-mutation-postcondition-failed`. Only `design-token set/remove` and the corresponding MCP tools mutate the project `cssLibrary`.

`node query --capability <name>` is repeatable and uses all-match semantics. `--type <legacy-hint>` remains only for exact matching of an authored legacy hint; it is not a semantic or capability filter.

`node attr set/remove` accepts only `OpenGraphite.contract.json` `editableAttributes` on a DOM target whose standard tag/content model and operation capabilities support that attribute. This includes standard HTML attributes such as `hidden`, `href`, `target`, `aria-label`, `value`, `src`, and `alt`, as well as retained OpenGraphite metadata; it is not a `data-og-*`-only interface. Setting `--value ''` preserves a present empty attribute, while only explicit `node attr remove` deletes the attribute token. A disallowed contract name returns `disallowed-attribute`, and a name that is not valid for the selected semantic target returns `unsupported-node-capability`; both are atomic no-write results.

New projects and generated resources use Web contract `1.0.0`. Existing `0.1.0` projects migrate only through `ogkiln migrate` or MCP `migrate_project`: the first call is a no-write dry-run that returns all resource diffs and a proposal bound to the target version, fixed options, project manifest, and every target canonical relative path/raw-byte SHA-256 hash, including any UTF-8 BOM. The closure includes registered HTML, the project CSS library, existing companion CSS, project-local linked styles/scripts, and recursive local `@import`; inline and embedded CSS migrate with their HTML candidate, and local imports discovered in embedded `<style>` also join the closure. HTML dependencies are dispatched by link/script relation and actual source kind rather than URL extension, so extensionless stylesheet and runtime paths remain covered. A `<style>` is CSS only when `type` is omitted, exact empty, or ASCII-case-insensitive exact `text/css`; a stylesheet `<link>` uses its HTTP-whitespace-trimmed MIME essence and treats present-empty `type` as non-CSS; a `<script>` is executable only for exact empty, ASCII-case-insensitive exact `module`, or an exact JavaScript MIME type, with `type` taking precedence over obsolete `language`. JSON/import-map/data-block scripts and non-CSS style/link bodies stay opaque. HTML/CSS whitespace is only TAB/LF/FF/CR/SPACE, HTTP whitespace excludes FF, and NBSP/vertical-tab remain authored value characters. HTML non-void `/>` does not close the element, while SVG/MathML self-closing does; decimal/hex numeric character references are interpreted even without a semicolon. Unrelated raw spelling, CRLF, and BOM remain lossless. Apply requires the same proposal. Missing or stale proposals and unsupported targets always leave the entire project unchanged without partial diffs. Only when registered sources contain legacy input do unknown reserved legacy CSS, unresolved import/module/runtime dependencies, unconvertible structure/state, a missing/outside-root/unreadable discovered dependency, or the same canonical URL being classified as both CSS and runtime (`migration-resource-kind-conflict`) block migration; a clean standard project remains an unchanged no-op. Immediately before each candidate commit, apply revalidates the full proposal closure from raw bytes and path resolution; a stale closure rolls back earlier commits and returns `stale-migration-proposal`. Rollback is compare-and-swap: it restores only a committed resource that still matches the migration output bytes and mode, preserving a concurrent external edit and reporting `migration-rollback-failed` instead of overwriting it.

Catalog v1 converts known type/layout/icon-mask selectors to `.og-migrated-v1-*`, hidden/variant/part to standard attributes, and known design custom properties to `--migrated-v1-*`, while preserving optional identity, component/source references, binding, editing policy, icon provenance, and unknown non-owned `data-*`. It records only destinations it would newly generate; project CSS, executable inline/linked JavaScript, and inline event handlers that read legacy input or observe one of those generated classes, standard attributes, or custom properties block migration. Direct/bracket/aliased attribute access and borrowed `call`/`apply` are classified alike, but an exact attribute name intersects only a destination actually generated; only dynamic names become whole-attribute evidence. Whole-column `dataset` / `style` evidence blocks only when it intersects an actually removed dataset attribute, inline-style mutation, or generated custom property. Whole-attribute, dynamic selector/computed DOM, and AttributeNode evidence intersects only actual HTML attribute changes; whole-markup evidence intersects any HTML source change, including embedded-style migration. External CSS changes intersect CSSOM observers, while embedded CSS changes intersect CSSOM or actual style-text observers. ID-based style/link evidence is scoped to actual CSS owners in the HTML that refers to the inline/linked runtime, so unrelated pages, same-ID non-style elements, runtime-created style text, ordinary element text, `CSSStyleDeclaration.cssText`, and generic object/property access do not create a CSS whole-source conflict. Preview-manifest changes intersect global-preview-context `placementMocks`/whole-context access or an exact/static-concatenated newly generated `host.*` field; fields/document-only access and unrelated objects with a `placementMocks` property remain safe. An already-present semantically equal standard destination is not generated evidence: its authored case, quoting, character references, and surrounding raw bytes remain intact while only the legacy token is removed. Ambiguous component master/slot and source placement state block migration until template/slot/placement source is manually standardized. Only `.ogp` placement mocks `codeViewerMode=preview` and `placementMode=collapsed` map to `host.variant`; source HTML stays unchanged. A project-local `OpenGraphite.contract.json` remains byte-for-byte tool configuration and is neither a proposal target nor a diff/apply candidate; source version reporting is derived from registered-source legacy tokens, not that file's version. The `.ogp` schema version and Agent JSON `schemaVersion` remain unchanged, and a second dry-run is idempotent with no diffs.

`project create` creates a new `.ogp` at `--output` and uses `--root` as the project root for `public` and `CSS` resources. If `public` does not exist, it seeds `public/index.html`, `public/index.css`, `CSS/OpenGraphite.css`, and a `home` page entry. If `public` already exists, it leaves existing HTML unregistered and creates an empty Chapter manifest while copying `CSS/OpenGraphite.css` when missing.

`ogkiln build` expands component instances into static Pages HTML, removes the runtime/component source links from the output, and copies `OpenGraphite.css`, companion CSS, and non-HTML public assets into the output directory. The input `.ogp` manifest is editor-only and is not copied; its canvas annotations, guides, and canvas object references are not injected into generated HTML or CSS.

`ogkiln screenshot canvas` accepts either `--chapter-id` or `--collection-id` to composite that container's visible HTML cards and `.ogp` annotations; with neither selector it uses the first Chapter that is visible in the Sidebar, and requires an explicit selector when every Chapter is hidden.

The OpenGraphite MCP server exposes the same repository-backed operations over stdio:

```bash
node MCP/OpenGraphite/server.mjs
```

## Run

For local app launch from Codex or a terminal:

```bash
./script/build_and_run.sh
```

Useful modes:

```bash
./script/build_and_run.sh --verify
./script/build_and_run.sh --logs
```

## Release DMG

This repository includes the local DMG/notarization workflow adapted from
[My-Swift-Project-template](https://github.com/Masashi-desu/My-Swift-Project-template).

Application releases use `project.yml` as the version source of truth. The
current app version is `0.1.0(1)`, represented as `MARKETING_VERSION: 0.1.0`
and `CURRENT_PROJECT_VERSION: 1`.

For the current release operation, `dev` is the release-preparation branch and
`main` is the public branch. The signed and notarized DMG is created locally
and uploaded to GitHub Releases from the `dev` commit without adding the DMG to
Git. Pushes to `dev` and `main` still run CI; the `main` push verifies that the
expected release tag and DMG asset already exist. See
`Docs/release/README_dev_main_github.md`.

Create a local release configuration:

```bash
cp .env.example .env
```

Then edit `.env` for your Developer ID / notarization credentials.

Commit the release changes on `dev`, push `dev`, and wait for CI to pass. Then
build the local DMG:

```bash
./Scripts/release_dmg.zsh --output-dir dist
```

Create the GitHub Release from the `dev` commit and upload the local DMG:

```bash
./Scripts/release/github/publish_local_release.sh
```

After the release is created, publish the same commit to `main`:

```bash
git push origin HEAD:main
```

CI does not rebuild, sign, notarize, or upload the DMG.

For local DMG creation without notarization, install `create-dmg`, set
`CODESIGN_IDENTITY="-"` and `CODESIGN_ENTITLEMENTS=""` in `.env`, then run:

```bash
./Scripts/release_dmg.zsh --skip-notarize
```

Details are documented in `Docs/release/README_local_DMG.md`.

## Sample

Open `SampleProject/OpenGraphiteSample.ogp` from the Welcome screen or press **Open Sample Project**. The sample resolves `public/index.html` and `CSS/OpenGraphite.css` from the repository root.

The sample keeps the public OpenGraphite site in the `Main` Chapter / Collection and provides hands-on learning canvases separately under `Tutorials`.

- Pages tutorials: basic objects, progressive annotation adoption, explicit Web contract migration, Page / Chapter visibility management, standard Flex / Grid / Block / responsive layout, absolute and mixed positioning, appearance and typography, standard media and icons, motion, standard flip composition, native hidden state, component instances, sticky notes, rulers and guides, and stylus ink.
- Components tutorials: master anatomy, slots and instance content, and synchronized state previews with component placements.
- Each tutorial is an independent HTML file with a same-named companion CSS file, so users can select the examples in Canvas, inspect their hierarchy in Layers, and safely change the prompted values in Inspector.
- The sticky-note and stylus tutorials also include live `.ogp` annotations, while the guide tutorial includes project-persisted Guide positions; these teaching aids remain separate from the public HTML and CSS.

When launched through the Debug scheme, `OPENGRAPHITE_SAMPLE_PROJECT_PATH` points Open Sample Project at `SampleProject/OpenGraphiteSample.ogp` in the checkout. The app still resolves and saves HTML through the paths declared in that `.ogp`; the repository files are touched because the sample `.ogp` points there.

When launched without that environment variable, Open Sample Project treats the bundled `SampleProject`, `public`, and `CSS` directories as a read-only seed. On first use it copies them to `~/Library/Application Support/OpenGraphite/Samples/OpenGraphiteSample/` and opens that copied `.ogp`. Existing copied samples are not overwritten.

## Current Editor Features

- Welcome screen with sample and arbitrary `.ogp` open actions
- Pages/Components sidebar with resizable, collapsible Chapter/Collection selectors and layers inside each HTML card
- Page context actions to hide or restore a card on its Chapter canvas, plus permanent source deletion only when no other `.ogp` placement uses the same HTML; Chapter context actions can hide a Chapter from the Sidebar while preserving its canvas contents
- Top-chrome Objects / History icon-only sidebar switcher, with a session-only unified Undo / Redo list that shows each operation timestamp, object name, and object-type thumbnail
- WKWebView canvas using `.ogp` canvas dimensions
- Canvas-background context-menu insertion of any typed page/component node reference, with live object preview, exact world-position placement, drag repositioning, and edits synchronized to the referenced source
- Normal / Flow canvas modes, plus a separate right-click Focus preview that shows one HTML object or a whole page card in a centered, finite scrolling region; Focus uses the same canvas zoom input resolver for `Command + scroll`, trackpad pinch, and compatible gesture events, keeps 100% as original size, supports zoom in/out without creating an infinite canvas, and uses cancelable runtime-only animation effects without adding source markers
- Front-layer sticky notes and mouse/Sidecar Apple Pencil ink, with eraser and lasso multi-selection tools, stored only in Chapter/Collection `.ogp` annotations
- Rulers, undoable `.ogp`-persisted guides creatable by ruler drag or context menu and repositionable by drag or numeric input, plus an adaptive canvas grid, independently visible from Settings without changing HTML or CSS
- DOM layer extraction for unannotated, partially annotated, and fully annotated standard HTML, with session/stable reference status
- Canvas and nested layer node selection
- Inspector display for tag, available OpenGraphite annotations, annotation completeness, and reference stability
- Inspector editing for common CSS design properties with companion CSS write-back
- Authored CSS provenance kept separate from WebKit computed `display` / `position` / `visibility` / `content-visibility`, with CSS controls read-only when provenance is incomplete
- Wrapper-aware media and icon inspection that writes standard properties to the rendered `img`, `video`, SVG, or mask child while preserving CSS provenance
- Inspector value input with drag-to-scrub numeric fields, glyph option strips, and read-only previews for corner radius, border, gradient, shadow, and typography
- Project Inspector editing for project-defined `:root` CSS Custom Properties as generic design tokens, with CLI/MCP access through `ogkiln design-token`; page themes remain standard root `background` / `color` declarations
- Inspector editing for CSS animation and scroll-driven animation timeline declarations

## Standalone HTML

`public/index.html` references `../CSS/OpenGraphite.css`, `public/index.css`, and shared component CSS, so it can be opened directly in a browser from the repository checkout.

## Development Rules

- Swift document comment guidance: `Docs/rules/DocumentCommentStandards.md`
- Swift Testing guidance: `Docs/rules/TestingStandards.md`
- Design philosophy: `Docs/specs/DesignPhilosophy.md`
- Source-of-truth contract: `Docs/specs/SourceOfTruthContract.md`
- Canvas annotation contract: `Docs/specs/CanvasAnnotations.md`
- Canvas object-reference contract: `Docs/specs/CanvasObjectReferences.md`
- Operations TODO governance: `Docs/operations/TODO/GOVERNANCE.md`
