Below is a **Product Requirements Document (PRD)** for **Bron (iOS)**, written in a way that engineering, design, and agent logic can all execute against. I’ve structured it so each **PR (pull request / milestone)** has **explicit subtasks**, since that’s how you like to drive execution.

I assume:

* **Claude** is the deep agent reasoning engine
* iOS is native (Swift / SwiftUI)
* Server returns **UI Recipes + style tokens**, never raw UI
* Personalization is subtle, structural-first

---

# PRD: Bron — Deep Agents for Everyone (iOS)

## 1. Product Overview

**Bron** is an iOS application that provides users with personal AI agents (“Brons”) capable of working on tasks in the background.
Brons interact through chat but advance tasks by **requesting structured input via generated UI components**, not by relying on predefined task complexity levels.

The system emphasizes:

* Task progression via UI Needs
* Safe execution (no destructive actions)
* Subtle personalization
* Clear visibility into what each Bron is doing

---

## 2. Target User

**Primary Persona**

* College students
* Well-educated
* Disposable income
* High cognitive load, low time
* Comfortable delegating work if trust + transparency exist

---

## 3. Core Concepts

### 3.1 Bron

A Bron is:

* A Claude-powered agent
* Assigned to one active task at a time
* Capable of background execution
* Represented as an entry in `BronListView`

### 3.2 Task

A task progresses via states, **not complexity**.

**Task States**

* Draft
* NeedsInfo (blocked by missing input)
* Planned
* Ready
* Executing
* Waiting
* Done
* Failed

### 3.3 UI Need (Key Mechanism)

Instead of “complexity,” Bron generates **UI Recipes** when it requires structured information to proceed.

---

## 4. Views

### 4.1 BronListView

Shows all Brons currently working on background tasks.

Each row displays:

* Bron name + avatar
* Task title
* Status pill
* Progress summary
* Last activity timestamp
* Primary quick action (Open / Provide Info / Execute)

### 4.2 BronDetailView

Chat-based interaction with a single Bron:

* Message timeline
* Composer + adaptive suggestion row
* Inline UI Recipe rendering
* Collapsible Task Drawer

---

## 5. Functional Requirements

### FR-01: Chat Interaction

* User can text a Bron
* Bron responds via natural language
* Bron may update task state silently

### FR-02: Task Creation & Categorization

* Bron detects task intent
* Creates or updates a task
* Assigns category (Admin, Creative, School, etc.)

### FR-03: UI-Driven Task Progression

* When missing info exists, Bron generates a UI Recipe
* UI Recipe rendered natively in chat
* Task remains blocked until input is provided or deferred

### FR-04: Background Task Execution

* Brons continue working while user navigates away
* Task state updates reflected in BronListView

### FR-05: Plan Mode

* Tasks can enter “Planned” state
* Bron generates step lists
* User can edit steps or save them as a Skill

### FR-06: Skill System

* User can save a task’s steps as a Skill
* Skills can be edited
* Skills can be applied to future tasks

### FR-07: Execute Task

* Execute button only enabled when safe
* Execution generates drafts/artifacts
* Explicit user approval required before any external action

### FR-08: Status Spreadsheet

* Table view of all tasks
* Columns: Task | Category | Status | Next Action | Waiting On | Updated | Execute

### FR-09: Notifications

* Bron notifies user when input is required
* Notification links directly to the UI Recipe

### FR-10: Personalization

* Chat UI subtly adapts based on:

  * User preferences
  * Task category
  * Session behavior

---

## 6. Non-Functional Requirements

* No destructive actions (delete/overwrite/move)
* Secrets remain on-device
* UI generation + render < 5 seconds
* Deterministic UI rendering (no free-form layouts)

---

## 7. Out of Scope

* Messaging other users
* Social feeds
* Multi-user collaboration

---

# 8. Technical Architecture (High Level)

**Client (iOS)**

* SwiftUI
* UI Recipe renderer
* Local personalization profile
* Secure storage (Keychain)

**Server**

* Task orchestration
* Claude agent interface
* UI Recipe generation
* No secret storage

**Claude (Agent Layer)**

* Task reasoning
* UI Need identification
* Plan generation
* Natural language responses

---

# 9. Pull Request Plan

## PR-01: Core Data Models

**Goal:** Establish canonical task, Bron, and UI Need structures.

**Subtasks**

1. Define Task schema + states
2. Define BronInstance schema
3. Define Skill schema
4. Define UI Recipe schema
5. Local persistence layer (CoreData / SQLite)

---

## PR-02: Claude Agent Integration

**Goal:** Enable deep-agent reasoning via Claude.

**Subtasks**

1. Claude API integration
2. Prompt contract (task + context + style tokens)
3. Response parsing (message, UI Recipe, state updates)
4. Error handling + retries
5. Agent sandboxing (no destructive instructions)

---

## PR-03: BronDetailView (Chat)

**Goal:** Build chat interface with task awareness.

**Subtasks**

1. Message list UI
2. Composer + suggestion row
3. Inline UI Recipe renderer
4. Task Drawer UI
5. Execute button gating logic

---

## PR-04: UI Recipe Rendering Engine

**Goal:** Deterministic, safe UI generation.

**Subtasks**

1. Whitelist UI components
2. SwiftUI renderers per component
3. Schema validation
4. Action dispatch (provide info / confirm / defer)
5. Performance optimization (<5s)

---

## PR-05: BronListView

**Goal:** Active Brons dashboard.

**Subtasks**

1. ActiveBronCard UI
2. Sorting by urgency/state
3. Quick action buttons
4. Empty states
5. Auto-dismiss completed Brons

---

## PR-06: Background Execution Engine

**Goal:** Allow Brons to work asynchronously.

**Subtasks**

1. Background task runner
2. State transitions
3. Progress reporting
4. Interrupt handling (NeedsInfo)
5. Resumption logic

---

## PR-07: Plan Mode

**Goal:** Structured task planning.

**Subtasks**

1. PlanBuilder UI Recipe
2. Step list editor
3. Task → Planned state transition
4. Plan persistence
5. Step reordering & editing

---

## PR-08: Skill System

**Goal:** Reusable, user-defined workflows.

**Subtasks**

1. Save task as Skill
2. Skill editor UI
3. Apply Skill to new task
4. Parameter injection
5. Versioning support

---

## PR-09: Personalization Engine

**Goal:** Subtle adaptive UI behavior.

**Subtasks**

1. On-device personalization profile
2. Preference inference logic
3. Style token generation
4. UI token → visual mapping
5. User controls / reset

---

## PR-10: Notifications & UX Polish

**Goal:** Reliable user engagement.

**Subtasks**

1. NeedsInfo notifications
2. Deep-link to UI Recipe
3. Quiet hours support
4. Copy/tone personalization
5. Accessibility audit

---

## 10. Success Metrics

* Time from task creation → Ready
* Number of UI Need rounds per task
* Execute Task conversion rate
* User-reported trust/confidence
* Task abandonment rate

