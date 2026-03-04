# Floating Pedestal Button Integration Guide

## What This Component Does

`button-pedestal.html` contains a self-contained floating SVG pedestal button with:

- continuous layered drift (incommensurate sine motion)
- gentle rotational wobble (about +/- 4 degrees)
- random larger position shifts every 4-11 seconds
- press animation (dome compression + glow)
- shockwave ring and sparkle burst
- sequential smooth-scroll through configured section targets

This guide explains how to merge it into the main BRB homepage (`index.html`).

---

## Files

- Source demo: `pedestal/button-pedestal.html`
- This guide: `pedestal/INTEGRATION.md`
- Target page: `index.html`

---

## Current BRB Hook (Important)

The main site now exposes a global press API:

```js
window.BRB.triggerPress(holdMs);
```

Use this instead of `document.getElementById("pressBtn").click()`.

Why: the BRB button uses pointer/touch down/up handlers and hold-duration logic. Calling `.click()` does not reliably trigger the full pathway on modern pointer-event browsers.

---

## Step 1: Copy Floating CSS

From `button-pedestal.html`, copy these style blocks into your `index.html` `<style>` section:

- `.pedestal-float`
- `.pedestal-float.pressed-glow`
- `.dome-group`, `.dome-group.pushed`
- `.shockwave`, `.shockwave.go`, `@keyframes shockExpand`
- `.sparkle`, `.sparkle.go`, `@keyframes sparkleFly`
- optional `.scroll-hint` styles
- mobile sizing rule for `.pedestal-float` (recommended)

Make sure the pedestal has `position: fixed` and `z-index` above content.

---

## Step 2: Insert HTML Near Top of `<body>`

Place these just after your ambient canvas / flash overlays and before `.shell`:

```html
<div class="shockwave" id="pedestalShockwave"></div>
<div class="scroll-hint" id="pedestalScrollHint" aria-hidden="true">...</div>
<div class="pedestal-float" id="pedestalFloat">
  <!-- full SVG from button-pedestal.html -->
</div>
```

Use the full SVG block verbatim from `button-pedestal.html`.

---

## Step 3: Add Floating Animation Script

Copy the floating logic from `button-pedestal.html`:

- state object (`baseX`, `baseY`, drift phases, shift timers)
- `animateFloat()` loop
- `spawnSparkles()`
- press handlers on the floating control

When integrating, use unique IDs:

- `pedestalFloat`
- `domeGroup`
- `pedestalShockwave`
- `pedestalScrollHint`

---

## Step 4: Wire Scroll Targets to BRB Sections

Replace demo targets with BRB page sections:

```js
var scrollTargets = [
  document.querySelector(".lab-panel"),
  document.querySelector(".panel"),          // Theoretical Framework
  document.querySelector(".methods-wrap"),   // Methodological Framework
  document.querySelector(".footer"),
  document.body
].filter(Boolean);
```

Each floating-button press should advance to the next target and loop.

---

## Step 5: Feed BRB Analytics from Floating Presses

In the floating button press completion logic (typically on pointer/touch release), call:

```js
if (window.BRB && typeof window.BRB.triggerPress === "function") {
  window.BRB.triggerPress(holdMs);
}
```

Use the measured hold duration (`holdMs`) from pedestal pointer down/up.

This keeps these systems in sync:

- live count
- inter-press intervals
- waveform (duration-sensitive)
- entropy field
- burst map

---

## Suggested Integration Pattern

Use pointer events so hold duration works on desktop and mobile:

```js
var downAt = 0;
var active = false;

pedestal.addEventListener("pointerdown", function (e) {
  if (e.pointerType === "mouse" && e.button !== 0) return;
  active = true;
  downAt = Date.now();
  dome.classList.add("pushed");
});

pedestal.addEventListener("pointerup", function () {
  if (!active) return;
  active = false;
  dome.classList.remove("pushed");
  var holdMs = Math.max(40, Date.now() - downAt);
  if (window.BRB && typeof window.BRB.triggerPress === "function") {
    window.BRB.triggerPress(holdMs);
  }
});
```

Add matching `pointercancel` cleanup.

---

## Tuning

### Anchor Position

Adjust where the button tends to live:

```js
baseX: 78, // percent viewport width
baseY: 30  // percent viewport height
```

### Drift Intensity

Increase/decrease drift amplitudes (`18`, `10`, `14`, `8`) in the sine terms.

### Shift Frequency

`nextShift = 4000 + Math.random() * 7000` controls major drift interval.

### Shift Smoothing

`* 0.008` easing factor controls shift speed:

- higher = snappier
- lower = dreamier

### Mobile Size

```css
@media (max-width: 650px) {
  .pedestal-float {
    width: 100px;
    height: 230px;
  }
}
```

---

## Integration Checklist

- Floating button appears above content and remains tappable.
- Dome compresses and effects fire on press.
- Press scrolls to next target section.
- Floating presses increment BRB counter.
- Waveform responds to hold duration from floating button.
- Rapid taps still work on iPhone/Android.
- No overlap with critical UI on small screens.
