# 🕹️ Browser Console Automation: A Field Guide

> ***How to make tedious, timer-gated, click-heavy web training do itself — using nothing but F12 and JavaScript.***

---

Born from rage-automating an OSHA 10 course on 360Training[^1]. Applies to **any** timer-gated, slide-based, click-to-advance web interface: compliance training, onboarding modules, corporate LMS, you name it.

[^1]: A SCORM-based course player that forces you to stare at a countdown timer, then click "Next" — for *hours*.

---

## Table of Contents

- [1. Getting In](#1-getting-in)
- [2. Recon: Finding Elements Blind](#2-recon-finding-elements-blind)
- [3. The Click Problem](#3-the-click-problem)
- [4. Timer Strategies](#4-timer-strategies)
- [5. The Working Script (v5)](#5-the-working-script-v5)
- [6. Quiz Detection](#6-quiz-detection)
- [7. Keeping the Tab Alive](#7-keeping-the-tab-alive)
- [8. Emergency Procedures](#8-emergency-procedures)
- [9. Recon Cheat Sheet](#9-recon-cheat-sheet)
- [10. Troubleshooting](#10-troubleshooting)
- [11. Tampermonkey](#11-tampermonkey)
- [12. Platform-Specific Notes](#12-platform-specific-notes)
- [Quick Reference](#quick-reference)

---

## 1. Getting In

### The 3-Step Ritual

- [x] Press **F12** (or `Ctrl+Shift+J` / `Cmd+Option+J`)
- [x] Click the **Console** tab
- [x] Type `allow pasting` and hit Enter *(one-time per session)*

> **Note**
> Browsers block pasting into the console as a security measure. You **must** type `allow pasting` manually before any script will work. Every. Single. Time.

### Console Commands You'll Actually Use

| Action | Command | Notes |
|:---|:---|:---|
| Run a script | Paste → `Enter` | That's it |
| Stop a `setInterval` | `clearInterval(id)` | Pass the stored variable |
| Stop a `setTimeout` | `clearTimeout(id)` | Same deal |
| ☢️ Kill **ALL** timers | See [Nuclear Option](#kill-everything-nuclear-option) | Last resort |
| Clear console output | `Ctrl+L` or `clear()` | Cosmetic only |
| Re-run last command | `↑` arrow → `Enter` | Handy for retrying |

---

## 2. Recon: Finding Elements Blind

> **The problem:** Training platforms *love* disabling right-click, which blocks normal Inspect Element. The console is your workaround.

### 🔍 Find Elements by Visible Text

You can *see* a button or timer on screen but can't click-to-inspect it. Search the DOM by text content instead:

```javascript
document.querySelectorAll('*').forEach(el => {
  if (el.innerText && el.innerText.match(/^Next$/i) && el.children.length === 0)
    console.log(el.tagName, el.id, el.className, el.type,
      el.outerHTML.substring(0, 200));
});
```

<details>
<summary><strong>📋 Common search regexes (click to expand)</strong></summary>

| What you're looking for | Regex | Example match |
|:---|:---|:---|
| Timer `MM:SS` | `/^\d+:\d+$/` | `04:53` |
| Timer `HH:MM:SS` | `/^\d+:\d+:\d+$/` | `01:04:53` |
| Next / Continue button | `/^Next$/i` | `NEXT` |
| Submit button | `/^Submit$/i` | `Submit` |
| Any bare number | `/^\d+$/` | `42` |
| Percentage | `/^\d+%$/` | `75%` |

</details>

### 🖼️ Check Inside Iframes

SCORM players and training platforms ***love*** iframes. If the above finds nothing:

```javascript
document.querySelectorAll('iframe').forEach(f => {
  try {
    f.contentDocument.querySelectorAll('*').forEach(el => {
      if (el.innerText && el.innerText.match(/^Next$/i)
        && el.children.length === 0)
        console.log('IFRAME:', el.tagName, el.id, el.className,
          el.outerHTML.substring(0, 200));
    });
  } catch(e) {
    console.log('⛔ IFRAME blocked by cross-origin policy');
  }
});
```

> **⚠️ Cross-origin error?** The iframe content is on a different domain. Find its URL with:
> ```javascript
> document.querySelectorAll('iframe').forEach(f => console.log(f.src));
> ```
> Navigate to that URL directly and run your scripts *there*.

### 🔗 Inspect the Parent Chain

This is **critical**. Buttons are frequently wrapped — the visible text is in a `<span>`, but the *actual click handler* lives on a parent `<a>` or `<div>`:

```
<a href="javascript:;" class="btn ctrl">        ← 🎯 THIS is what you click
  <span id="PlaybuttonEnText">NEXT</span>       ← ❌ NOT this
  <i class="glyphicon glyphicon-triangle-right"></i>
</a>
```

Find the parent:

```javascript
['PlaybuttonEnText', 'NextQuestionButtonEnText'].forEach(id => {
  const el = document.getElementById(id);
  if (el) console.log(id, '→ parent:',
    el.parentElement.tagName, el.parentElement.id,
    el.parentElement.className,
    el.parentElement.outerHTML.substring(0, 300));
});
```

*Replace the IDs with whatever you found in the previous step.*

### 👁️ Check Visibility / Enabled State

Training platforms often maintain **separate DOM elements** for enabled vs. disabled states, toggling visibility:

```javascript
['PlaybuttonEnText', 'PlaybuttonDsText'].forEach(id => {
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

> **An element is truly visible when ALL THREE are true:**
> 1. `offsetWidth > 0`
> 2. `display` is **not** `none`
> 3. `visibility` is **not** `hidden`

---

## 3. The Click Problem

> ***"The console says it clicked. Nothing happened."***
>
> This is the #1 issue. Every time.

### Why `.click()` Fails

| Cause | What's happening |
|:---|:---|
| **Wrong element** | You're clicking a `<span>` but the handler is on the parent `<a>` |
| **Framework binding** | jQuery/React/Angular attached handlers that `.click()` doesn't trigger |
| **Listening for mouse events** | Handler wants `mousedown` → `mouseup` → `click` sequence |
| **State gate** | Handler checks a CSS class or attribute, not `disabled` property |

### The Solution Ladder

*Try in order. Stop when one works.*

---

**Level 1** — ~~Click the text~~ Click the ***parent***:

```javascript
document.getElementById('PlaybuttonEnText').parentElement.click();
```

---

**Level 2** — Full mouse event sequence:

```javascript
function realClick(el) {
  el.dispatchEvent(new MouseEvent('mousedown', {bubbles: true}));
  el.dispatchEvent(new MouseEvent('mouseup', {bubbles: true}));
  el.dispatchEvent(new MouseEvent('click', {bubbles: true}));
}
```

---

**Level 3** — jQuery trigger *(if the page uses it)*:

```javascript
if (window.jQuery) {
  console.log('jQuery version:', jQuery.fn.jquery);
  jQuery('#PlaybuttonEnText').parent().trigger('click');
}
```

---

**Level 4** — Call the function directly:

Check the element's event handlers *(Elements tab → select element → Event Listeners panel)* and bypass the DOM entirely:

```javascript
// If you find: CoursePlayerEngine.NextSlide()
CoursePlayerEngine.NextSlide();
```

---

**Level 5** — Read and execute the `href`:

```javascript
const btn = document.getElementById('PlaybuttonEnText').parentElement;
console.log(btn.href); // e.g., "javascript:goNext()"
goNext(); // call it directly
```

---

## 4. Timer Strategies

Three approaches, from simple to sophisticated.

### Strategy A: Poll Until Ready

> *Brute force. Check every N seconds. Click when available.*

```javascript
const timer = setInterval(() => {
  const btn = document.getElementById('PlaybuttonEnText');
  if (btn && btn.parentElement.offsetWidth > 0) {
    btn.parentElement.click();
    console.log('✅ Clicked at', new Date().toLocaleTimeString());
  } else {
    console.log('⏳ Waiting...');
  }
}, 5000);
window._auto = timer;
```

| ✅ Pros | ❌ Cons |
|:---|:---|
| Dead simple | Wasteful CPU |
| Works everywhere | Spams the console |
| | Predictable pattern (detectable) |

---

### Strategy B: Read Timer → Sleep → Click ⭐ *Recommended*

> *Read the countdown, convert to seconds, sleep that long + random buffer, click once.*

```javascript
function getTimerSeconds() {
  const el = document.getElementById('timer');
  if (!el) return 0;
  const parts = el.innerText.trim().split(':');
  return parseInt(parts[0]) * 60 + parseInt(parts[1]);
}

function cycle() {
  const secs = getTimerSeconds();
  const buffer = 3 + Math.random() * 10;

  if (secs > 0) {
    const wait = secs + buffer;
    console.log(`⏳ Timer: ${secs}s — sleeping ${Math.round(wait)}s`);
    window._autoTimeout = setTimeout(cycle, wait * 1000);
  } else {
    const btn = document.getElementById('PlaybuttonEnText');
    if (btn && btn.parentElement.offsetWidth > 0) {
      btn.parentElement.click();
      console.log(`✅ Clicked at ${new Date().toLocaleTimeString()}`);
      setTimeout(cycle, (5 + Math.random() * 10) * 1000);
    } else {
      console.log('⚠️ No button — retrying in 5s');
      window._autoTimeout = setTimeout(cycle, 5000);
    }
  }
}
cycle();
```

| ✅ Pros | ❌ Cons |
|:---|:---|
| One check per slide | Slightly more complex |
| Efficient — sleeps most of the time | |
| Random timing looks human | |

---

### Strategy C: MutationObserver

> *Reactive. Watches for DOM changes. Acts when button state changes.*

```javascript
const observer = new MutationObserver(() => {
  const btn = document.getElementById('PlaybuttonEnText');
  if (btn && btn.parentElement.offsetWidth > 0) {
    setTimeout(() => {
      btn.parentElement.click();
      console.log('✅ Clicked at', new Date().toLocaleTimeString());
    }, 3000 + Math.random() * 10000);
  }
});
observer.observe(document.body,
  {childList: true, subtree: true, attributes: true});
window._autoObserver = observer;
// To stop: observer.disconnect()
```

> **⚠️ Caution:** MutationObservers can fire **multiple times** for a single state change. Add a debounce guard (`let pending = false;`) for production use or you'll get rapid-fire clicks.

---

## 5. The Working Script (v5)

> *Battle-tested against 360Training's SCORM player. The one that actually works.*

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
      console.log(`⏳ Timer: ${secs}s — sleeping ${Math.round(wait)}s`);
      window._oshaTimeout = setTimeout(cycle, wait * 1000);
    } else {
      const btn = getClickableButton();
      if (btn) {
        btn.click();
        clickCount++;
        console.log(`✅ Clicked Next (#${clickCount}) at `
          + new Date().toLocaleTimeString());
        const pause = 5 + Math.random() * 10;
        window._oshaTimeout = setTimeout(cycle, pause * 1000);
      } else {
        console.log('⚠️ No enabled button — retrying in 5s');
        window._oshaTimeout = setTimeout(cycle, 5000);
      }
    }
  }

  cycle();
  console.log('🟢 v5 running. clearTimeout(window._oshaTimeout) to stop.');
})();
```

### 🔧 Adapting for Other Platforms

> Swap these pieces and the rest works as-is:

| Component | 360Training | *Your platform* |
|:---|:---|:---|
| Timer element | `getElementById('timer')` | *ID of your countdown* |
| Timer format | `MM:SS` split on `:` | *Adjust if `HH:MM:SS` etc.* |
| Enabled buttons | `PlaybuttonEnText`, `NextQuestionButtonEnText` | *Your enabled-state button IDs* |
| Click target | `span.parentElement` (the `<a>`) | *Whatever holds the handler* |

---

## 6. Quiz Detection

### Approach A: Detect & Alert *(recommended)*

Let the script **pause itself** and ping you:

```javascript
function isQuizSlide() {
  // Option 1: known quiz container
  const qc = document.getElementById('questionContainer');
  if (qc && qc.offsetWidth > 0) return true;

  // Option 2: quiz-specific button is active
  const qBtn = document.getElementById('NextQuestionButtonDsText');
  if (qBtn && qBtn.parentElement.offsetWidth > 0) return true;

  return false;
}
```

Add this to the **top** of your `cycle()` function, *before* the timer check:

```javascript
if (isQuizSlide()) {
  console.log('📝 QUIZ — your turn. Checking again in 30s.');
  if (Notification.permission === 'granted') {
    new Notification('Quiz Question!', {body: 'Answer required'});
  } else {
    Notification.requestPermission();
  }
  window._oshaTimeout = setTimeout(cycle, 30000);
  return;
}
```

> **💡 Tip:** Call `Notification.requestPermission()` early (before the first cycle) so the browser prompt appears while you're still looking at the page.

### Approach B: Detect by Button Type

If the platform uses different buttons for content vs quiz (like 360Training):

- `Playbutton*` visible → **content slide** → auto-advance ✅
- `NextQuestionButton*` visible → **quiz slide** → alert & wait ⏸️

> **⚠️ Warning:** **Avoid generic quiz detection** like searching for *any* `<input type="radio">` on the page. Training platforms often have hidden form elements in the page chrome that trigger false positives on every single slide. Ask me how I know.

---

## 7. Keeping the Tab Alive

> Many SCORM platforms **pause the timer** when the tab loses focus. Three workarounds:

### ✅ Side-by-Side Windows *(simplest)*

Don't tab away. Put the training in **one browser window** and your work in **another**, side by side. Each window keeps its own "focused" state.

### ⚡ Visibility API Override

```javascript
Object.defineProperty(document, 'hidden',
  {value: false, writable: false});
Object.defineProperty(document, 'visibilityState',
  {value: 'visible', writable: false});
document.dispatchEvent(new Event('visibilitychange'));
```

*Works on some platforms. Not all. Worth trying.*

### 🔇 Silent Audio Keepalive

Some platforms stay "active" as long as audio plays:

```javascript
const ctx = new AudioContext();
const osc = ctx.createOscillator();
const gain = ctx.createGain();
gain.gain.value = 0; // completely silent
osc.connect(gain);
gain.connect(ctx.destination);
osc.start();
// To stop: osc.stop(); ctx.close();
```

---

## 8. Emergency Procedures

### Stop Your Script

```javascript
// setTimeout-based (v5 and Strategy B)
clearTimeout(window._oshaTimeout);

// setInterval-based (Strategy A)
clearInterval(window._auto);

// MutationObserver (Strategy C)
window._autoObserver.disconnect();
```

### Kill Everything (Nuclear Option)

> *Multiple intervals spawned. Console is a wall of text. Things are clicking that shouldn't be clicking.*

```javascript
for (let i = 0; i < 10000; i++) {
  clearInterval(i);
  clearTimeout(i);
}
console.log('☠️ All timers killed');
```

> **⚠️ Caution:** This also kills the **page's own timers**. The course timer will freeze. Refresh the page afterward (`F5`), then reopen F12 and paste your script fresh.

### "I Broke the Page"

**Don't panic.** SCORM tracks completion **server-side**, per-slide. You haven't lost progress.

- [x] Refresh the page (`F5`)
- [x] Open F12 → Console
- [x] Type `allow pasting`
- [x] Paste your script
- [x] It picks up where you left off

---

## 9. Recon Cheat Sheet

> *Copy-paste diagnostics for mapping any unfamiliar page fast.*

<details>
<summary><strong>🔘 Dump All Buttons</strong></summary>

```javascript
document.querySelectorAll(
  'button, input[type="button"], input[type="submit"], a.btn, [role="button"]'
).forEach(el => {
  console.log(el.tagName, el.id || '(no id)', el.className,
    el.innerText.trim().substring(0, 30),
    'visible:', el.offsetWidth > 0,
    'disabled:', el.disabled);
});
```

</details>

<details>
<summary><strong>⏱️ Dump All Timers / Countdowns</strong></summary>

```javascript
document.querySelectorAll('*').forEach(el => {
  if (el.children.length === 0 && el.innerText
    && el.innerText.match(/\d+:\d+/))
    console.log(el.tagName, el.id || '(no id)',
      el.className, el.innerText.trim());
});
```

</details>

<details>
<summary><strong>🖼️ Dump All Iframes</strong></summary>

```javascript
document.querySelectorAll('iframe').forEach((f, i) => {
  console.log(`iframe[${i}]:`, f.id || '(no id)', f.src || '(no src)');
  try {
    console.log('  accessible:', !!f.contentDocument);
  } catch(e) {
    console.log('  ⛔ cross-origin blocked');
  }
});
```

</details>

<details>
<summary><strong>🌐 List All Global Functions</strong></summary>

Look for `goNext`, `nextSlide`, `submitAnswer`, `navigate`, `advance`:

```javascript
Object.keys(window)
  .filter(k => typeof window[k] === 'function' && !k.startsWith('_'))
  .sort()
  .forEach(k => console.log(k));
```

</details>

<details>
<summary><strong>💲 Check for jQuery</strong></summary>

```javascript
if (window.jQuery) {
  console.log('jQuery version:', jQuery.fn.jquery);
  // Inspect click handlers on a specific element:
  console.log(jQuery._data(jQuery('#someButton')[0], 'events'));
} else {
  console.log('No jQuery on this page');
}
```

</details>

---

## 10. Troubleshooting

<details>
<summary><strong>Script says "clicked" but page doesn't advance</strong></summary>

**Wrong element.** The click handler is on a parent or sibling.

1. Re-run the parent chain inspection (Section 2)
2. Try clicking different levels up: `.parentElement`, `.parentElement.parentElement`
3. Try `realClick()` from Section 3 (full mouse event sequence)
4. Try Level 4/5 from the Solution Ladder — call the underlying function directly

</details>

<details>
<summary><strong>Timer reads as NaN or undefined</strong></summary>

The timer element changed ID, or the format isn't what you're parsing.

1. Re-run the timer dump (Section 9)
2. Check: did the ID change between slides?
3. Adjust your `split(':')` logic if format is `HH:MM:SS` or `M:SS`

</details>

<details>
<summary><strong>Everything fires twice (or more)</strong></summary>

Multiple script instances running. You pasted more than once without killing the old one.

1. [Nuclear option](#kill-everything-nuclear-option)
2. Paste script **exactly once**

</details>

<details>
<summary><strong>Script stops after one cycle</strong></summary>

One of your code branches doesn't schedule the next `setTimeout`.

Every path in `cycle()` must **either**:
- Call `setTimeout(cycle, ...)` to continue, **or**
- Explicitly stop (and log that it stopped)

</details>

<details>
<summary><strong>Cross-origin iframe blocks access</strong></summary>

The content is on a different domain than the shell.

1. Find the iframe URL: `document.querySelectorAll('iframe').forEach(f => console.log(f.src))`
2. Navigate directly to that URL
3. Run your script in *that* tab's console

</details>

<details>
<summary><strong>Console clears on page navigation</strong></summary>

The platform navigates to a *new page* (not just updating in-place).

1. Enable **"Preserve log"** — gear icon in Console tab
2. Consider a **Tampermonkey userscript** instead (Section 11) — it auto-runs on every matching page load

</details>

---

## 11. Tampermonkey

> *For scripts that persist across page reloads and run automatically.*

Install [Tampermonkey](https://www.tampermonkey.net/), then create a new userscript:

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

  // Wait for page to fully load
  setTimeout(() => {
    // Paste your cycle() function and supporting code here
    // Use GM_notification() instead of new Notification() for alerts
  }, 5000);
})();
```

> **💡 Tip:** Change the `@match` URL pattern to target your specific platform. Wildcards work:
> - `https://player.360training.com/*` — 360Training only
> - `https://*.litmos.com/*` — any Litmos subdomain
> - `https://training.yourcompany.com/*` — internal LMS

---

## 12. Platform-Specific Notes

### 🎓 SCORM-Based *(360Training, Litmos, Docebo, TalentLMS)*

- Almost always use **iframes** — outer page = LMS shell, inner = course content
- Timers and nav buttons usually in **outer shell**; content and quizzes in **iframe**
- Progress tracked **server-side** via SCORM API calls — refreshing won't lose progress
- Look for global SCORM functions: `API.LMSCommit()`, `API_1484_11.Commit()`

### 🛡️ Compliance Training *(KnowBe4, Proofpoint SAT)*

- Often **video-based** — timer is the video duration, not a text countdown
- Listen for the video `ended` event instead:

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

- Some let you `video.playbackRate = 2` — ~~worth trying~~ *definitely* worth trying

### 🏢 Enterprise LMS *(Workday Learning, SuccessFactors)*

- Heavily React/Angular — standard `.click()` *rarely* works
- Use `dispatchEvent` approach (Section 3, Level 2) or find exposed global functions
- Often require VPN — make sure your connection stays stable or the session dies

---

## Quick Reference

| Task | Command |
|:---|:---|
| Open console | `F12` → Console tab |
| Enable paste | Type `allow pasting` → Enter |
| Find buttons | [Dump All Buttons](#9-recon-cheat-sheet) |
| Find timers | [Dump All Timers](#9-recon-cheat-sheet) |
| Check iframes | [Dump All Iframes](#9-recon-cheat-sheet) |
| Inspect parents | [Parent chain snippet](#-inspect-the-parent-chain) |
| Check visibility | [Visibility snippet](#️-check-visibility--enabled-state) |
| **Kill your script** | `clearTimeout(window._oshaTimeout)` |
| **Kill everything** | `for(let i=0;i<10000;i++){clearInterval(i);clearTimeout(i);}` |
| Keep tab active | Side-by-side windows or [Visibility override](#-visibility-api-override) |

---

> *"Any sufficiently boring training module is indistinguishable from a timer with extra steps."*
> — ~~Arthur C. Clarke~~ Everybody who's sat through SCORM training
