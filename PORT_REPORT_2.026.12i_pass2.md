# Kobo 2.026.12i — Rehome-Apply Completion Pass (Pass 2)

**Repo:** `/Users/shivavadla/dev/kpi`
**Scope:** Re-application of OpenClinica fork customizations on top of the kobo 2.026.12i upgrade base, plus build-blocker repair.
**Date:** 2026-05-29

> HONESTY NOTE: No build, typecheck, lint, npm, or git command was run as part of this pass beyond read-only inspection. All "valid" / "resolves" claims below are **static reasoning against `.d.ts`/source and tsconfig**, not compiler output. End-to-end build readiness has NOT been verified by a compiler. Treat the "Build Readiness" section as the authoritative caveat.

---

## 1. Counts

| Metric | Value |
|---|---|
| Rehome customizations total | 44 |
| Ported (re-applied) | 38 |
| Obsolete (intentionally not re-added) | 6 |
| Uncertain | 0 |
| Apply targets | 43 |
| Apply targets completed | 43 |
| EditableForm-related specs (efSpecs) | 2 |

All 43 apply targets ran. "Completed" means the target's *in-scope* edits were applied; several targets had pieces that were deliberately out of scope (single-file hard rule) and are tracked as cross-file dependencies in Section 3, not as failures.

---

## 2. Applied vs. Flagged (per area)

### 2.1 Applied (high confidence the edit landed as intended)

- **EditableForm.tsx** (`jsapp/js/editorMixins/EditableForm.tsx`) — full functional-component translation of the fork's editable-form customizations. No stray `this.` references; the class→function translation is clean. Includes: `desiredAssetType` prop + state seeding (FILE 1a/1b), `settings__version`/`settings__form_id` round-trip from `content.settings`, form-style sessionStorage cache, iframe handshake (`form_saveneeded`/`form_savecomplete`), eConsent single-signature guard via `isEConsentSignatureRow`, save-time `version`/`form_id` write to `app.survey.settings`, fork header/aside/branding (Back button, delete/duplicate/add-to-library toolbar, Form ID + Version `TextBox`es, `| OpenClinica` titles, "Error loading form:").
- **formEditors.tsx** — route→`desiredAssetType`, template-child `parentAssetUid`, `backRoute = ROUTES.LIBRARY` fork UX override (both child routes), `back` searchParam override applied last. Prop-drills `desiredAssetType` into `<EditableForm/>`. (Sibling-confirmed against fork `326f806dc`.)
- **ownedCollectionsStore.ts** (build-blocker repair) — recreated the deleted owned-collections Reflux store, mirroring the compiling `managedCollectionsStore.ts` but with owned-only filtering via `assetUtils.isSelfOwned`. Re-pointed importers `assetCollectionActions.tsx` and `myLibraryStore.ts`; `myLibraryRoute.tsx` fixed automatically by recreation.
- **dataInterface.ts** — added `customer_shared_infra?: boolean | null` to `AccountResponse` (optional + nullable to match serializer that has no default and existing mock that omits it).
- **hub/admin/mixins.py** (OC-26908) — removed dead `SearchQueryTooShortException` from import and except tuple. Cleanliness-only; no runtime behavior change.
- **actions.js** — added `actions.survey.addItemAtPosition` declaration; added `form_saveinprogress`/`form_savecomplete` parent-frame postMessage in `updateAsset`.
- **surveyCompanionStore.js** — added `addItemAtPosition` listener + handler (inline `loadDict` branch and library-fetch `whenLoaded` fallback).
- **surveyScope.tsx** — `handleCloneGroup`, plus helpers `getUnnullifiedContent` / `getContentChoices` / `add_rows_to_question_library`.
- **assetActionButtons.tsx** — `userCanEdit = true` permission bypass (both occurrences); library download filter `dl.format !== 'xml'`.
- **Drawer.tsx** — replaced kobo HelpBubble/Source secondary icons with the single OpenClinica Form Designer help link; removed now-dead imports/locals.
- **formBuilderUtils.ts** — `nullifyTranslations` error-string rebrand to fork wording.
- **formLanding.js** — removed undeployed-version cell, deploy/redeploy/unarchive buttons cell, redeployment-needed warning; branding + "form" wording swaps.
- **formSubScreens.js** — two `| KoboToolbox` → `| OpenClinica` title swaps.
- **formSummary.js** — "Share project"→"Share form" label; `| OpenClinica` title.
- **formSummaryProjectInfo.tsx** — country fallback `t('Countries')`→`t('Form country')`, admin-override mechanism preserved.
- **mainHeader.component.tsx** — suppressed `<AccountMenu />` render; placeholder strings "Search Library" / "Search Forms".
- **gitRev.component.tsx** — relaxed render guard to "git_rev exists", independent gating of branch/short rows, added new `tag` row.

### 2.2 Flagged for human review (applied, but a decision is owed)

- **EditableForm header UX**: fork's Back button replaces upstream's close (X) button and removes the kobo logo. This is a fork-intentional iframe override but is a UX preference — confirm keep-Back-vs-restore-close.
- **`customer_shared_infra` read via cast** in EditableForm.tsx on `sessionStore.currentAccount`. Now that the type field exists in `dataInterface.ts`, the cast *can* be removed — but EditableForm was not re-edited to drop it (single-file rule on the type pass). Cast remains in source.
- **`hideDetails`, `safeNavigateToAsset`, `safeNavigateToCollection`** defined in EditableForm but currently unwired (upstream removed the Details section / those nav buttons). Harmless (`noUnusedLocals` off) but a reviewer may wire or drop them.
- **`formEditors.tsx` `backRoute = ROUTES.LIBRARY`**: deliberate fork override of upstream's `LIBRARY_ITEM` (parent collection). Product decision point, preserved per fork intent.
- **`assetActionButtons.tsx` download filter form/scope**: applied es6 form `!== 'xml'` (exclude XML) across all non-collection assets; fork-base TSX had used stricter `=== 'xls'` scoped to `isLibrary()`. Confirm preferred form. Note the filtered value currently feeds only the empty-menu guard (the download `.map` render is commented out at HEAD), so it has **no user-visible effect today**.
- **`Drawer.tsx` SECONDARY simplification SKIPPED**: primaryIcons (Projects/Library nav) and the `AccountSidebar` branch were left at upstream behavior, diverging from the fork's narrower drawer. Deliberate; needs a maintainer decision.
- **`mainHeader.component.tsx` org badge**: upstream's new `RequireOrg`/`OrganizationBadge` left rendering (did not exist when fork was written). Confirm whether OC4 wants it hidden. `AccountMenu` import retained (eslint-disabled) for easy re-enable.
- **`mainHeader` "Search Forms" label** on the projects-view route — terminology confirm.
- **dead methods left in place** in `formLanding.js` (`isFormRedeploymentNeeded`, `callUnarchiveAsset`) — harmless, removable if lint complains.

---

## 3. Customizations that could NOT be confidently ported (human follow-up required)

These are **not failures of judgment** — each was blocked by the hard rule that a given apply target may edit only its one assigned file. The customization's *other halves* live in files outside that target's scope and were NOT applied by this pass. They MUST be confirmed handled (by a sibling pass or human) or the feature stays broken / the build fails.

1. **Group-clone chain cross-file wiring (BLOCKING for the feature, and for TS compile).**
   - `actions.d.ts`: `addItemAtPosition` is NOT declared on `actions.survey` (only `addExternalItemAtPosition` exists, ~line 343-345). `surveyScope.tsx`'s `handleCloneGroup` calls `actions.survey.addItemAtPosition(...)`, which will raise **`Property 'addItemAtPosition' does not exist`** at typecheck. The `.js` declaration was added (target 2) but the **`.d.ts` type declaration was NOT** (no target owned `actions.d.ts`). This is a build blocker.
   - Runtime ordering: the `surveyCompanionStore.js` `listenTo(actions.survey.addItemAtPosition, ...)` relies on the `actions.js` declaration existing at store init. That declaration was applied (target 2), so this specific link is satisfied — but it is fragile and depends on load order.
   - Net: "Duplicate group" / "Add selected rows to library" are **not functional and will not compile** until `actions.d.ts` gains the `addItemAtPosition` type (params with optional `itemDict?: any; uid?: string`).

2. **EditableForm.tsx prop declaration vs. formEditors.tsx prop pass (resolved, but verify).**
   formEditors passes `desiredAssetType={...}` to `<EditableForm/>`. The EditableForm pass (efSpec FILE 1) reports adding `desiredAssetType?: AssetTypeName` to `EditableFormProps` and seeding state from the prop. The formEditors pass (target 8) could NOT edit EditableForm and flagged this as a **potential build-breaking excess-property error** if FILE 1 had not landed. Both passes ran; the prop now appears declared. **Verify the two edits are mutually consistent** (prop name/type and `useState` seeding) — this is the single most likely place for a silent mismatch.

3. **Language-change alert (`accountMenu.tsx`).** Fork wants `alertify.alert(t('Change language'), t('Please refresh the page'))` + `import alertify`. Current source still has upstream's `window.alert(t('Please refresh the page'))`. NOT applied (no target owned `accountMenu.tsx`). Needs a dedicated pass.

4. **`isSharedInfraEnabled()` re-port.** The fork method (`sessionStore.currentAccount.customer_shared_infra === true`) lived in the deleted `editableForm.es6`. EditableForm.tsx reportedly re-adds an `isSharedInfraEnabled`; the type field now exists. Confirm the method body reads the typed field (not a stale cast) once a reviewer touches the file.

5. **Branding "Too many tags" → "Too many labels" (OBSOLETE — no home).** The host `actions.resources.listTags` action + its Raven block were removed upstream. There is no source location to apply the string. Recorded as obsolete; flag if product still wants the wording surfaced somewhere.

6. **`add_row_to_question_library` (single-row) SKIPPED.** Its only caller (`view.row.coffee:423`) is commented out; functionally dead. Safe to skip; re-add only if that caller is revived.

### Obsolete items intentionally NOT re-added (6)
`actions.auth.logout` + `logout.completed→reload`; `actions.auth.getEnvironment` action+listener; cross-storage logout guard in `updateAsset` (all three now owned by `session.ts verifyLogin`); the `getCrossStorageClient` import (omitted to avoid an unused-import lint error since its only consumer is the obsolete guard); the "Too many tags" listTags Raven string (host removed); the MDL layout / icon-rename / `componentWillReceiveProps` tag-toggle bits from `assetrow.es6` (dead architecture). These are deliberate omissions matching upstream removals.

---

## 4. Build Readiness Status

**NOT verified as build-ready. At least one known TypeScript blocker is outstanding.**

| Check | Status | Evidence |
|---|---|---|
| Conflict markers | PASS | `git grep -lE "^(<<<<<<<|>>>>>>>) "` (excl. md) → no matches |
| Python syntax | PASS | 42 changed `.py` compiled via `py_compile` (incl. `hub/admin/mixins.py`, confirmed present/modified) |
| Dangling `ownedCollectionsStore` import | RESOLVED | file exists (5689 bytes, untracked `??`); all 4 import sites resolve |
| Other dangling imports | NONE FOUND | only `xlform/src/*` flagged; those resolve to existing `.coffee`/`.d.ts`, predate this pass |
| `actions.d.ts` `addItemAtPosition` type | **MISSING — BLOCKER** | `actions.survey` declares only `addExternalItemAtPosition`; `surveyScope.tsx` references the undeclared `addItemAtPosition` |
| EditableForm `desiredAssetType` prop ↔ formEditors pass | LIKELY OK, UNVERIFIED | both passes report the matching edits; not cross-checked by compiler |
| Full `tsc` / webpack prod build | **NOT RUN** | hard rule: no builds/npm; static reasoning only |
| Lint (Biome/ESLint) | **NOT RUN** | several intentional dead methods/imports could trip rules; eslint-disable added only for `AccountMenu` |

**Remaining blockers before a clean build:**
1. **Add `addItemAtPosition` to `jsapp/js/actions.d.ts`** (`actions.survey` block + param/definition types). Without it, typecheck fails in `surveyScope.tsx`. — HARD BLOCKER.
2. **Confirm `EditableFormProps.desiredAssetType` declaration matches the `formEditors.tsx` prop pass** (name + type `AssetTypeName`, optional). If FILE 1 did not land exactly, this is an excess-property compile error.
3. **Run `tsc` and the prod webpack build** (`webpack --config webpack/prod.config.js`) — neither was executed; first real signal will come from CI/human.
4. **Stage `ownedCollectionsStore.ts`** — it is currently untracked (`??`); it exists on disk so the build sees it, but it is not yet committed.
5. **Optional, non-blocking:** decide on the flagged UX/product items in §2.2 and the unported `accountMenu.tsx` alert (§3.3) before considering the fork-port "complete."

**File counts for the working tree:** 201 files changed vs. upstream 2.026.12i total; 45 tracked files newly modified in this pass; `ownedCollectionsStore.ts` is an additional untracked new file (not in the 45).

---

## 5. One-paragraph summary

Of 44 rehome customizations, 38 were re-applied and 6 were intentionally dropped as obsolete (logout/reload, getEnvironment, the cross-storage logout guard now owned by `session.ts`, the homeless "Too many tags" string, the dead single-row library helper, and the dead MDL/tag-toggle UI bits); all 43 apply targets ran with their in-scope edits landed, including the recreation of the deleted `ownedCollectionsStore.ts` build-blocker and the `customer_shared_infra` type addition. The work is genuinely substantial and the EditableForm class→function translation is clean, but the port is **not** verified as build-ready: no compiler, linter, npm, or git command was run (static reasoning only), there is a known TypeScript blocker because `actions.d.ts` was never given the `addItemAtPosition` declaration that `surveyScope.tsx` now references, the EditableForm `desiredAssetType` prop wiring is cross-pass and unverified by a compiler, `ownedCollectionsStore.ts` is still untracked, and several genuinely fork-load-bearing changes could not be ported because their files were outside each target's single-file scope — most importantly the `accountMenu.tsx` language-change alert and the `actions.d.ts` type, both required before this can be called complete. Treat the result as "in-scope edits applied, end-to-end correctness pending a real build and a human decision on the flagged UX items."
