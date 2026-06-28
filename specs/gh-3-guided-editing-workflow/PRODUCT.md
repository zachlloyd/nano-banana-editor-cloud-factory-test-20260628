# Guided editing workflow with presets and iterative history

Issue: [zachlloyd/nano-banana-editor-cloud-factory-test-20260628#3](https://github.com/zachlloyd/nano-banana-editor-cloud-factory-test-20260628/issues/3)

## Summary
Make iterative image editing easier by (1) offering preset edit intents that help users phrase effective prompts and (2) replacing the current truncating, linear history with a branchable version tree the user can navigate, compare, and continue editing from. The existing upload + free-text prompt + result flow is preserved; presets and richer history are additive.

## Problem
The editor works well for one-off prompts, but users do not know how to phrase effective edits and have no structured way to iterate. Today, reverting to an earlier image (`revertToHistoryImage`) discards every later edit ("git reset" behavior), so users cannot keep two branches of an edit or compare a result against the version it came from.

## Goals
- Help users start an edit without prompt-engineering knowledge, via preset edit intents.
- Let users iterate over multiple rounds and freely return to any earlier version without losing later work.
- Let users compare a result against the version it was edited from.
- Keep the app approachable: the upload + single prompt flow remains the default, and no backend persistence is added.

## Non-goals
- Backend persistence, accounts, or sharing. History lives in the browser only.
- A multi-step wizard or saved/user-authored prompt templates. Presets are fixed, single-tap starting points, not a guided multi-screen flow.
- Durable storage across full page reloads is deferred (see Open questions). Reloading may clear history.
- Editing more than one image project at a time, or comparing arbitrary unrelated versions.

## Figma
Figma: none provided.

## Behavior

### Presets
1. When an image is selected and ready to edit, the user sees a small set of preset edit intents presented as tappable chips above or beside the free-text instruction field. Presets are drawn from common tasks named in the roadmap: at minimum **Remove background**, **Replace background**, **Style transfer**, **Cleanup / restore**, **Remove object**, and **Enhance**.
2. Tapping a preset chip populates the instruction field with a concrete, editable starter prompt for that intent (e.g. "Remove the background and make it transparent"). It does not immediately submit. The user can edit the populated text before submitting.
3. Presets that need a target (e.g. "Replace background", "Remove object") populate a prompt with an obvious placeholder the user is expected to complete (e.g. "Replace the background with `___`"). Submitting a prompt that still contains an unfilled placeholder is allowed (the model receives the literal text); the app does not block submission on placeholder content.
4. Selecting a preset chip visually indicates the active selection until the user submits or edits the text. Editing the text or submitting clears the active-chip indication. Selecting a different chip replaces the instruction text with that chip's starter prompt.
5. Presets are always available whenever editing is available, including on the initial uploaded image and on any version reached via history. Presets never appear before an image is selected.
6. The free-text instruction field remains fully functional with or without using a preset; a user can ignore presets entirely and the experience matches today's behavior.

### Version model and history
7. Editing produces a tree of versions, not a linear stack. The originally uploaded image is the root version. Each successful edit creates a new child version whose parent is the version that was being edited, recording the prompt used and a timestamp.
8. Reverting to (selecting) an earlier version does **not** delete later versions. The selected version becomes the current editing base; previously created versions remain in the tree and stay reachable.
9. Submitting an edit while an earlier version is selected creates a new child of that version, producing a branch. Both the older branch and the new branch remain in the history.
10. The history view shows every version created in the session, with enough structure that the user can tell which version descends from which (e.g. branch grouping or parent indication). Each version shows a thumbnail and the prompt that produced it (the root shows it is the original upload).
11. The currently selected version is visually distinguished in the history view from all other versions.
12. Selecting any version in the history view makes it the current image: the main preview updates to that version, and the next edit will branch from it. The instruction field is cleared on selection.
13. Each version's prompt label is shown truncated in the history strip but the full prompt is available on hover/focus (title or tooltip), matching today's affordance.
14. History is empty until the first successful edit; before that only the root image exists and no history view is shown. After the first edit, the history view is visible.
15. History reflects only successful edits. A failed or cancelled edit does not add a version and does not change the selected version.

### Compare
16. For any non-root version, the user can compare it against its parent (the version it was edited from) in a before/after view showing both images and the prompt that produced the after image.
17. The compare affordance is reachable from the current result and/or from a selected version in history. Closing compare returns to the normal editing view with the same version still selected.
18. The root version has no parent, so the compare affordance is absent or disabled for it.

### Editing flow, states, and edge cases
19. The happy path is unchanged in spirit: select image → (optionally tap a preset) → adjust/enter instructions → submit → result becomes the new current version and is appended to history as a child of the prior version.
20. While an edit is in flight, the submit control shows a processing state and is disabled, preset chips and history selection are disabled (or queue is prevented) so a second edit cannot start until the first resolves, matching the single-request model today.
21. On a successful edit, the instruction field is cleared, any active preset selection is cleared, the new version is selected, and a success message is shown.
22. On a failed edit (network error, API error, missing/invalid input), an error message is shown, the previously selected version remains current and selected, the instruction text is preserved so the user can retry, and no version is added to history.
23. Submitting with empty instructions is blocked with a clear message, as today. Tapping a preset counts as providing instructions once its text is in the field.
24. Re-running the same prompt on the current version (without changes) is allowed and creates another child version; the app does not dedupe identical edits.
25. Uploading a new image starts a fresh tree: the new upload becomes a new root and prior history is cleared from view. (If a confirmation before discarding existing history is desired, that is an open question, not required behavior.)
26. The original uploaded image is always recoverable as the root version as long as the session/history persists.
27. The layout remains responsive and approachable; the history view must not obscure the primary preview or the instruction field, and must scroll independently when there are many versions.

## Open questions
- **Persistence across reloads:** Should the version tree survive a full page reload within the same browser (e.g. via `sessionStorage`/`localStorage`), or is in-memory-only acceptable for the demo? Recommendation: in-memory only for v1, with cross-reload persistence deferred.
- **Discard confirmation on new upload (invariant 25):** Should uploading a new image prompt for confirmation when an edit history exists?
- **Compare scope (invariant 16):** Is parent/child before/after sufficient, or do users need to compare any two arbitrary versions? Recommendation: parent/child only for v1.
- **Preset set:** Final list and exact starter-prompt wording for each preset chip.
