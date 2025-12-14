Got it — thanks for the correction.
Below is a **self-contained visual style guide** (textual + diagrammatic) that your team can actually *build from*, without relying on external imagery. Think of this as a **broadcast-style design bible** for Bron.

---

# BRON — VISUAL STYLE GUIDE (v1.0)

**Theme:** Championship Gravity · ESPN / NBA Energy · Teammate Presence
**Core Constraint:** High-contrast black & white UI, color concentrated in Bron avatar, deep red as rare “commit ink”

---

## 1. VISUAL NORTH STAR

**Mental image (internal):**

> A championship broadcast control room.
> Black and white screens.
> Condensed headlines.
> One glowing presence at the desk.

The UI should feel:

* Decisive
* Editorial
* Heavy
* Focused

Not:

* Playful
* Chatty
* Pastel
* Decorative

---

## 2. COLOR SYSTEM

### 2.1 UI Palette (Default)

```
BLACK        #000000   Primary background, emphasis
WHITE        #FFFFFF   Primary surface, text contrast

GRAY-900     Near-black text
GRAY-700     Secondary text
GRAY-500     Metadata
GRAY-300     Dividers
GRAY-150     Subtle surfaces
GRAY-050     Background separation
```

**Rules**

* UI must function at 100% clarity in pure grayscale
* No gradients
* No shadows for decoration (only for separation if needed)

---

### 2.2 Accent Color: DEEP RED (Rare)

**Meaning:** Commitment · Importance · Finality
**NOT:** Error · Warning · Failure

Usage constraints:

* Max **one instance per screen**
* Never fill large areas
* Never paired with error copy

Allowed:

* Primary commit button outline
* Thin underline
* Left-edge rule
* Single keyword emphasis

---

### 2.3 Avatar Color Ownership

```
UI            → monochrome
Deep red      → intent / commitment (rare)
Avatar        → color, glow, expression
```

The avatar is the **only expressive color surface**.

---

## 3. TYPOGRAPHY SYSTEM

### 3.1 Font Stack

```
DISPLAY FONT (Impact)
- Bebas Neue   (free)
  OR
- Tungsten / Knockout (licensed)

UTILITY FONT (Body/UI)
- IBM Plex Sans
  (SF Pro acceptable fallback)
```

---

### 3.2 Typographic Roles

#### Display (Impact / Broadcast)

* ALL CAPS
* Short phrases only
* Condensed
* Heavy weight
* Tight leading

Used for:

* Screen titles
* Task titles
* Status headers
* Section labels

#### Utility (Body / Control)

* Sentence case
* Calm, readable
* Neutral

Used for:

* Chat messages
* Descriptions
* Forms
* Metadata
* Buttons

---

### 3.3 Type Scale (Example Tokens)

```
DISPLAY / XL   44–48 pt   (Screen titles)
DISPLAY / L    32–36 pt   (Task titles)
DISPLAY / M    18–22 pt   (STATUS, SECTION)

BODY / L       17–19 pt
BODY / M       15–17 pt
META / S       12–13 pt
```

Tracking:

* Display caps: +1 to +3
* Body: default

---

## 4. LAYOUT LANGUAGE

### 4.1 Hierarchy Philosophy

Hierarchy is created by:

1. Size
2. Weight
3. Spacing
4. Alignment

**Never by color alone.**

---

### 4.2 Structural Motifs

* Strong horizontal rules
* Clear section breaks
* Modular panels
* Editorial spacing

Think “broadcast rundown,” not “chat bubbles.”

---

## 5. CORE SCREENS (TEXTUAL MOCKUPS)

### 5.1 BronListView — *Active Roster*

```
ACTIVE BRONS
────────────────────────────────

◉  SUBMIT RECEIPT
   NEEDS INFO
   Step 2/5 • 3m ago

◉  PODCAST SETUP
   EXECUTING
   Drafting outline

◉  WEATHER CHECK
   READY
   Awaiting execution
```

Typography:

* Section title → DISPLAY/M
* Task title → DISPLAY/M
* Status → DISPLAY/M or strong utility
* Metadata → BODY/M or META

Avatar:

* Left-aligned
* Only colored element

---

### 5.2 BronDetailView — *Chat Workspace*

```
[Chat timeline — calm, neutral, utility font]

User:
Can you submit the receipt?

Bron:
I can do that. I need the receipt photo and purchase details.
```

No bubbles with personality.
Feels like notes between teammates.

---

### 5.3 Task Drawer — *Control Panel*

```
SUBMIT RECEIPT
NEEDS INFO
────────────────────────

• Receipt photo
• Amount
• Date
• Merchant

[ EXECUTE TASK ]   ← deep red outline
```

Rules:

* Task title + status = DISPLAY
* Everything else = utility
* Deep red only appears here (if anywhere)

---

## 6. UI RECIPE CARDS

Visual style:

* Flat
* Tool-like
* Minimal copy
* Strong alignment

```
RECEIPT DETAILS
────────────────────────
[ Upload receipt ]
[ Amount ______ ]
[ Date ________ ]

[ CONTINUE ]   [ SKIP FOR NOW ]
```

No decorative icons.
No color unless it’s the commit action.

---

## 7. MOTION & FEEDBACK

### Motion Philosophy

* Motion communicates **state**
* Stillness = confidence
* No bounce
* No playful easing

### Examples

* State change → quick crossfade / slide
* Completion → subtle settle
* Avatar motion → micro only

---

## 8. BRON AVATAR VISUAL ROLE

The avatar:

* Is the **only expressive element**
* Carries warmth and life
* Reflects task state, not emotion

UI stays sharp and silent.
Avatar breathes.

---

## 9. ERROR STATES (IMPORTANT)

Errors are:

* Calm
* Grayscale
* Explicit

```
Something didn’t go through.
Nothing was changed.
You can retry or adjust the task.
```

**Never red. Never alarming.**

---

## 10. VISUAL BRAND TESTS

Before shipping, ask:

1. *If this were printed in black ink on white paper, would it still work?*
2. *Is color doing work that layout or type should do instead?*
3. *Does this feel like a broadcast panel or a playful app?*

If it feels playful → revise.

---

## ONE-LINE SUMMARY

**Bron looks like a championship control room
with one living teammate at the desk.**

---

If you want next, I can:

* Turn this into a **tokenized design system** (JSON / Swift enums)
* Create a **Figma page structure** (frames + naming)
* Write a **PR visual checklist** to enforce this rigor
* Produce **SwiftUI mock components** using these rules
