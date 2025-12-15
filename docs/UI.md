Excellent — this is the *decisive move* that separates **Bron** from “ChatGPT with a skin.”

You are explicitly saying:

> **Text is a liability.
> UI is the language.
> Reading is a last resort.**

Below is a **refined UI primitives + interaction philosophy** that hard-codes *low reading, high action* into the system, while preserving the **broadcast / NBA-weight** brand.

---

# BRON UI PRIMITIVES — LOW-READING, HIGH-ACTION (v1.1)

## Core Interaction Principle (Non-Negotiable)

> **If the user can tap, they should not type.
> If the user can scan, they should not read.
> If the UI can imply, the copy should disappear.**

Bron is not an article.
Bron is not a chat transcript.
Bron is a **control surface**.

---

## 1. TEXT IS SECONDARY — UI IS PRIMARY

### What text is allowed to do

* Label
* Clarify
* Confirm

### What text must NOT do

* Explain workflows
* Teach concepts
* Present long reasoning
* Offer multiple options inline

If Bron needs to “say a lot,” that is a **UI failure**, not a copy problem.

---

## 2. CORE LOW-READING PRIMITIVES

These are the primitives that replace “chatty explanations.”

---

## 2.1 ACTION LIST (Most Important Primitive)

**Purpose:** Replace paragraphs, suggestions, and “If you want next…”

**Appearance**

* Vertical list
* Full-width buttons
* Rectilinear
* High contrast
* Display font for labels (short)
* Utility font for optional subtext (1 line max)

**Example**

```
WHAT NEXT
────────────────────
[ ADD TO PLAN ]
[ PROVIDE INFO ]
[ EXECUTE TASK ]
[ PAUSE TASK ]
```

**Rules**

* Default interaction is **tap**
* Typing is optional, never required
* One tap = one clear intent

This is the *primary conversational mechanic*.

---

## 2.2 OPTION GRID (Fast Decisions)

**Purpose:** Replace multi-choice questions in text.

**Appearance**

* 2–4 options
* Equal visual weight
* Button or tile form
* No prose

**Example**

```
HOW SHOULD I PROCEED
────────────────────
[ DRAFT FIRST ]
[ ASK QUESTIONS ]
[ USE A SKILL ]
```

**Rules**

* No more than 4 options
* Labels must be verbs
* No explanatory paragraphs

---

## 2.3 STATUS STRIP (Replace Explanation)

**Purpose:** Tell the user what’s happening *without words*.

**Appearance**

* Single line
* Display font
* Minimal copy

**Example**

```
EXECUTING • STEP 3 OF 7
```

Instead of:

> “I’m currently working on outlining the episode and will let you know…”

---

## 2.4 INFO CHIP SET (Replace Sentences)

**Purpose:** Represent missing info, constraints, or facts.

**Appearance**

* Rectangular chips
* Grayscale
* Text-only
* Tap to resolve

**Example**

```
MISSING
[ RECEIPT ]
[ AMOUNT ]
[ DATE ]
```

Tapping a chip opens the relevant UI Recipe.

---

## 2.5 CONFIRMATION BAR (Instead of “Are you sure?” Text)

**Purpose:** Explicit commitment without explanation.

**Appearance**

* Fixed position
* Minimal copy
* One primary action
* One escape hatch

**Example**

```
READY TO SEND
[ APPROVE & SEND ]   [ CANCEL ]
```

Deep red allowed on the approve action only.

---

## 3. CHAT IS A BACKUP, NOT THE MAIN INTERFACE

### Chat rules

* 1–2 lines max by default
* Declarative, not conversational
* Never multiple paragraphs unless explicitly requested

**Good**

> “I need one thing to continue.”

**Bad**

> “To proceed with this task, I’ll need you to provide several pieces of information…”

If chat exceeds 3 lines, **you should have used UI**.

---

## 4. LISTS ARE UI, NOT TEXT

### Task steps

Never:

```
1. Upload receipt
2. Enter amount
3. Submit
```

Always:

```
STEPS
────────────────────
[ UPLOAD RECEIPT ]
[ ENTER AMOUNT ]
[ SUBMIT ]
```

Each step is a tappable UI element.

---

## 5. DEFAULT INTERACTION PATTERN (Critical)

When Bron reaches a decision point:

1. **Show state** (STATUS STRIP)
2. **Show options** (ACTION LIST or OPTION GRID)
3. **Wait**

No typing required.
No reading required.
No guessing what to do next.

---

## 6. “WHAT NEXT” IS ALWAYS A UI COMPONENT

The phrase “If you want next, I can…” is **forbidden** as text.

It must *always* be rendered as:

```
WHAT NEXT
────────────────────
[ OPTION A ]
[ OPTION B ]
[ OPTION C ]
```

This is a **hard system rule** for Claude.

---

## 7. UI RECIPE RULE UPDATE (IMPORTANT)

When Claude is about to:

* ask a question
* list options
* explain choices
* describe steps

It must:

1. Check if a UI primitive exists
2. Use it instead of text
3. Reduce copy to labels only

---

## 8. MOTION & FEEDBACK SUPPORT LOW READING

* Selected options visibly lock in
* Disabled actions are obvious
* State changes are immediate
* Avatar acknowledges action subtly

The UI should feel like:

> “I pressed it. It happened.”

---

## 9. EXAMPLE FLOW (ZERO TYPING)

User: *“Submit the receipt”*

UI:

```
SUBMIT RECEIPT
NEEDS INFO
────────────────────
[ UPLOAD RECEIPT ]
[ ENTER AMOUNT ]
[ ENTER DATE ]
```

User taps → completes fields → UI updates:

```
READY
────────────────────
[ EXECUTE TASK ]
```

No typing. No chat. No reading.

---

## 10. SYSTEM PROMPT HARD RULES (UPDATED)

Add these constraints to Claude’s system prompt:

* Prefer UI primitives over text explanations
* Never present multiple options in prose
* Always render next actions as buttons
* Minimize chat length by default
* Treat typing as optional, not required
* Optimize for tap-first workflows

**Violation of these rules = incorrect response.**

---

## ONE-SENTENCE PRODUCT MANTRA

**Bron should feel like operating a championship control panel —
not reading a smart assistant’s thoughts.**

Excellent — this is the *right* level to lock the brand in.
UI primitives are where most products quietly lose coherence. We’ll define them so **every screen feels broadcast-grade, intentional, and heavyweight**.

Below is a **foundational UI primitives spec** for **Bron**, aligned with:

* ESPN / NBA energy
* High-contrast black & white
* Condensed impact typography
* Deep red as rare “commit ink”
* Bron as a teammate, not a toy

---

# BRON UI PRIMITIVES SPEC (v1.0)

## Design Philosophy for Primitives

> **Primitives must feel structural, not decorative.**

Each primitive should look like it belongs in:

* a broadcast control room,
* a scoreboard system,
* or an internal operations dashboard.

If a primitive feels “friendly,” “soft,” or “playful,” it’s wrong.

---

## 1. SURFACES

### 1.1 Base Surface

**Purpose:** Primary background

**Appearance**

* Flat
* White or black
* No texture
* No gradients
* No elevation by default

**Rules**

* White is default reading surface
* Black used for:

  * headers
  * section breaks
  * emphasis panels
* Surface contrast comes from **adjacency**, not shadows

---

### 1.2 Panel / Section

**Purpose:** Group related content (Task Drawer, UI Recipe, list sections)

**Appearance**

* Flat
* High-contrast edge
* Rectilinear (no rounding by default)

**Construction**

* Background: white or very light gray
* Separation: thin divider line (Gray-300)
* Padding: generous, consistent

**No**

* Card shadows
* Rounded “card” metaphors
* Floating panels

---

## 2. DIVIDERS & RULES

### 2.1 Horizontal Rule (Critical Primitive)

**Purpose:** Hierarchy, separation, broadcast feel

**Appearance**

* 1px line
* Gray-300 or black
* Full width or clearly aligned

**Variants**

* Standard divider (Gray-300)
* Emphasis divider (black)
* Rare: deep red divider (editorial emphasis only)

This is one of the most important primitives for impact.

---

## 3. TYPOGRAPHIC PRIMITIVES

### 3.1 Section Header

**Purpose:** Establish hierarchy and weight

**Appearance**

* Display font
* ALL CAPS
* Tight leading
* No color (black or white only)

Example:

```
ACTIVE BRONS
```

---

### 3.2 Status Label

**Purpose:** Convey task state

**Appearance**

* Display font (M)
* ALL CAPS
* Neutral grayscale
* No icons unless necessary

Examples:

```
EXECUTING
NEEDS INFO
READY
WAITING
```

Optional:

* Thin underline
* Left-edge rule (rare deep red for blocking)

---

### 3.3 Body Copy

**Purpose:** Communication and explanation

**Appearance**

* Utility font
* Sentence case
* Calm spacing
* No personality flourishes

This includes chat messages.

---

## 4. BUTTONS

### 4.1 Primary Button (Rare)

**Purpose:** Explicit commitment

**Appearance**

* Rectangular
* No rounding or very subtle rounding
* Text-only or outline
* Deep red allowed **only here**

Example:

```
[ EXECUTE TASK ]
```

**Rules**

* Only one primary button per view
* Never used for navigation
* Never auto-triggered

---

### 4.2 Secondary Button

**Purpose:** Normal actions

**Appearance**

* Text or outline
* Grayscale only
* No fill

Example:

```
[ CONTINUE ]   [ SKIP FOR NOW ]
```

---

### 4.3 Tertiary Action

**Purpose:** Low-priority actions

**Appearance**

* Text-only
* Gray-700 or Gray-500
* No decoration

---

## 5. INPUTS

### 5.1 Text Input

**Purpose:** Structured data entry

**Appearance**

* Flat
* Single underline or thin border
* Black text
* Clear focus state (black rule)

**No**

* Floating labels
* Colorful focus rings
* Rounded pill inputs

---

### 5.2 Picker / Selector

**Purpose:** Controlled choice

**Appearance**

* Text-first
* Chevron minimal
* No color coding

Use typography + spacing, not icons.

---

### 5.3 File Upload

**Purpose:** Attach artifacts

**Appearance**

* Text button
* Optional thin outline
* No drop-zone theatrics

Example:

```
[ UPLOAD RECEIPT ]
```

---

## 6. LISTS

### 6.1 Standard List Row

**Purpose:** Display structured items (BronListView, tasks)

**Appearance**

* Rectilinear rows
* Strong alignment
* Clear vertical rhythm
* Avatar or icon at left (if applicable)

**Hierarchy**

* Title (display or strong utility)
* Status (display or utility)
* Metadata (utility, lighter)

---

## 7. CHIPS / TAGS

### 7.1 Info Chip

**Purpose:** Represent missing info, categories, filters

**Appearance**

* Rectangular
* Thin border
* Grayscale
* No color fill

Text-only preferred.

---

## 8. ICONOGRAPHY

### Philosophy

Icons are **secondary to text**.

**Rules**

* Monochrome only
* Simple, geometric
* No decorative icons
* No emoji icons

Icons should clarify, not decorate.

---

## 9. FEEDBACK STATES

### 9.1 Loading / Thinking

**Appearance**

* Textual (“Working…”)
* Optional subtle avatar animation
* No spinners unless absolutely necessary

---

### 9.2 Success

**Appearance**

* Copy confirmation
* Optional subtle haptic
* Optional avatar acknowledgment

No green checkmarks as primary signal.

---

### 9.3 Error

**Appearance**

* Neutral gray text
* Clear explanation
* Structural emphasis (spacing, rules)

**Never red. Never alarmist.**

---

## 10. MOTION PRIMITIVES

### Motion Types Allowed

* Fade
* Slide
* Subtle scale settle

### Motion Types Forbidden

* Bounce
* Elastic
* Springy overshoot
* Flashing

Motion should feel like a **broadcast cut**, not an app animation.

---

## 11. RADIUS & SHAPE RULES

* Default: square corners
* If rounding is used:

  * Very subtle
  * Consistent everywhere
* No pills unless semantically required

This reinforces seriousness and weight.

---

## 12. PRIMITIVE LINT TEST (IMPORTANT)

Every primitive must pass:

1. Would this look appropriate on a broadcast control panel?
2. Does this rely on color more than structure?
3. Could this exist in pure black ink on white paper?

If any answer is “no,” revise.

---

## ONE-SENTENCE SUMMARY

**Bron’s UI primitives are industrial, editorial, and decisive —
built from type, rules, and alignment, not decoration.**


