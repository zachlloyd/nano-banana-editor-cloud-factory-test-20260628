# Tech spec: Guided editing workflow with presets and iterative history

Companion to [`PRODUCT.md`](./PRODUCT.md). Issue: [#3](https://github.com/zachlloyd/nano-banana-editor-cloud-factory-test-20260628/issues/3). Researched at commit `a1a42b25d288772192b660429ef90c4861cf5f38`.

## Context
The app is a single-page Next.js (App Router) client component plus one API route. There is no global state library, no router-based navigation, and no persistence — all editing state is React `useState` in one component.

- [`src/app/page.tsx` @ a1a42b2](https://github.com/zachlloyd/nano-banana-editor-cloud-factory-test-20260628/blob/a1a42b25d288772192b660429ef90c4861cf5f38/src/app/page.tsx) — the entire UI and editing state.
  - `ImageHistoryItem` interface (lines 6-10): `{ image: string; prompt: string; timestamp: number }`.
  - State hooks (lines 13-19): `selectedImage`, `selectedFile`, `instructions`, `isSubmitting`, `submitMessage`, `imageHistory`, `responseText`.
  - `revertToHistoryImage` (lines 29-48): **truncates** history with `prev.slice(0, index)` — this is the "git reset" behavior PRODUCT.md replaces (invariant 8).
  - `handleSubmit` (lines 62-124): posts `FormData` to `/api/process-image`, on success pushes the previous image to `imageHistory` (lines 90-98), swaps `selectedImage`/`selectedFile` to the result (lines 101-106), clears `instructions`.
  - Instruction input (lines 181-189) and submit button (lines 201-209) — where preset chips attach.
  - History strip (lines 224-255): a `fixed` bottom bar mapping `imageHistory` to clickable thumbnails keyed by `item.timestamp`.
- [`src/app/api/process-image/route.ts` @ a1a42b2](https://github.com/zachlloyd/nano-banana-editor-cloud-factory-test-20260628/blob/a1a42b25d288772192b660429ef90c4861cf5f38/src/app/api/process-image/route.ts) — `POST` handler calling Gemini `gemini-2.5-flash-image`, returns `{ generatedImage, responseText, originalImageSize }`.

This feature is **frontend-only**. The API route already accepts an arbitrary image + instruction per call and is stateless, which is exactly what a branchable version tree needs — no API change is required. See `PRODUCT.md` for all user-visible behavior.

## Proposed changes
All changes are in `src/app/page.tsx` (optionally split into small components/modules under `src/app/`). No backend, no new dependencies.

### 1. Version tree state model (replaces linear `imageHistory`)
Introduce an explicit node model instead of an append/truncate array:

```ts path=null start=null
interface ImageVersion {
  id: string;            // stable unique id (crypto.randomUUID())
  parentId: string | null; // null for the root upload
  image: string;         // data URL
  prompt: string | null; // null for the root; the prompt that produced this version otherwise
  timestamp: number;
}
```

State becomes:
- `versions: Record<string, ImageVersion>` (or `ImageVersion[]`) — every node in the tree.
- `currentVersionId: string | null` — the selected/editing base (drives the main preview).
- Keep `instructions`, `isSubmitting`, `submitMessage`, `responseText`, `selectedFile`.

Derive the displayed image from `versions[currentVersionId].image` rather than a separate `selectedImage` source of truth, to keep the preview and tree in sync (invariants 7-12).

### 2. Edit submission creates a child (invariants 7, 9, 19, 22)
In `handleSubmit`, on success: create a new `ImageVersion` with `parentId = currentVersionId`, the submitted `prompt`, and the returned image; add it to `versions`; set `currentVersionId` to the new node. Do **not** mutate or remove siblings. On failure: leave `versions` and `currentVersionId` untouched and preserve `instructions` (change from today, which already preserves it). The `selectedFile` sent to the API continues to come from the current version's data URL via the existing `dataURLtoFile` helper.

### 3. Replace `revertToHistoryImage` with non-destructive selection (invariant 8, 12)
Replace the truncating revert with `selectVersion(id)` that only sets `currentVersionId`, clears `instructions`/`responseText`, and rebuilds `selectedFile` from that version's image. No `slice`.

### 4. Preset chips (invariants 1-6)
Add a static preset list (id, label, starter prompt template) rendered as chips near the instruction field, shown only when a version is selected. Clicking a chip sets `instructions` to its template and marks it active (`activePresetId` state); editing the text or submitting clears `activePresetId`. Presets are pure client config — recommend a small `presets.ts` module so wording is easy to tune.

### 5. History view with branch structure (invariants 10, 11, 13, 14)
Evolve the bottom strip to convey parent/child structure. Minimum viable: group/indent by branch or render in tree order with a parent indicator; highlight `currentVersionId`; key by `version.id` (not timestamp, since branches can share timestamps closely). Keep it `overflow-x-auto` and non-blocking (invariant 27). The root node appears labeled as the original upload.

### 6. Compare view (invariants 16-18)
Add a compare affordance for any non-root version that shows `versions[parentId].image` (before) and the node's `image` (after) plus the node's prompt. Implement as a lightweight modal/overlay toggled by `compareVersionId` state; closing restores the normal view with selection intact. Disabled/absent when `parentId === null`.

### 7. New-upload resets the tree (invariant 25)
`handleImageUpload` creates a fresh root `ImageVersion` (`parentId: null`), resets `versions` to just that node, sets it current, and clears messages. Optional discard-confirmation is an open product question, not built by default.

## Testing and validation
There is currently no test framework in the repo (`package.json` scripts: `dev`, `build`, `start`, `lint`). Recommended validation, in order of cost:

- **Lint/build gates (every change):** `npm run lint` and `npm run build` must pass.
- **Manual / scripted UI verification** mapped to `PRODUCT.md` invariants:
  - Presets (1-6): each chip populates editable text without auto-submitting; active state clears on edit/submit; chips hidden before upload, shown after.
  - Branching history (7-9, 12, 24): edit A→B, select A, edit A→C; assert B and C both persist and descend from A; assert selecting a node never deletes others (regression guard against the old `slice` behavior).
  - Failure handling (15, 22): force an API error; assert no version added, selection unchanged, instructions preserved.
  - Compare (16-18): before/after shows parent vs node; disabled on root.
  - Reset (25, 26): new upload yields a single root; root remains recoverable until reset.
  - Concurrency (20): submit disabled while in flight; chips/history selection cannot start a second request.
- **Optional automated coverage (recommended if tests are introduced):** add React Testing Library + Vitest/Jest unit tests for the pure tree helpers (`addChild`, `selectVersion`, `resetTree`) and preset application, since these encode the invariants most prone to regression. This would also require adding a `test` script and dev dependencies — call out as a small setup cost in the implementation PR.

## Risks and mitigations
- **Memory growth:** every version stores a full base64 data URL in memory; long sessions with many branches grow the heap. Acceptable for a demo; mitigate later with thumbnail downscaling or a version cap if needed (follow-up).
- **State-shape migration:** moving from `imageHistory[]`/`selectedImage` to a version map touches most of `page.tsx`. Mitigate by deriving the preview from `currentVersionId` and keeping helpers pure and unit-testable.
- **`next/image` with data URLs:** the main preview uses `next/image` while the history strip already uses plain `<img>` (lines 236-240). Keep history thumbnails as `<img>` to avoid `next/image` data-URL/loader friction; no change needed there.

## Follow-ups
- Cross-reload persistence via `sessionStorage`/`localStorage` (PRODUCT.md open question) — deferred from v1.
- Compare across arbitrary versions and discard-confirmation on new upload — pending product decisions.
- Thumbnail downscaling / version cap for memory.

## Parallelization
Not proposed. The work is concentrated in a single file (`src/app/page.tsx`) with one shared state model; splitting it across parallel agents would create overlapping edits and merge conflicts that outweigh any wall-clock savings. A single agent should implement the state-model change first, then presets, history view, and compare in sequence on one branch.
