# Field Deployment Scene — Integration Guide

## What this does

When the user scrolls the **Field Deployment** section into view (≥45% visible), the floating SVG pedestal:

1. **Stops its fairy-drift** animation
2. **Flies across the screen** to a specific landing spot on the illustrated street corner
3. **Shrinks from 140×320px → 44×100px** to match the scene's scale
4. **Docks** and begins a gentle idle bob, becoming "part of" the illustration
5. **Pedestrians react** — one figure walks toward the button curiously
6. When docked, pressing it logs **"PRESS #N RECORDED"** in a HUD overlay
7. **Scrolling away** reverses everything — the pedestal lifts out, scales back up, and resumes floating

---

## How to integrate into your existing `index.html`

### 1. Add the CSS

Copy these blocks into your existing `<style>`:

```css
/* ── FIELD DEPLOYMENT SCENE ── */
.field-section { position: relative; padding: 2rem 0 3rem; }

.field-header { text-align: center; margin-bottom: 1.5rem; }
.field-header h2 {
  font-family: "Fraunces", Georgia, serif;
  font-size: clamp(1.6rem, 3vw, 2.6rem);
  margin: 0; line-height: 1.1;
}
.field-header p {
  color: var(--muted); margin: 0.4rem 0 0;
  font-size: 1rem; max-width: 50ch; display: inline-block;
}

.scene-wrap {
  position: relative;
  border: 1px solid var(--line);
  border-radius: var(--radius-lg);
  overflow: hidden;
  background: linear-gradient(180deg, #c8ddf0 0%, #e4ddd0 55%, #d5cfc2 100%);
  box-shadow: var(--shadow);
  aspect-ratio: 16 / 7;
  max-height: 520px;
}
.scene-wrap svg { display: block; width: 100%; height: 100%; }

.scene-status {
  position: absolute; bottom: 0.8rem; left: 50%;
  transform: translateX(-50%);
  font-family: "IBM Plex Mono", monospace;
  font-size: 0.72rem; color: rgba(255,255,255,0.85);
  background: rgba(26,30,40,0.7);
  backdrop-filter: blur(8px);
  padding: 0.35rem 0.8rem; border-radius: 999px;
  white-space: nowrap; opacity: 0;
  transition: opacity 500ms ease; pointer-events: none;
}
.scene-status.show { opacity: 1; }

.field-caption {
  text-align: center; margin-top: 1rem;
  font-family: "IBM Plex Mono", monospace;
  font-size: 0.78rem; color: #8a8577;
}
```

And add these docking transition states to your existing `.pedestal-float` styles:

```css
.pedestal-float.docking {
  transition: transform 1200ms cubic-bezier(0.34, 1.2, 0.64, 1),
              width 1200ms cubic-bezier(0.34, 1.2, 0.64, 1),
              height 1200ms cubic-bezier(0.34, 1.2, 0.64, 1),
              filter 800ms ease;
  pointer-events: none;
}
.pedestal-float.docked {
  transition: transform 200ms ease, filter 300ms ease;
  pointer-events: none;
  filter: drop-shadow(0 6px 12px rgba(22,28,38,0.2))
          drop-shadow(0 2px 6px rgba(143,23,23,0.15));
}
.pedestal-float.undocking {
  transition: transform 900ms cubic-bezier(0.34, 1.2, 0.64, 1),
              width 900ms cubic-bezier(0.34, 1.2, 0.64, 1),
              height 900ms cubic-bezier(0.34, 1.2, 0.64, 1),
              filter 600ms ease;
}
```

### 2. Add the HTML

Place the `<section class="field-section">` block (with its full street scene SVG) somewhere in your page's `<main class="stack">`, ideally **after** the Research Divisions panel and **before** the Participate panel. Copy the entire `field-section` from the demo file.

### 3. Add the JavaScript

Merge into your existing script. The key new systems are:

- **`dockButton()` / `undockButton()`** — handles the fly-in/fly-out animation
- **`getDockScreenPos()`** — maps the SVG landing coordinates to screen pixels
- **`IntersectionObserver`** — triggers dock/undock on scroll
- **`startDockedBob()`** — gentle idle motion when docked
- **`animateCuriosity()`** — moves pedestrian figures toward the button
- **`walkPeople()`** — ambient walking animation loop

The float loop (`tickFloat`) already has guards:
```javascript
if (isDocked || isDocking || isUndocking) return;
```
So it won't fight with the docking animation.

### 4. Wire the press counter

When the button is pressed while docked, also fire your existing lab press:

```javascript
// Inside the pedestal click handler, after the docked check:
if (isDocked) {
  document.getElementById("pressBtn").click();
  // This feeds the waveform, entropy, intervals, etc.
}
```

---

## Tuning

### Landing position
The button lands at SVG coordinate **(500, 345)** in the 960×420 viewBox. To move it:

```javascript
// In getDockScreenPos():
x: offX + 500 * scale  // ← change 500 to shift horizontal
y: offY + 345 * scale  // ← change 345 to shift vertical
```

The `landingSpot` ellipse in the SVG should match:
```html
<ellipse id="landingSpot" cx="500" cy="345" .../>
```

### Docked size
```javascript
var dockedSize = { w: 44, h: 100 };
```
Increase for a more prominent street presence, decrease for deeper immersion.

### Dock/undock timing
- Dock fly-in: `1200ms` (the CSS transition + the `setTimeout(1250)`)
- Undock fly-out: `900ms` (CSS transition + `setTimeout(950)`)
- IntersectionObserver threshold: docks at `0.45`, undocks below `0.15`

### People behavior
The walking pedestrians use a simple `requestAnimationFrame` loop. Person 2 (the one near the button) walks closer during `animateCuriosity()`:

```javascript
person2El.style.transform = "translate(508px, 318px)";  // closer to button
```

You could expand this to have multiple people queue up, or add speech bubbles.

---

## SVG Scene Structure

```
viewBox="0 0 960 420"

├── Sky gradient
├── Clouds (3 ellipses)
├── Buildings (5 buildings with windows, signs, awnings)
│   ├── Tall left building
│   ├── Mid building (blue-grey)
│   ├── Corner shop ("CAFÉ & BOOKS")
│   ├── Right building
│   └── Far right building
├── Sidewalk (gradient + paving lines)
├── Road (with dashed center line)
├── Street furniture
│   ├── Lamppost
│   ├── Tree (trunk + foliage clusters)
│   ├── Bench
│   ├── Bike rack
│   └── Trash bin
├── Pedestrians (#person1, #person2, #person3)
└── Landing spot marker (hidden until dock)
```

To modify the scene: edit the SVG directly. Buildings are simple `<rect>` + window grids. Add more pedestrians by duplicating the person groups. Add a café terrace, a dog, pigeons — whatever sells the street life.

---

## Mobile

On screens <768px, the scene switches to `aspect-ratio: 16/9` for more vertical space. The pedestal shrinks to 100×230px normally, so the docked size stays proportional. You may want to adjust `dockedSize` for small screens:

```javascript
var isMobile = window.innerWidth < 768;
var dockedSize = isMobile ? { w: 30, h: 68 } : { w: 44, h: 100 };
```
