---
name: opengraphite-css-contract
description: Use when helping users author, review, debug, or transform HTML that uses OpenGraphite.css, data-og-* attributes, --og-* CSS variables, layouts, roles, and reusable design snippets.
---

# OpenGraphite CSS Contract

Use this skill when an agent needs to help a general OpenGraphite user write or fix HTML that is rendered by `OpenGraphite.css`.

## Audience

This is user-facing context for people who consume `OpenGraphite.css` in HTML documents. Assume the user is authoring standalone HTML and CSS, not modifying OpenGraphite itself.

If the user provides their own copy or version of `OpenGraphite.css`, inspect that file and prefer the actual rules in front of you. If no stylesheet is provided, use the public contract below.

When the repository contains `OpenGraphite.contract.json`, treat it as the machine-readable source for known `data-og-*` values, roles, layouts, and `--og-*` variables. Use the prose below to explain the contract, but prefer the JSON file for validation-oriented work.

Explain the CSS contract directly from attributes, variables, and examples. Do not require implementation files or build tools to answer normal usage questions.

## Core Model

OpenGraphite documents are ordinary HTML. `OpenGraphite.css` renders elements by reading:

- semantic tag names chosen by the author;
- `data-og-*` attributes for OpenGraphite structure and variants;
- inline `--og-*` CSS variables for design values;
- optional component master HTML in the project `components` segment and `<og-instance>` references in pages;
- standard CSS values such as lengths, colors, shorthands, gradients, `min()`, `max()`, and `clamp()`.

Class names may be used by the surrounding website, but do not make class names the OpenGraphite editing contract. Prefer `data-og-*` and `--og-*` for content that should remain understandable to OpenGraphite-aware tools.

## Basic Setup

Include the stylesheet and mark editable/rendered elements with `data-og-type`:

```html
<link rel="stylesheet" href="OpenGraphite.css">

<main
  data-og-id="page"
  data-og-type="page"
  data-og-layout="vertical"
  data-og-role="page-preview"
  style="--og-gap:32px; --og-padding:48px;">
  <HeroTitle
    data-og-id="title"
    data-og-type="text"
    style="--og-font-size:56px; --og-font-weight:760; --og-line-height:1;">
    OpenGraphite
  </HeroTitle>
</main>
```

For component references, keep masters in component canvas HTML and reference them from pages with a component source link plus the optional runtime:

```html
<link rel="stylesheet" href="OpenGraphite.css">
<link rel="opengraphite-components" href="_components/design-system.html">
<script src="OpenGraphite.runtime.js" defer></script>
```

## Attributes

- `data-og-id`: stable element identifier. Use unique IDs when tools or people need to refer to specific nodes.
- `data-og-type`: primitive rendering type. Known values are `page`, `frame`, `text`, `button`, and `image`.
- `data-og-layout`: child layout mode. Known values are `vertical`, `horizontal`, and `absolute`.
- `data-og-role`: reusable visual or semantic variant. Known roles include `page-preview`, `landing-hero`, `primary-button`, `secondary-button`, `card`, `eyebrow`, and `muted`.
- `data-og-component`: component identifier used by a master root or an `<og-instance>`.
- `data-og-component-kind="master"`: marks a component master subtree in the Components segment.
- `data-og-variant`: optional component or role variant.
- `data-og-slot`: slot target inside a component master. The element's existing contents are fallback content.
- `data-og-part`: stable part name inside a component. Use `root` on the master root when runtime ID mapping should preserve the instance ID.
- `data-og-hidden="true"`: hides the element.
- `data-og-locked="true"`: marks the element as locked and changes the cursor.
- `data-og-selected="true"` and `data-og-editing="true"` are UI/session states. Runtime expansion can also add `data-og-expanded`, `data-og-generated`, `data-og-component-error`, `data-og-host-id`, `data-og-instance-source`, `data-og-source-component`, `data-og-source-instance`, and `data-og-slot-origin`. Do not include runtime attributes in hand-authored source HTML unless you are explicitly debugging runtime output.

## Types

- `page` and `frame`: block containers with relative positioning.
- `text`: block text with `--og-font-size`, `--og-font-weight`, `--og-line-height`, `--og-letter-spacing`, and `--og-text-align`.
- `button`: inline-flex action element with centered content, default gap, padding, radius, and pointer cursor.
- `image`: media frame with hidden overflow. Direct `img` and `video` children fill the frame and use `--og-object-fit`.

## Layouts

- `vertical`: `display:flex`, column direction, `--og-align` default `stretch`, `--og-justify` default `flex-start`, and `--og-gap` default `0`.
- `horizontal`: `display:flex`, row direction, `--og-align` default `center`, `--og-justify` default `flex-start`, and `--og-gap` default `0`.
- `absolute`: parent becomes a positioned block; direct `data-og-type` children are absolutely positioned with `--og-x` and `--og-y`.

When any element has inline `--og-x` or `--og-y`, `OpenGraphite.css` also gives it relative positioning with `left` and `top` offsets.

On screens up to 760px wide, horizontal layouts stack vertically, buttons become full width, and `page-preview` uses `--og-padding:24px`.

## CSS Variables

Global theme variables usually live on `:root`:

- `--og-page-background`
- `--og-text-color`
- `--og-muted-color`
- `--og-accent`
- `--og-accent-foreground`

Common box and layout variables:

- `--og-width`, `--og-height`
- `--og-min-width`, `--og-min-height`, `--og-max-width`
- `--og-flex`
- `--og-margin`, `--og-padding`
- `--og-gap`, `--og-align`, `--og-justify`
- `--og-x`, `--og-y`

Appearance variables:

- `--og-foreground`
- `--og-background`
- `--og-border`
- `--og-radius`
- `--og-shadow`

Text variables:

- `--og-font-size`
- `--og-font-weight`
- `--og-line-height`
- `--og-letter-spacing`
- `--og-text-align`

Media and transform variables:

- `--og-object-fit`
- `--og-scale-x`, `--og-scale-y`
- `--og-transform-origin`

Editing helper variables:

- `--og-edit-width`
- `--og-edit-min-height`

## Roles

- `page-preview`: gives a page-like full viewport preview using `--og-background` and `--og-foreground` with theme fallbacks.
- `landing-hero`: clips overflow for hero compositions.
- `primary-button`: uses accent color defaults and a colored shadow.
- `secondary-button`: uses a light background and subtle border defaults.
- `card`: uses a light background, subtle border, and default shadow.
- `eyebrow`: accent-colored uppercase small text.
- `muted`: uses the muted theme color.

Roles are reusable variants, not unique identifiers. Multiple elements can share the same role.

## Authoring Rules

- Keep design values as standard CSS strings in `--og-*` variables.
- Prefer shorthand values such as `--og-padding:14px 20px`, `--og-border:1px solid rgba(...)`, and `--og-shadow:0 18px 44px rgba(...)`.
- Use CSS functions directly when useful, for example `--og-width:min(100%,560px)` or `--og-background:linear-gradient(...)`.
- Avoid invented decomposed variables such as `--og-padding-top`, `--og-border-color`, or `--og-shadow-blur` unless the user's stylesheet explicitly supports them.
- Do not replace the OpenGraphite contract with classes. Classes can coexist, but `data-og-*` and `--og-*` should remain understandable on their own.
- For generated snippets, include enough `data-og-id` values to make the structure easy to inspect and edit.
- Put reusable multi-node components in component canvas HTML registered under `.ogp` `components[]`; keep pages lightweight with `<og-instance>` references when runtime or build expansion is desired.
- Use `OpenGraphite.runtime.js` for lightweight source-first projects. Use `ogkiln build` when static deployment, SEO, or no-JS delivery matters.
- Slot overrides in pages use the standard `slot` attribute, while master targets use `data-og-slot`.

## Common Patterns

Vertical section:

```html
<Section
  data-og-id="features"
  data-og-type="frame"
  data-og-layout="vertical"
  style="--og-gap:20px; --og-padding:32px;">
  ...
</Section>
```

Horizontal action row:

```html
<Actions
  data-og-id="actions"
  data-og-type="frame"
  data-og-layout="horizontal"
  style="--og-gap:12px; --og-align:center;">
  <a data-og-id="primary" data-og-type="button" data-og-role="primary-button">Start</a>
  <a data-og-id="secondary" data-og-type="button" data-og-role="secondary-button">Learn more</a>
</Actions>
```

Image frame:

```html
<Preview
  data-og-id="preview"
  data-og-type="image"
  data-og-role="card"
  style="--og-width:min(100%,640px); --og-height:360px; --og-radius:18px;">
  <img src="preview.png" alt="Preview" style="--og-object-fit:cover;">
</Preview>
```

Absolute placement:

```html
<Canvas data-og-id="canvas" data-og-type="frame" data-og-layout="absolute">
  <Badge
    data-og-id="badge"
    data-og-type="text"
    style="--og-x:24px; --og-y:32px;">
    New
  </Badge>
</Canvas>
```

Component master:

```html
<FeatureCard
  data-og-id="feature-card-master"
  data-og-type="frame"
  data-og-layout="vertical"
  data-og-component="feature-card"
  data-og-component-kind="master"
  data-og-part="root"
  style="--og-gap:16px; --og-padding:28px; --og-radius:6px;">
  <FeatureCardTitle
    data-og-id="feature-card-title"
    data-og-type="text"
    data-og-slot="title"
    style="--og-font-size:28px; --og-font-weight:800;">
    Fallback title
  </FeatureCardTitle>
  <FeatureCardBody
    data-og-id="feature-card-body"
    data-og-type="text"
    data-og-role="muted"
    data-og-slot="body">
    Fallback body
  </FeatureCardBody>
</FeatureCard>
```

Component instance:

```html
<og-instance
  data-og-id="availability-card"
  data-og-type="frame"
  data-og-component="feature-card">
  <span slot="title">Availability-ready card</span>
  <span slot="body">Pages keep references while the master stays reusable.</span>
</og-instance>
```

## Debugging

When rendering looks wrong:

1. Confirm `OpenGraphite.css` is loaded with the expected URL.
2. Confirm the element has `data-og-type`; most base rules depend on it.
3. Confirm layout is on the parent with `data-og-layout`, not only on the children.
4. Confirm inline variables are valid CSS declarations and end with semicolons.
5. For image/video sizing, put the media element directly inside a `data-og-type="image"` wrapper.
6. For absolute layout, set `data-og-layout="absolute"` on the parent and `--og-x` / `--og-y` on direct child elements.
7. Check responsive behavior at 760px and below if horizontal layouts or buttons changed shape.
8. For `<og-instance>`, confirm the page has a valid `rel="opengraphite-components"` link, `OpenGraphite.runtime.js` is loaded when using runtime expansion, and the master has matching `data-og-component` plus `data-og-component-kind="master"`.
9. If deployment output is wrong but runtime preview is correct, verify `ogkiln build <project.ogp|current> --output <dir>` and inspect the generated static HTML.
