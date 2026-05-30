# OpenGraphite

OpenGraphite is a macOS SwiftUI design editor that treats HTML as the editable source of truth, not as an export artifact. Edits made in `OpenGraphite.app` are reflected directly in the opened HTML file, and that HTML can be used as the web deliverable.

## Artifacts

- `OpenGraphite.app`: macOS SwiftUI app generated from `project.yml`
- `CSS/OpenGraphite.css`: distributable CSS library for `data-og-*` and `--og-*`
- `SampleProject/OpenGraphiteSample.ogp`: sample project file
- `public/index.html`: standalone OpenGraphite introduction page
- `project.yml`: XcodeGen source of truth
- `Docs/Architecture.md`: design notes

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

## Current Editor Features

- Welcome screen with sample and arbitrary `.ogp` open actions
- Pages/Layers sidebar
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
