# OpenGraphite

OpenGraphite is a macOS SwiftUI design editor that treats HTML as the editable source of truth, not as an export artifact. Edits made in `OpenGraphite.app` are reflected directly in the opened HTML file, and that HTML can be used as the web deliverable.

## Artifacts

- `OpenGraphite.app`: macOS SwiftUI app generated from `project.yml`
- `CSS/OpenGraphite.css`: distributable CSS library for `data-og-*`, standard design properties, and reserved `--og-*` helpers
- `OpenGraphite.contract.json`: machine-readable `data-og-*` and editable CSS declaration contract
- `public/OpenGraphite.runtime.js`: optional runtime that expands `<og-instance>` component references in the browser
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

HTML is the canonical structure and reference document. Editable design values live in the same-named companion CSS file.

```html
<HeroSection
  data-og-id="hero"
  data-og-type="frame"
  data-og-layout="vertical"
  data-og-internal-id="hero-node">
  <MainTitle data-og-id="title" data-og-type="text">
    OpenGraphite
  </MainTitle>
</HeroSection>
```

```css
[data-og-internal-id="hero-node"] {
  gap: 32px;
  padding: 64px;
  border-radius: 24px;
}
```

OpenGraphite does not use class names as the editable style source of truth. Tag names represent semantic components, `data-og-*` stores structure and reference metadata, companion CSS stores design values, and `OpenGraphite.css` provides the shared rendering rules. Composite components can be authored as HTML masters in project `collections[].components[]` and referenced from pages with `<og-instance>`. Component canvases can also contain `data-og-role="component-placement"` nodes that reference another component node and display multiple preview states side by side while keeping edits synchronized to the source component. Placement-specific preview mocks live in the `.ogp` canvas `previewContext`, not in the source HTML.

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
./Scripts/ogkiln project inspect SampleProject/OpenGraphiteSample.ogp --json
./Scripts/ogkiln project current --json
./Scripts/ogkiln annotation list SampleProject/OpenGraphiteSample.ogp --chapter-id main --json
./Scripts/ogkiln annotation get SampleProject/OpenGraphiteSample.ogp --id ogref:annotation:pages:<chapter-internal-id>:<annotation-internal-id> --json
./Scripts/ogkiln design-token list SampleProject/OpenGraphiteSample.ogp --json
./Scripts/ogkiln design-token set SampleProject/OpenGraphiteSample.ogp --name --color-accent --value '#f5f7f8'
./Scripts/ogkiln project page create SampleProject/OpenGraphiteSample.ogp --page-id tutorial --path tutorial.html --title Tutorial --body-file tutorial.body.html --x 2960 --y 0
./Scripts/ogkiln project page add SampleProject/OpenGraphiteSample.ogp --page-id archive --path archive.html --x 4440 --y 0
./Scripts/ogkiln project page place SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:2opic2blumreb --name Desktop --x 3040 --y 0
./Scripts/ogkiln project component create SampleProject/OpenGraphiteSample.ogp --collection-id component-main --component-id shared-ui --path _components/shared-ui.html --title 'Shared UI' --body-file shared-ui.body.html
./Scripts/ogkiln project component place SampleProject/OpenGraphiteSample.ogp --component-id ogref:component:component-main:3bgx6phkz3jv5 --name Desktop --width 1180 --height 1900
./Scripts/ogkiln project component remove SampleProject/OpenGraphiteSample.ogp --component-id <shared-ui-internal-id> --delete-file
./Scripts/ogkiln screenshot canvas SampleProject/OpenGraphiteSample.ogp --chapter-id main --output screenshots/canvas.png
./Scripts/ogkiln screenshot page SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:2opic2blumreb --output screenshots/docs.png
./Scripts/ogkiln screenshot node SampleProject/OpenGraphiteSample.ogp --id ogref:node:1gibtxulofmr0:2opic2blumreb:fb1954bc9811 --output screenshots/doc-cli.png
./Scripts/ogkiln build SampleProject/OpenGraphiteSample.ogp --output dist
./Scripts/ogkiln page graph SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --json
./Scripts/ogkiln page graph SampleProject/OpenGraphiteSample.ogp --component-id ogref:component:component-main:3bgx6phkz3jv5 --json
./Scripts/ogkiln validate SampleProject/OpenGraphiteSample.ogp --json
./Scripts/ogkiln node query SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --type button --text-contains Docs --json
./Scripts/ogkiln node get SampleProject/OpenGraphiteSample.ogp --id ogref:node:1gibtxulofmr0:kl1xxsgkiuue:3aefceddb042 --json
./Scripts/ogkiln node style set SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --id 3aefceddb042 --var gap --value 32px
./Scripts/ogkiln node text set SampleProject/OpenGraphiteSample.ogp --component-id ogref:component:component-main:3bgx6phkz3jv5 --id 57d89af48b12 --value 'Availability-ready card'
./Scripts/ogkiln node text set SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --id eace7f6a5b08 --value 'OpenGraphite'
./Scripts/ogkiln node html insert SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --id 72222bd6f11e --position prepend --html '<Header data-og-id="site-header" data-og-type="frame"></Header>'
./Scripts/ogkiln node move SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --id efeaffcc2273 --target 3aefceddb042 --position after
./Scripts/ogkiln node copy SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --id d9778be9a854 --target b01aee52375f --position append --id-prefix copy-
```

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

- Pages tutorials: basic objects and Page / Chapter visibility management, Auto Layout, Absolute Layout, appearance and typography, media and icons, motion and object state, component instances, sticky notes, rulers and guides, and stylus ink.
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
- Normal / Flow canvas modes, plus a separate right-click Focus preview that shows one HTML object or a whole page card in a centered, finite scrolling region; Focus uses the same canvas zoom input resolver for `Command + scroll`, trackpad pinch, and compatible gesture events, keeps 100% as original size, supports zoom in/out without creating an infinite canvas, and removes editor-only object-focus markers before HTML is saved
- Front-layer sticky notes and mouse/Sidecar Apple Pencil ink, with eraser and lasso multi-selection tools, stored only in Chapter/Collection `.ogp` annotations
- Rulers, undoable `.ogp`-persisted guides creatable by ruler drag or context menu and repositionable by drag or numeric input, plus an adaptive canvas grid, independently visible from Settings without changing HTML or CSS
- DOM layer extraction from `[data-og-id]`
- Canvas and nested layer node selection
- Inspector display for tag, `data-og-id`, `data-og-type`, `data-og-layout`, `data-og-role`
- Inspector editing for common CSS design properties with companion CSS write-back
- Inspector value input with drag-to-scrub numeric fields, glyph option strips, and read-only previews for corner radius, border, gradient, shadow, and typography
- Project Inspector editing for `:root` CSS Custom Properties as design tokens, with CLI/MCP access through `ogkiln design-token`
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
