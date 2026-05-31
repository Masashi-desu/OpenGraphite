# OpenGraphite

OpenGraphite is a macOS SwiftUI design editor that treats HTML as the editable source of truth, not as an export artifact. Edits made in `OpenGraphite.app` are reflected directly in the opened HTML file, and that HTML can be used as the web deliverable.

## Artifacts

- `OpenGraphite.app`: macOS SwiftUI app generated from `project.yml`
- `CSS/OpenGraphite.css`: distributable CSS library for `data-og-*` and `--og-*`
- `OpenGraphite.contract.json`: machine-readable `data-og-*` and `--og-*` contract
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

OpenGraphite does not use class names as the style source of truth. Tag names represent semantic components, `data-og-*` stores editor metadata, CSS variables store design values, and `OpenGraphite.css` provides the rendering rules.

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

Inspect and edit project-registered OpenGraphite HTML with `ogkiln`. The CLI edits only pages registered under chapters in the target `.ogp`; use `current` to target the project currently opened by `OpenGraphite.app`.

```bash
./Scripts/ogkiln project inspect SampleProject/OpenGraphiteSample.ogp --json
./Scripts/ogkiln project current --json
./Scripts/ogkiln project page create SampleProject/OpenGraphiteSample.ogp --page-id docs --path docs.html --title 'OpenGraphite Docs' --body-file docs.body.html --x 2960 --y 0
./Scripts/ogkiln project page add SampleProject/OpenGraphiteSample.ogp --page-id legacy --path legacy.html --x 4440 --y 0
./Scripts/ogkiln project page place SampleProject/OpenGraphiteSample.ogp --page-id docs --x 3040 --y 0
./Scripts/ogkiln screenshot canvas SampleProject/OpenGraphiteSample.ogp --output screenshots/canvas.png
./Scripts/ogkiln screenshot page SampleProject/OpenGraphiteSample.ogp --page-id docs --output screenshots/docs.png
./Scripts/ogkiln screenshot node SampleProject/OpenGraphiteSample.ogp --page-id docs --id doc-cli --output screenshots/doc-cli.png
./Scripts/ogkiln page graph SampleProject/OpenGraphiteSample.ogp --page-id home --json
./Scripts/ogkiln validate SampleProject/OpenGraphiteSample.ogp --json
./Scripts/ogkiln node query SampleProject/OpenGraphiteSample.ogp --page-id home --type button --text-contains Docs --json
./Scripts/ogkiln node get SampleProject/OpenGraphiteSample.ogp --page-id home --id hero --json
./Scripts/ogkiln node style set SampleProject/OpenGraphiteSample.ogp --page-id home --id hero --var --og-gap --value 32px
./Scripts/ogkiln node text set SampleProject/OpenGraphiteSample.ogp --page-id home --id title --value 'OpenGraphite'
./Scripts/ogkiln node html insert SampleProject/OpenGraphiteSample.ogp --page-id home --id page --position prepend --html '<Header data-og-id="site-header" data-og-type="frame"></Header>'
./Scripts/ogkiln node move SampleProject/OpenGraphiteSample.ogp --page-id home --id footer --target hero --position after
./Scripts/ogkiln node copy SampleProject/OpenGraphiteSample.ogp --page-id home --id card --target card-list --position append --id-prefix copy-
```

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

Create a local release configuration:

```bash
cp .env.example .env
```

Then edit `.env` for your Developer ID / notarization credentials and run:

```bash
./Scripts/release_dmg.zsh
```

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
- Chapters/Pages/Layers sidebar
- WKWebView canvas using `.ogp` canvas dimensions
- DOM layer extraction from `[data-og-id]`
- Canvas and Layer node selection
- Inspector display for tag, `data-og-id`, `data-og-type`, `data-og-layout`, `data-og-role`
- Inspector editing for common `--og-*` CSS variables with direct HTML write-back

## Standalone HTML

`public/index.html` references `../CSS/OpenGraphite.css` and can be opened directly in a browser from the repository checkout.

## Development Rules

- Swift document comment guidance: `Docs/rules/DocumentCommentStandards.md`
- Swift Testing guidance: `Docs/rules/TestingStandards.md`
- Design philosophy: `Docs/specs/DesignPhilosophy.md`
- Operations TODO governance: `Docs/operations/TODO/GOVERNANCE.md`
