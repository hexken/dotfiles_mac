---
name: web-ui-text
description: >-
  Inspect, test and debug web UIs without screenshots, via text (accessibility snapshot, Playwright assertions, layout and accessibility checks). Use for any work on a web page or app UI: building it, checking a change, debugging what a page shows, or reviewing layout. Screenshots can't be used on this machine because the Netskope proxy blocks every request carrying an image.
allowed-tools: Bash(page-text *)
---

# Web UIs without screenshots

On this machine any image sent to the API is blocked, and the session is then stuck (see the `netskope-recover` skill). Browsers can still take screenshots; they just never enter the conversation. Turn what you need to know into text.

## Looking at a page

Run the app the project's usual way, then:

```
page-text <url> [--selector CSS] [--wait-for CSS] [--viewport 390x844] [--axe] [--max-lines N]
```

It prints, all as text:
- the accessibility snapshot: headings, links, buttons, form fields with their values, tables with cell text;
- console errors and warnings, uncaught exceptions, and failed requests (HTTP 4xx/5xx);
- layout problems: sideways scrolling, clipped text, controls that overlap or are off-screen;
- with `--axe`, an accessibility audit (colour contrast, missing labels, landmarks).

Use `--selector` to focus on one region when the snapshot is long. Use `--viewport 390x844` to check phone width. Use `--wait-for` for pages that render after data loads. Pages behind a login need the project's own test fixtures; use a Playwright test instead.

## Checking behaviour

Write or extend Playwright tests in the project's test suite (for the eval platform, the `e2e` pytest marker): act with `get_by_role`/`get_by_label`, then assert with `expect(...).to_have_text`, `to_be_visible`, `to_have_value`. For a one-off check, write a short Playwright script that prints text, e.g. `print(page.get_by_role("table").aria_snapshot())`. Print what matters, not whole pages.

## Checking appearance

- Geometry and style as numbers: `locator.bounding_box()`, `page.evaluate` of `getComputedStyle(...)`, `scrollWidth > clientWidth` for overflow.
- Visual regression: compare a new screenshot with a baseline the user approved, inside a test, so only "N pixels differ" reaches the conversation. Never open the images.
- Taste ("does it look right?"): ask the user. Pass `--screenshot <path>` to `page-text`, give the user the path, and ask them to describe what they see.

## Rules

- Never Read, attach or request an image or PDF. Never use a screenshot or zoom action in any browser or computer-use tool; a PreToolUse hook denies them anyway.
- Claude in Chrome's text tools (`read_page`, `get_page_text`, `find`) are fine for exploring a live page. Prefer `page-text` and Playwright scripts for anything else: it isn't verified whether its click actions attach screenshots to their results.
- If a request is blocked anyway (`403 Your IT Admin has blocked this request`), use `netskope-recover`.
