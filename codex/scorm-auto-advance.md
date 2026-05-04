# SCORM Course Player Auto-Advance via Browser Console

## Objective

Automate slide advancement in timer-gated SCORM course players (360Training and similar) by injecting JavaScript into the browser console. The script reads the countdown timer, waits for expiration, clicks the enabled navigation button, and repeats. Quiz slides require manual intervention.

## Inputs

- Browser with developer tools (F12) — Chrome, Firefox, Edge
- Active course session in a SCORM-based training platform
- Element IDs for: countdown timer, enabled-state navigation button(s), disabled-state navigation button(s)

## Procedure

### 1. Open the Console

Press `F12` to open developer tools. Select the **Console** tab. Type `allow pasting` and press Enter. This is required once per session before any script can be pasted.

### 2. Identify the Timer Element

Training platforms disable right-click. Use the console to locate the countdown timer:

```javascript
document.querySelectorAll('*').forEach(el => {
  if (el.children.length === 0 && el.innerText && el.innerText.match(/^\d+:\d+$/))
    console.log(el.tagName, el.id, el.className, el.innerText.trim());
});
```

If no results appear, the timer may be inside an iframe:

```javascript
document.querySelectorAll('iframe').forEach(f => {
  try {
    f.contentDocument.querySelectorAll('*').forEach(el => {
      if (el.children.length === 0 && el.innerText && el.innerText.match(/^\d+:\d+$/))
        console.log('IFRAME:', el.tagName, el.id, el.className, el.innerText.trim());
    });
  } catch(e) {
    console.log('Cross-origin iframe — inaccessible from parent console');
  }
});
```

Record the element ID of the active countdown. On 360Training, this is `id="timer"`.

### 3. Identify the Navigation Button

Locate elements containing "Next" (or "Continue", adjust regex):

```javascript
document.querySelectorAll('*').forEach(el => {
  if (el.innerText && el.innerText.match(/^Next$/i) && el.children.length === 0)
    console.log(el.tagName, el.id, el.className, el.outerHTML.substring(0, 200));
});
```

Training platforms frequently use separate DOM elements for enabled and disabled button states rather than toggling the `disabled` attribute. Identify both:

| 360Training Element ID | State | Meaning |
|:---|:---|:---|
| `PlaybuttonEnText` | Visible when timer = 0 | Content slide, ready to advance |
| `PlaybuttonDsText` | Visible when timer > 0 | Content slide, waiting |
| `NextQuestionButtonEnText` | Visible after answer selected | Quiz slide, ready to advance |
| `NextQuestionButtonDsText` | Visible before answer selected | Quiz slide, waiting for input |

### 4. Determine the Click Target

The visible text element is typically a `<span>` inside a clickable parent (`<a>`, `<button>`, `<div>`). Clicking the span does nothing. Identify the parent:

```javascript
['PlaybuttonEnText', 'NextQuestionButtonEnText'].forEach(id => {
  const el = document.getElementById(id);
  if (el) console.log(id, '-> parent:', el.parentElement.tagName,
    el.parentElement.id, el.parentElement.className,
    el.parentElement.outerHTML.substring(0, 300));
});
```

On 360Training, the click target is the parent `<a href="javascript:;">` element.

### 5. Confirm Visibility Detection

Verify which elements are visible on a content slide while the timer is running:

```javascript
['PlaybuttonEnText', 'PlaybuttonDsText',
 'NextQuestionButtonEnText', 'NextQuestionButtonDsText'].forEach(id => {
  const el = document.getElementById(id);
  if (el) {
    const parent = el.parentElement;
    console.log(id,
      'visible:', parent.offsetWidth > 0,
      'display:', getComputedStyle(parent).display,
      'visibility:', getComputedStyle(parent).visibility);
  }
});
```

Expected result on a content slide mid-timer: only `PlaybuttonDsText` parent shows `visible: true`. After timer expiry, only `PlaybuttonEnText` parent shows `visible: true`.

An element is visible when all three conditions hold: `offsetWidth > 0`, `display !== 'none'`, `visibility !== 'hidden'`.

### 6. Deploy the Auto-Advance Script

This script reads the timer value, converts to seconds, sleeps until expiry plus a random buffer (3–13 seconds), clicks the enabled button, and starts the next cycle.

```javascript
(function() {
  let clickCount = 0;

  function getTimerSeconds() {
    const el = document.getElementById('timer');
    if (!el) return 0;
    const parts = el.innerText.trim().split(':');
    return parseInt(parts[0]) * 60 + parseInt(parts[1]);
  }

  function getClickableButton() {
    for (const id of ['PlaybuttonEnText', 'NextQuestionButtonEnText']) {
      const span = document.getElementById(id);
      if (span && span.parentElement.offsetWidth > 0)
        return span.parentElement;
    }
    return null;
  }

  function cycle() {
    const secs = getTimerSeconds();
    const buffer = 3 + Math.random() * 10;

    if (secs > 0) {
      const wait = secs + buffer;
      console.log(`Timer: ${secs}s -- sleeping ${Math.round(wait)}s`);
      window._oshaTimeout = setTimeout(cycle, wait * 1000);
    } else {
      const btn = getClickableButton();
      if (btn) {
        btn.click();
        clickCount++;
        console.log(`Clicked Next (#${clickCount}) at `
          + new Date().toLocaleTimeString());
        const pause = 5 + Math.random() * 10;
        window._oshaTimeout = setTimeout(cycle, pause * 1000);
      } else {
        console.log('No enabled button -- retrying in 5s');
        window._oshaTimeout = setTimeout(cycle, 5000);
      }
    }
  }

  cycle();
  console.log('Auto-advance running. clearTimeout(window._oshaTimeout) to stop.');
})();
```

### 7. Stop the Script

```javascript
clearTimeout(window._oshaTimeout);
```

If multiple instances were accidentally started (console shows duplicate click logs), kill all timers:

```javascript
for (let i = 0; i < 10000; i++) { clearInterval(i); clearTimeout(i); }
```

This also kills the platform's own timers. Refresh the page afterward and re-paste the script.

## Verification

Successful operation produces console output in the following pattern:

```
Auto-advance running. clearTimeout(window._oshaTimeout) to stop.
Timer: 348s -- sleeping 352s
Clicked Next (#1) at 1:01:19 PM
Timer: 112s -- sleeping 115s
Clicked Next (#2) at 1:03:19 PM
```

Each cycle should show one timer read and one click. Multiple clicks per cycle or clicks without intervening timer waits indicate a problem (see Failure Patterns).

The page must visibly advance to the next slide after each click log entry.

## Failure Patterns

### `.click()` reports success but page does not advance

**Cause:** The click event is landing on the wrong DOM element. The `<span>` containing button text does not have the event handler; the parent `<a>` or `<div>` does.

**Resolution:** Click `element.parentElement` instead of the element directly. If this fails, dispatch a full mouse event sequence:

```javascript
function realClick(el) {
  el.dispatchEvent(new MouseEvent('mousedown', {bubbles: true}));
  el.dispatchEvent(new MouseEvent('mouseup', {bubbles: true}));
  el.dispatchEvent(new MouseEvent('click', {bubbles: true}));
}
```

If mouse events also fail, check for a `javascript:` href on the `<a>` tag and call the function directly, or search for exposed global navigation functions:

```javascript
Object.keys(window)
  .filter(k => typeof window[k] === 'function')
  .filter(k => /next|advance|navigate|submit/i.test(k))
  .forEach(k => console.log(k));
```

### Script clicks continuously without waiting for timer

**Cause:** The Next button is not disabled while the timer runs. The platform uses visibility toggling (separate enabled/disabled elements) rather than the `disabled` attribute.

**Resolution:** Do not check for button availability. Instead, read the timer value and sleep for the full duration before attempting a click. This is the approach used in the working script above.

### False positive quiz detection

**Cause:** The page contains `<input type="radio">`, `<select>`, or elements with `class="question"` in the persistent page chrome, not just on quiz slides. Generic selectors match on every slide.

**Resolution:** Use platform-specific element IDs for quiz detection rather than generic input type selectors. On 360Training, detect quiz slides by checking whether `NextQuestionButtonDsText` (or its parent) is visible.

### Timer reads NaN

**Cause:** The timer element ID changed between slides, or the text format does not match `MM:SS`.

**Resolution:** Re-run the timer identification query from Step 2. Adjust the `split(':')` parsing if the format is `HH:MM:SS` or `M:SS`.

### Multiple script instances running simultaneously

**Cause:** The script was pasted multiple times without stopping the previous instance. Each paste creates a new independent `setTimeout` chain.

**Resolution:** Always run `clearTimeout(window._oshaTimeout)` before pasting the script again. If multiple instances are already running, use the nuclear kill (`for` loop clearing all timer IDs), refresh the page, and paste once.

### Cross-origin iframe blocks element access

**Cause:** The course content iframe is served from a different domain than the course player shell.

**Resolution:** Identify the iframe source URL:

```javascript
document.querySelectorAll('iframe').forEach(f => console.log(f.src));
```

Navigate directly to that URL and run the script in that context.

### Timer pauses when tab loses focus

**Cause:** The SCORM player uses the Page Visibility API to detect tab focus loss.

**Resolution (preferred):** Run the training in a separate browser window alongside your work window. Both windows maintain independent focus state.

**Resolution (fallback):** Override the Visibility API before running the auto-advance script:

```javascript
Object.defineProperty(document, 'hidden', {value: false, writable: false});
Object.defineProperty(document, 'visibilityState', {value: 'visible', writable: false});
document.dispatchEvent(new Event('visibilitychange'));
```

This does not work on all platforms.

## Adaptation to Other Platforms

The script requires four platform-specific values:

| Parameter | How to Identify | 360Training Value |
|:---|:---|:---|
| Timer element | Step 2 query | `document.getElementById('timer')` |
| Timer text format | Inspect timer element text | `MM:SS`, parsed with `split(':')` |
| Enabled button ID(s) | Steps 3-5 queries | `PlaybuttonEnText`, `NextQuestionButtonEnText` |
| Click target | Step 4 parent inspection | `span.parentElement` (an `<a>` tag) |

### Video-based platforms (KnowBe4, Proofpoint SAT)

These use video duration as the timer. Replace the timer-reading logic with a video `ended` event listener:

```javascript
const video = document.querySelector('video');
if (video) {
  video.addEventListener('ended', () => {
    setTimeout(() => {
      // find and click next button
    }, 3000 + Math.random() * 5000);
  });
}
```

Some platforms allow `video.playbackRate = 2` to double playback speed.

### React/Angular enterprise platforms (Workday Learning, SuccessFactors)

Standard `.click()` calls and `dispatchEvent` frequently fail on these platforms. Locate exposed global navigation functions (Step 3 failure resolution) or inspect the React component tree via React DevTools.

## Persistence Across Page Reloads

The console script does not survive page navigation. For platforms that reload the page between slides, use a Tampermonkey userscript:

```javascript
// ==UserScript==
// @name         Auto-Advance Training
// @namespace    http://tampermonkey.net/
// @version      1.0
// @description  Auto-clicks Next when timer expires
// @match        https://player.360training.com/*
// @grant        GM_notification
// ==/UserScript==

(function() {
  'use strict';
  setTimeout(() => {
    // Insert cycle() function and dependencies here
  }, 5000);
})();
```

Adjust the `@match` pattern for the target platform.

## Security Notes

- The script runs in the context of the authenticated session. It does not transmit credentials or session tokens externally.
- SCORM completion data is recorded server-side per-slide. A page refresh does not lose progress.
- Console-injected scripts are cleared on page refresh and leave no persistent artifacts.
- Some platforms log interaction timing server-side. The random delay buffer (3-13 seconds) reduces the likelihood of pattern detection but does not eliminate it.
- Tampermonkey userscripts persist across sessions and should be disabled or removed after course completion.

## Recon Reference

Diagnostic queries for mapping an unfamiliar course player. Run these in order.

### All buttons

```javascript
document.querySelectorAll(
  'button, input[type="button"], input[type="submit"], a.btn, [role="button"]'
).forEach(el => {
  console.log(el.tagName, el.id || '(no id)', el.className,
    el.innerText.trim().substring(0, 30),
    'visible:', el.offsetWidth > 0, 'disabled:', el.disabled);
});
```

### All timer-like text

```javascript
document.querySelectorAll('*').forEach(el => {
  if (el.children.length === 0 && el.innerText && el.innerText.match(/\d+:\d+/))
    console.log(el.tagName, el.id || '(no id)', el.className, el.innerText.trim());
});
```

### All iframes

```javascript
document.querySelectorAll('iframe').forEach((f, i) => {
  console.log(`iframe[${i}]:`, f.id || '(no id)', f.src || '(no src)');
  try { console.log('  accessible:', !!f.contentDocument); }
  catch(e) { console.log('  cross-origin blocked'); }
});
```

### Global navigation functions

```javascript
Object.keys(window)
  .filter(k => typeof window[k] === 'function')
  .filter(k => /next|advance|navigate|submit|forward|continue/i.test(k))
  .sort()
  .forEach(k => console.log(k));
```

### jQuery presence and event inspection

```javascript
if (window.jQuery) {
  console.log('jQuery', jQuery.fn.jquery);
  // Replace selector with target element
  console.log(jQuery._data(jQuery('#btnNext')[0], 'events'));
} else {
  console.log('No jQuery');
}
```
