# OpenGraphite

OpenGraphite is a macOS SwiftUI design editor that treats HTML as the editable source of truth, not as an export artifact. Edits made in `OpenGraphite.app` are reflected directly in the opened HTML file, and that HTML can be used as the web deliverable.

## Artifacts

- `OpenGraphite.app`: macOS SwiftUI app generated from `project.yml`
- `CSS/OpenGraphite.css`: distributable CSS library for `data-og-*` and `--og-*`
- `OpenGraphite.contract.json`: machine-readable `data-og-*` and `--og-*` contract
- `public/OpenGraphite.runtime.js`: optional runtime that expands `<og-instance>` component references in the browser
- `Scripts/ogkiln`: CLI for repository-backed inspection, validation, and node-level HTML edits
- `MCP/OpenGraphite/server.mjs`: OpenGraphite MCP server backed by `ogkiln`
- `SampleProject/OpenGraphiteSample.ogp`: sample project file
- `public/index.html`: standalone OpenGraphite introduction page
- `project.yml`: XcodeGen source of truth
- `Docs/Architecture.md`: design notes
- `Docs/specs/DesignPhilosophy.md`: design philosophy and source-of-truth contract
- `Docs/specs/AgentInterface.md`: CLI, MCP, JSON graph, and external-sync contract

## Model

HTML is the canonical document.

```html
<HeroSection
  data-og-id="hero"
  data-og-type="frame"
  data-og-layout="vertical"
  data-og-role="landing-hero"
  style="
    --og-gap:32px;
    --og-padding:64px;
    --og-radius:24px;
  ">
  <MainTitle data-og-id="title" data-og-type="text">
    OpenGraphite
  </MainTitle>
</HeroSection>
```

OpenGraphite does not use class names as the style source of truth. Tag names represent semantic components, `data-og-*` stores editor metadata, CSS variables store design values, and `OpenGraphite.css` provides the rendering rules. Composite components can be authored as HTML masters in project `collections[].components[]` and referenced from pages with `<og-instance>`.

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

The gate regenerates `OpenGraphite.xcodeproj` from `project.yml` and runs the Swift Testing suite.

## Agent Interface

Inspect and edit project-registered OpenGraphite HTML with `ogkiln`. The CLI edits only pages registered under chapters or component canvases registered under collections in the target `.ogp`; use `current` to target the project currently opened by `OpenGraphite.app`.

```bash
./Scripts/ogkiln project inspect SampleProject/OpenGraphiteSample.ogp --json
./Scripts/ogkiln project current --json
./Scripts/ogkiln project page create SampleProject/OpenGraphiteSample.ogp --page-id tutorial --path tutorial.html --title Tutorial --body-file tutorial.body.html --x 2960 --y 0
./Scripts/ogkiln project page add SampleProject/OpenGraphiteSample.ogp --page-id archive --path archive.html --x 4440 --y 0
./Scripts/ogkiln project page place SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:2opic2blumreb --name Desktop --x 3040 --y 0
./Scripts/ogkiln project component create SampleProject/OpenGraphiteSample.ogp --collection-id component-main --component-id shared-ui --path _components/shared-ui.html --title 'Shared UI' --body-file shared-ui.body.html
./Scripts/ogkiln project component place SampleProject/OpenGraphiteSample.ogp --component-id ogref:component:component-main:3bgx6phkz3jv5 --name Desktop --width 1180 --height 1900
./Scripts/ogkiln project component remove SampleProject/OpenGraphiteSample.ogp --component-id <shared-ui-internal-id> --delete-file
./Scripts/ogkiln screenshot canvas SampleProject/OpenGraphiteSample.ogp --output screenshots/canvas.png
./Scripts/ogkiln screenshot page SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:2opic2blumreb --output screenshots/docs.png
./Scripts/ogkiln screenshot node SampleProject/OpenGraphiteSample.ogp --id ogref:node:1gibtxulofmr0:2opic2blumreb:fb1954bc9811 --output screenshots/doc-cli.png
./Scripts/ogkiln build SampleProject/OpenGraphiteSample.ogp --output dist
./Scripts/ogkiln page graph SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --json
./Scripts/ogkiln page graph SampleProject/OpenGraphiteSample.ogp --component-id ogref:component:component-main:3bgx6phkz3jv5 --json
./Scripts/ogkiln validate SampleProject/OpenGraphiteSample.ogp --json
./Scripts/ogkiln node query SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --type button --text-contains Docs --json
./Scripts/ogkiln node get SampleProject/OpenGraphiteSample.ogp --id ogref:node:1gibtxulofmr0:kl1xxsgkiuue:3aefceddb042 --json
./Scripts/ogkiln node style set SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --id 3aefceddb042 --var --og-gap --value 32px
./Scripts/ogkiln node text set SampleProject/OpenGraphiteSample.ogp --component-id ogref:component:component-main:3bgx6phkz3jv5 --id 57d89af48b12 --value 'Availability-ready card'
./Scripts/ogkiln node text set SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --id eace7f6a5b08 --value 'OpenGraphite'
./Scripts/ogkiln node html insert SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --id 72222bd6f11e --position prepend --html '<Header data-og-id="site-header" data-og-type="frame"></Header>'
./Scripts/ogkiln node move SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --id efeaffcc2273 --target 3aefceddb042 --position after
./Scripts/ogkiln node copy SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --id d9778be9a854 --target b01aee52375f --position append --id-prefix copy-
```

`ogkiln build` expands component instances into static Pages HTML, removes the runtime/component source links from the output, and copies `OpenGraphite.css` plus non-HTML public assets into the output directory.

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

When launched through the Debug scheme, `OPENGRAPHITE_SAMPLE_PROJECT_PATH` points Open Sample Project at `SampleProject/OpenGraphiteSample.ogp` in the checkout. The app still resolves and saves HTML through the paths declared in that `.ogp`; the repository files are touched because the sample `.ogp` points there.

When launched without that environment variable, Open Sample Project treats the bundled `SampleProject`, `public`, and `CSS` directories as a read-only seed. On first use it copies them to `~/Library/Application Support/OpenGraphite/Samples/OpenGraphiteSample/` and opens that copied `.ogp`. Existing copied samples are not overwritten.

## Current Editor Features

- Welcome screen with sample and arbitrary `.ogp` open actions
- Pages/Components sidebar with resizable, collapsible Chapter/Collection selectors and layers inside each HTML card
- WKWebView canvas using `.ogp` canvas dimensions
- DOM layer extraction from `[data-og-id]`
- Canvas and nested layer node selection
- Inspector display for tag, `data-og-id`, `data-og-type`, `data-og-layout`, `data-og-role`
- Inspector editing for common `--og-*` CSS variables with direct HTML write-back

## Standalone HTML

`public/index.html` references `../CSS/OpenGraphite.css` and can be opened directly in a browser from the repository checkout.

## Development Rules

- Swift document comment guidance: `Docs/rules/DocumentCommentStandards.md`
- Swift Testing guidance: `Docs/rules/TestingStandards.md`
- Design philosophy: `Docs/specs/DesignPhilosophy.md`
- Operations TODO governance: `Docs/operations/TODO/GOVERNANCE.md`
