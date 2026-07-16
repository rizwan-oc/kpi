# Kobo 2.026.12i Port Report

**Repo:** `/Users/shivavadla/dev/kpi`
**Branch:** `upgrade-2.026.12i`
**Base tag (upstream target):** `2.026.12i`
**HEAD at time of report:** `178035667` — *WIP: git 3-way auto-merge commit*
**Report date:** 2026-05-29

> **Honest status up front:** This is a **work-in-progress merge that is NOT complete**. The HEAD commit is an auto-merge whose own message states that **86 files still had conflict markers**, of which **85 have since been resolved** (1 conflict file remains unresolved). Both static build probes pass and most OpenClinica (OC) fork features have been reconciled, but **multiple specs still require human decisions** before this branch can be considered shippable. Do not treat "probes pass" as "the port works" — neither a real backend boot, a webpack build, nor a Playwright run has been performed.

---

## 1. Summary table of counts by category

| Category | Metric | Count |
|---|---|---|
| **Conflicted-merge files (cmConflict)** | Total | 86 |
| | Resolved | 85 |
| | **Still unresolved** | **1** |
| **Clean-merge files (cmClean)** | Total | 17 |
| **Re-home specs (rehome)** | Total | 44 |
| | Classified `port` | 38 |
| | Classified `obsolete` | 5 |
| | Classified `uncertain` | 1 |
| **Apply targets** | Total targets | 53 |
| | Actually applied | 5 |
| **Needs-review items** | Total flagged | 39 |
| **Reconcile / OC features** | Wired | 7 of 7 |

> **Caveat on `apply`:** only **5 of 53** apply targets were actually applied in this pass. The remaining 48 are not reflected in this branch yet and must be tracked separately — this is the single biggest gap between "counts look done" and "work is done".

---

## 2. Build-probe results

Both probes are **static only**. No `npm install`, no webpack build, no Django boot, no test suite. Treat as smoke checks, not validation.

### 2.1 Backend probe — `py_compile`

| Field | Value |
|---|---|
| Check | `python3 -m py_compile` |
| Ran | yes |
| Result | **OK** |
| Files checked | 41 changed `.py` files (vs tag `2.026.12i`, committed + working-tree) |
| Syntax failures | **0** |
| Files modified by probe | none |

**Notes:** All 41 changed Python files exist on disk and compile cleanly. This proves syntax only — it does **not** prove imports resolve at runtime, that `oc.*` / `bossoidc2` / `mozilla_django_oidc` / `oidc_auth` packages are installed in the image, or that Django settings load.

### 2.2 Frontend probe — static (`fe-static`)

| Field | Value |
|---|---|
| Check | conflict-marker scan + JSON validation |
| Ran | yes |
| Result | **OK** |
| Changed files vs base | 150 (`git diff 2.026.12i --name-only`) |
| Leftover conflict markers in changed set | **0** (scanned for `<<<<<<<`, `>>>>>>>`, `=======`, `\|\|\|\|\|\|\|`) |
| `git diff --diff-filter=U` unmerged files | none |
| JSON files changed | `package.json`, `package-lock.json` |
| JSON parse | both OK via `python3 -m json.tool` |
| Errors | **0** |

**Notes:** No leftover conflict markers in any of the 150 changed files; both changed JSON files parse. No `tsconfig*.json` was among changed files. Probe applied no fixes.

> **Independent re-check during report writing:** a repo-wide `git grep` for marker lines returned only `CODING_STYLE_FE.md` and `kobo/apps/openrosa/apps/logger/README.mkdn`. These are **pre-existing documentation files** containing marker-like example text, **not** part of the changed source set — they are not merge artifacts and are out of scope. The changed-file set is clean.

> **Important limitation:** the frontend probe did **not** run `tsc` or webpack. Several resolved files carry **known transient TypeScript type errors** (see §3 and §4) that a real type-check/build would surface — most notably the `econsent-signature` / `econsent_signature` icon name not being in the generated `IconName` union until the icon font is regenerated.

---

## 3. Needs human review

This section lists **every** flagged file/spec with its risk notes. **39 items** were flagged across reconcile, conflict-resolution, re-home, and apply phases. Items are grouped by phase. Treat each "risk" as an open question for a human owner.

### 3.1 Reconcile specs flagged `needsHumanReview: true` (2)

#### `package.json deps` — RECONCILED, **needs human review**
- The logic-builder SHA pin `ea77c653bbaff233a24489b1d66e5947c2eb8b44` was taken from OC feature commit `a1120ecf6` (OC-27669 P1.1), **not** the fork base. **If the OC team has since bumped the logic-builder pin, this value is stale** and must be updated to the intended prod pin before shipping.
- `package-lock.json` was intentionally **not** touched. The lockfile must be regenerated via `npm install --legacy-peer-deps --ignore-scripts` to materialize the `github:OpenClinica/logic-builder` dependency.

#### `frontend OC modules` — RECONCILED (2 surgical edits), **needs human review**
- **Broader ocutils wiring regression (flagged, out of strict scope):** the current `jsapp/js/main.js` does **not** contain the baseline fork's cross-storage session wiring that lived in `main.es6` — `initCrossStorageClient()`, `setPeriodicCrossStorageCheck(crossStorageCheck)`, the custom-event listeners that call `crossStorageCheckAndUpdate()`, logout-on-user-changed/timeout, and the CSRF token rename from `csrftoken` to `occsrftoken_v2`. `main.js` currently uses `/csrftoken=(\w{32,64})/` (kobo) instead of the fork's `occsrftoken_v2`. This is a **session/auth feature**, not a simple import, and was **not** restored surgically — needs a human decision on whether OC4 still relies on cross-storage SSO timeout sync in this kobo version.
- No build/typecheck was run (disallowed); compilation not verified.
- `RequireAdmin` guard restored to baseline semantics (`user_type == 'user'` ⇒ AccessDenied). If kobo 2.026.12i changed `user_type` values/casing, confirm `'user'` is still the correct non-admin sentinel.

### 3.2 Conflict-resolution files flagged for review

#### `kpi/templates/base.html` — **status: partial** (confidence: medium)
- **Title rebrand intent (KoboToolbox → OpenClinica) is NOT applied.** The brand prefix is hardcoded in `kpi/templates/base_simple.html:16` outside any overridable block. To preserve fork intent, `base_simple.html` must be edited (out of scope for this file-only task).
- `base_simple.html` emits its own KoboToolbox `<meta description>` unconditionally, so the page now has **two** description metas; the KoboToolbox one appears first.
- Resolution assumes `base_simple.html` exposes `head_scripts/head_stylesheets/head_end/title/body` blocks — verified against current/upstream, but re-check if `base_simple.html` changes.

#### `dependencies/pip/dev_requirements.txt` — resolved (confidence: **medium**)
- Autogenerated lock file; the only guaranteed-correct artifact is a fresh `uv pip compile dependencies/pip/dev_requirements.in`. The hand-merge pins fork-only OIDC deps at **OLD versions** (oic 0.13.0, python-jose 3.3.0, pyjwkest 1.4.2, mozilla-django-oidc 3.0.0, drf-oidc-auth 3.0.0, beaker 1.12.1, mako 1.2.4, msrest 0.7.1, beautifulsoup4 4.12.2, tldextract 3.4.4) whose compatibility with upstream's newer Django 4.2.28 / DRF 3.16.1 graph is **not verified**.
- `drf-oidc-auth==3.0.0` historically targets older DRF; pairing with DRF 3.16.1 may conflict.
- Sibling `dependencies/pip/requirements.in` still contains **unresolved conflict markers** (pyxform 3.0.0 vs OpenClinica/pyxform editable) — out of scope here but must be resolved consistently before recompiling.
- **Recommendation: regenerate the lock via the upstream uv toolchain** after `.in` conflicts are resolved rather than shipping this hand-merge.

#### `dependencies/pip/requirements.txt` — resolved (confidence: high)
- Same autogenerated-lock caveat; canonical fix is `uv pip compile dependencies/pip/requirements.in`.
- OIDC packages carry old fork pins; compatibility with Django 4.2.28 / DRF 3.16.1 / cryptography 44.0.3 **not verified**.
- `requirements.in` was not inspected to confirm which OIDC packages are still direct requirements.

#### `kpi/filters.py` — resolved (confidence: high)
- The fork's `SearchQueryTooShort` removals did **not** surface as conflicts; upstream still ships `SearchQueryTooShortException` / `min_search_characters`, so the merged file retains upstream short-query behavior — the **opposite** of fork intent. If the fork deliberately wanted min-search-length disabled, that intent is **NOT preserved** here.
- `from kpi.utils.domain import get_subdomain` is imported but unused (linter may flag).
- The subdomain block short-circuits before upstream's newer `ExcludeOrgAssetFilter`/MMO-org and deployment-status logic when a subdomain match applies.

#### `jsapp/js/constants.ts` — resolved (confidence: high)
- `econsent_signature` uses `icon: 'econsent-signature'`, which is **not yet in** the generated `IconName` union — a **transient TS type error** until the icon font/types are regenerated (source SVG present; regeneration out of scope). *(Note: a later econsent reconcile pass changed this to `qt-acknowledge` — see §4; confirm which value is current.)*
- Cross-file: `jsapp/js/stores/session.ts` must import `ANON_USERNAME` from `#/users/utils` while `ANON_USER_TYPE`/`ANON_USER_SUBDOMAIN` come from `js/constants`, or resolution will fail.
- `AVAILABLE_FORM_STYLES` dropped two `no-text-transform` variants; legacy forms saved with those styles will show a blank selector value (data not lost).

#### `jsapp/js/components/assetsTable/assetsTableRow.tsx` — resolved (confidence: high)
- **Behavioral change:** the actions column now renders the OC-customized `AssetActionButtons` (most actions commented out — only Rename Collection + a More popover visible) instead of the fork's inline icon buttons. **Library rows expose fewer direct actions than the old fork.** Confirm this matches intended OC UX or expand `AssetActionButtons`.
- Owner column switched from `owner__username` (fork) to `owner_label` (upstream) — verify same value semantics.
- No `tsc`/webpack build run.

#### `jsapp/js/components/library/myLibraryStore.ts` — resolved (confidence: high)
- **Cross-file dependency:** imports `ownedCollectionsStore from './ownedCollectionsStore'`, which **does NOT yet exist** in the merge working tree. It must be brought over (see re-home spec) or this file fails to compile.
- `startupStore` relies on upstream's reaction firing on context change to trigger fetch — confirm library load-on-login path at runtime.
- `PAGE_SIZE` now uses fork's `DEFAULT_PAGE_SIZE` (=200) vs upstream 100 — confirm 200 is desired.

#### `jsapp/js/mixins.tsx` — resolved (confidence: high)
- Fork customization #4 (Archive/Unarchive **Form** titles, library clone `goToUrl=/library`) targets code upstream moved to `#/assetQuickActions.tsx`; **NOT re-applied** (hard rule limited edits to mixins.tsx). `assetQuickActions.tsx` still says "Archive Project"/"Unarchive Project". Follow-up edit required if fork wording is still wanted.
- `parent` field added via `Object.assign` onto a type that no longer declares it — not type-checked.

#### `jsapp/js/stores/session.ts` — resolved (confidence: high)
- Replaced fork's `actions.auth.logout()` with upstream's `this.logOut()` (upstream removed the Reflux logout action). Behavior is equivalent but now async fire-and-forget — confirm intended logout path.
- `currentAccount` anon type merged shape; structural TS checks elsewhere not exhaustively run.
- Import paths normalized to `#/` alias; `#/ocutils` and `#/userpilot` not type-checked via build.

#### `jsapp/scss/components/_kobo.form-builder.scss` — resolved (confidence: high)
- OC back-button (`form-builder-header__button--back`), supportUrl cell, and add-questions-to-library affordances were **dropped as obsolete** (upstream header refactor removed the markup hooks). **If OC still needs a distinct back button or these affordances, they must be re-implemented against the new shared `<Button>` / `EditableForm.tsx`.**
- Dropped the fork's `.lib-nav--visible + .form-builder` companion selector; responsive margin behavior lost if any non-EditableForm view still renders `.lib-nav--visible`.

#### `jsapp/scss/stylesheets/partials/_base.scss` — resolved (confidence: high)
- Upstream's `:focus-visible` accessibility refactor is **intentionally overridden** to match the fork's "suppress focus outline entirely" intent. This **removes the keyboard-navigation focus indicator (an a11y regression)**. Confirm OC still wants outlines fully suppressed vs adopting upstream's accessible behavior.

#### `jsapp/scss/stylesheets/partials/form_builder/_mandatory_setting.scss` — resolved (confidence: high)
- Upstream's parallel UI (`.mandatory-settings-input-wrapper`) was discarded in favor of the fork's `.required-logic-panel`. **If upstream's 2.026.12i React/JS emits `.mandatory-setting__row--custom` / `.mandatory-settings-input-wrapper` markup that the fork did not refactor, those elements will be unstyled.** Confirm the fork's TSX renders `.required-logic-panel` / `.js-required-logic-tab` markup.
- CSS-only resolution; correctness depends on accompanying JS/TSX merges.

#### `jsapp/xlform/src/model.configs.coffee` — resolved (confidence: high)
- `select_one_from_file` labeled "Text" (OC choice) vs upstream "Select one from file" — confirm fork label is still desired.
- Dropped upstream's image `max-pixels` questionParam (orphaned `paramTypes.maxPixels` left harmless) — re-add if OC wants image compression.
- No CoffeeScript compile check run (validity confirmed by manual re-read).

#### `jsapp/xlform/src/view.choices.coffee` — resolved (confidence: high)
- Dropped fork's `data-cy="option"` Cypress hook — OC e2e selecting `[data-cy=option]` would break.
- New image input `@i` made label-free to match upstream — confirm "Value:"/"Image:" labels aren't needed.
- Confirm upstream dropping `@model.set('setManually', true)` doesn't regress manual-name behavior.

#### `jsapp/xlform/src/view.rowSelector.coffee` — resolved (confidence: high)
- **Re-introduced upstream keyboard navigation that the fork had removed.** No OC-specific reason for the fork's removal was evident, but confirm it doesn't interfere with the OC question-namer / PII / econsent flow.
- Dropped upstream's `rowDetails.calculation = questionLabelValue` for calculate type (fork sets name='calculation' + unconditional label) — calculate rows no longer get `.calculation` prefilled.
- `writeParameters` default-parameters now also runs for OC custom types `pii_encrypted`/`econsent_signature` (benign but unverified).

#### `kobo/settings/base.py` — resolved (confidence: high)
- `csp.middleware.CSPMiddleware` ordering vs new upstream middleware (allauth UserSessions, audit-log, RestrictedAccess) **not validated at runtime**.
- `USE_L10N` dropped (Django 4.2 deprecation) — low risk.
- DRF auth: `OIDCAuthentication` placed first per fork intent — confirm OIDC-first does not bypass an intended auth path.
- **`oidc_auth.authentication.BearerTokenAuthentication`, `oc.*`, `bossoidc2`, `mozilla_django_oidc` must be installed in the upgraded image — NOT verified here** (only the settings file was edited).
- Pre-existing upstream `\d`/`\W` SyntaxWarnings in `PASSWORD_CUSTOM_CHARACTER_RULES` remain (not introduced here).

### 3.3 Re-home specs flagged with risks (key items)

> Of 44 re-home specs: **38 `port`, 5 `obsolete`, 1 `uncertain`**. The following carry the most load-bearing risks.

#### `jsapp/js/editorMixins/editableForm.es6` → `EditableForm.tsx` (`port`) — **highest-risk port**
- **Complete paradigm rewrite** (Reflux assign-mixin → hooks; Mantine `<Button>` replacing `bem.FormBuilderHeader__button`). The fork diff **cannot be applied as a patch**; every method/JSX block must be hand-translated. High chance of subtle state/closure bugs (debounce, setState-with-callback).
- The econsent **save-time guard is likely partially obsolete** (upstream xlform now validates consent live); decide whether to drop it or keep as backstop, and reuse `isEConsentSignatureRow` instead of the old inline `getValue('bind::oc:external')` check. `row.getConsentItemChoiceValue()` may no longer exist.
- `customer_shared_infra` is consumed in ~20 files but **not declared on `AccountResponse`** — `isSharedInfraEnabled()` won't type-check until the field is added.
- Fork hard-disables upstream Metadata/Details aside sections (`hideMetadata`/`hideDetails` always true). **Blindly porting hides upstream functionality 2.026.12i may now expect visible.** Product decision needed.
- Header re-skin must be redone against new Mantine layout; matching SCSS no longer exists.
- `settings__version`/`settings__form_id` round-trip depends on the asset shape still surfacing those fields after upgrade.
- `createResource` navigation target reconciliation (fork `ROUTES.LIBRARY` vs upstream `state.backRoute`).

#### `jsapp/js/components/library/ownedCollectionsStore.ts` (`port`) — **blocking build dependency**
- Upstream **DELETED** this store and replaced it with `managedCollectionsStore` (renamed + `userCan` filtering). `managedCollectionsStore` returns viewable (not owned-only) collections — **sidebar collection-list semantics may differ.**
- **The upgrade build is currently broken:** `myLibraryStore.ts:19` and `assetCollectionActions.tsx:10` still import the now-missing `./ownedCollectionsStore`. These must be brought over or repointed before anything compiles.
- Removing upstream's `userCan('manage_asset', asset)` filter could leak collections client-side — confirm OC relies on backend tenant-scoping.

#### `jsapp/js/components/library/librarySidebar.es6` (`port`)
- Depends on the deleted `ownedCollectionsStore`; dangling imports block the build.
- `assetUtils.modifyDetails` / `mixins.clickAssets.click.asset.delete` no longer exist → mapped to `manageAssetSettings`/`deleteAsset` (inference — verify rename modal entry point).
- The ECONSENT searchParams-preservation in `goToTemplateCreator` has **no upstream equivalent** and must be hand-ported verbatim.
- Architectural decision: revert to class+mixin pattern vs re-implement dropzone/contextRouter in the new style.

#### `jsapp/js/main.es6` → `main.js` (`port`) — cross-storage SSO
- Core check re-homed to `session.ts`, but the **periodic poll + DOM activity listeners were NOT re-homed anywhere** (`setPeriodicCrossStorageCheck`/`addCustomEventListener`/`initCrossStorageClient` have zero callers). Human must decide: restore into `main.js` or fold into `session.ts`.
- Logout must use `sessionStore.logOut()` (old `actions.auth.logout` removed).
- Keep CSRF regex width `{32,64}` (Django 4.1 token-length change); do not regress to `{64}`. Use `occsrftoken_v2`.
- Cross-storage hub URL depends on OC4 host naming (`formdesigner.*` → `build.*`) — deploy-time check.

#### `jsapp/js/router/allRoutes.es6` → `allRoutes.js`/`router.tsx` (`port`)
- **Semantic conflict on `/forms` redirect:** fork redirected `/forms` → LIBRARY; upstream now redirects to the new `PROJECTS_ROUTES.MY_PROJECTS`. Product decision needed.
- ROOT redirect target (LIBRARY vs Projects landing) — product decision.
- `<UserPilotRouteTracking />` scope: now mounted in `app.jsx`; verify routes rendering via `BasicLayout` also get it if needed.

#### `jsapp/js/actions.es6` → `actions.js` (`port`)
- `form_saveinprogress`/`form_savecomplete` postMessage handshake is **absent from the entire tree** — verify whether `EditableForm.tsx` also needs these re-added.
- Fork's `actions.auth.logout()` deleted upstream; replacement `sessionStore.logOut()` may create a **circular import** in the Reflux actions module — verify or relocate.
- Cross-storage `currentUser` raw `get()` may duplicate/conflict with session-store logic — confirm whether to reuse `checkCrossStorageUser(...)`.

#### `jsapp/js/components/assetrow.es6` (`port`)
- **Survey-side permission bypass NOT carried over:** the fork forced `userCanEdit = true` (OC governs edit perms via Keycloak/study-manager). The modern split has **no equivalent override**; survey/Projects paths still gate on real `userCan('change_asset', ...)`. **Human must confirm whether OC still needs always-editable behavior on the survey/Projects side.**
- Decisions were made by commenting-out (brittle; a future merge could silently re-enable).

#### `jsapp/js/components/header.es6` (`port`)
- Account-menu suppression is the load-bearing OC change; its correct home is a product decision (hide just `AccountMenu` vs also hide the new `OrganizationBadge`).
- "Search Projects" → "Search Forms" relabel has no exact new home (upstream uses `t('Search…')`).
- `git_rev.tag` field likely not on the TS type and not populated by backend.

#### Other `port` specs with risks (abbreviated)
- **`bigModal.es6`** — task premise ("upstream deleted bigModal") inaccurate; renamed to `bigModal.js`. `LIBRARY_COLLECTION_CREATE/EDIT` constants survive but are **orphaned**; dispatch sites and `libraryAssetForm` formType handling were lost and must be re-ported, else new cases are dead code. Product decision on distinct create-vs-edit modal.
- **`formEditors.es6`** — template-creation flow may be intentionally retired upstream in favor of `LIBRARY_TEMPLATE` modal; `NEW_LIBRARY_TEMPLATE_ITEM/_CHILD` routes are **unreachable** (no navigator). `desiredAssetType` prop dropped from `EditableForm.tsx` and must be re-wired (prop + initializer).
- **`list.es6`** — genuine intent conflict: fork **removed** the expand-details checkbox; upstream **re-added** it. Don't auto-override. New `AssetNavigator.tsx` strings are hardcoded literals (not `t()`-wrapped).
- **`searchcollectionlist.es6`** — blocked by the dangling `ownedCollectionsStore` import. "OpenClinica" `DocumentTitle` rebrand is missing app-wide (0 occurrences vs 14 `| KoboToolbox`). Ambiguous which library contexts should activate `showAllTags`.

#### Re-home specs flagged `obsolete` (do **not** resurrect as ports)
- **`jsapp/js/i18nMissingStrings.es6`** (`obsolete`) — gettext-extraction artifact, not loaded at runtime. **But** the merge regressed the fork's "Select Many"→"Select Multiple" label in two **live** files (`KoboMatrix.tsx:125`, `ProjectExportsCreator.tsx:588`) — confirm whether to re-apply those two display-label edits (do NOT change `value:'select_many'`/icons).

#### Re-home spec flagged `uncertain` (1)
- **`jsapp/js/components/tagInput.es6`** (`uncertain`) — component is **intentionally dead** (its only consumer `assetrow.es6` was deleted upstream). The fork's tag→label terminology was applied in multiple spots and upstream reverted all of them. Whether OC4 still wants "label" instead of "tag" is a **product/i18n decision** (may need `.po` updates). Do not straight-port (would resurrect dead code).

### 3.4 Apply targets flagged `partial` (1)
- **`scripts/fix_migrations_for_kpi.py`** (`partial`) — item (3) **`--legacy-peer-deps` npm hardening is unaddressed**: `docker/entrypoint.sh:73-78` still runs `npm install --quiet` **without** `--legacy-peer-deps`, which is **load-bearing** for OC's `@openclinica/logic-builder` github dep. Must be applied to `entrypoint.sh` in a follow-up. INSERT assumes the standard `django_migrations` schema; `bossoidc2` fake-row inserted unconditionally. Lower-priority `init.bash` nits left for the `entrypoint.sh` re-home decision.

---

## 4. Reconcile / wiring status per OC feature

All 7 OC fork features were reconciled and reported `wired: true`. **2 of 7 carry `needsHumanReview: true`** (see §3.1). Honest read: "wired" means the wiring was located/restored in the inspected files — it does **not** mean the feature was exercised at runtime.

| OC feature | Wired | Action taken | Human review |
|---|---|---|---|
| **oc app wiring** (settings) | yes | Verify-only. All oc-app wiring already present in merged `kobo/settings/base.py`; no edits (would duplicate). All 3 settings files pass `ast.parse`. | no |
| **package.json deps** | yes | Re-added dropped `@openclinica/logic-builder` (github+SHA pin) into `package.json:12`; `userpilot 1.4.2` survived. | **yes** |
| **econsent question type** | yes | Fixed broken icon ref in `constants.ts:309-313`: `econsent-signature` (not a registered glyph) → `qt-acknowledge`. Helpers/xlform hooks verified present. | no |
| **xlform customizations** | yes | Verify-only across `model.survey.coffee`, `view.rowDetail.SkipLogic.coffee`, `view.surveyApp.coffee`; all OC intent preserved. Benign deltas only (upstream refactors). | no |
| **frontend OC modules** | yes | 2 surgical edits: `router.tsx` (`RequireAdmin` import + MY_LIBRARY guard `RequireAuth`→`RequireAdmin`); `app.jsx` (mount `<UserPilotRouteTracking/>` next to `<Tracking/>`). | **yes** |
| **scss imports** | yes | Verify-only. All 3 OC SCSS partials already `@use`/`@import`-ed (`main.scss:54`, `form_builder.scss:14-15`). | no |

**Key wiring detail to confirm at runtime:** in `kobo/settings/base.py`, `AUTHENTICATION_BACKENDS` first entry is `kpi.backends.ModelBackend` (upstream rename) and `oc.backend.OpenIdConnectBackend` is inserted after `kpi.backends.ObjectPermissionBackend`. The Keycloak/OIDC block (`OIDC_RP_*`, `OIDC_CALLBACK_CLASS`, `KEYCLOAK_*`, `ALLOW_LOGOUT_GET_METHOD`) plus `from oc.settings import configure_oidc` and `configure_oidc(...)` are present at lines ~2308-2333. Note: `configure_oidc()` mutates module-level globals in `oc/settings.py` (`OIDC_PROVIDERS`, `OIDC_AUTH`) and does **not** inject `OIDC_OP_*` endpoints into Django's settings namespace — faithful to the fork, but confirm the oc backend reads config from `oc.settings` as intended at runtime.

> **Note on econsent icon:** the econsent reconcile pass set the icon to `qt-acknowledge`, while the `constants.ts` conflict-resolution note left it as `econsent-signature` (a transient TS error pending icon-font regen). These two notes disagree on the final value — **a human should confirm which value `constants.ts:309-313` actually holds on this branch** before a build.

---

## 5. Next steps — deploy + Playwright verification phase

The branch is **not ready to deploy**. Address the blockers below in order before the deploy/Playwright phase.

### 5.1 Hard blockers (must fix before any build)
1. **Resolve the 1 remaining unresolved conflict file** (86 total, 85 resolved). Confirm via `git diff --diff-filter=U` and a marker grep over the changed set.
2. **Resolve `dependencies/pip/requirements.in`** — it still contains conflict markers (pyxform 3.0.0 vs OpenClinica/pyxform editable). Then **regenerate both pip locks** with the upstream uv toolchain (`uv pip compile requirements.in` / `dev_requirements.in`) rather than shipping the hand-merged lock files.
3. **Bring over / repoint `ownedCollectionsStore`** — `myLibraryStore.ts:19` and `assetCollectionActions.tsx:10` import a file missing from the working tree. Decide: port `ownedCollectionsStore.ts` (fork intent) or repoint to upstream `managedCollectionsStore` (and accept the viewable-vs-owned semantics change). **The frontend build cannot succeed until this is fixed.**
4. **Complete the high-risk `editableForm.es6 → EditableForm.tsx` re-home** — including the `customer_shared_infra` field on `AccountResponse` (or it won't type-check) and a product decision on the hidden Metadata/Details panels.

### 5.2 Apply backlog
5. **Apply the remaining 48 of 53 `apply` targets** — only 5 were applied this pass. In particular, harden `docker/entrypoint.sh` `npm install` with `--legacy-peer-deps` (required by `@openclinica/logic-builder`).

### 5.3 Product/UX decisions needed (collect before final resolution)
6. Survey-side **always-editable permission bypass** (`assetrow.es6`) — keep or drop?
7. **Account-menu / OrganizationBadge** suppression scope (`header.es6`).
8. `/forms` and ROOT **redirect targets** — Library (fork) vs Projects (upstream).
9. **OpenClinica branding** rebrand pass (title in `base_simple.html`; `DocumentTitle` across ~14 files).
10. **Cross-storage SSO** periodic-poll / activity-listener home (`main.js` vs `session.ts`), CSRF token rename to `occsrftoken_v2`.
11. **`:focus-visible` a11y** override (`_base.scss`) — keep fork's suppression or adopt upstream accessible behavior?
12. "Select Many"→"Select Multiple" live-label re-apply in `KoboMatrix.tsx` / `ProjectExportsCreator.tsx`.
13. logic-builder **SHA pin** confirmation (`package.json:12`) and `qt-acknowledge` vs `econsent-signature` icon value.

### 5.4 Build + materialize
14. Regenerate `package-lock.json`: `npm install --legacy-peer-deps --ignore-scripts`.
15. Regenerate the **icon font** so `econsent-signature` (or the chosen glyph) is a valid `IconName`.
16. Run a **real frontend build**: `NODE_OPTIONS=--openssl-legacy-provider ./node_modules/.bin/webpack --config webpack/prod.config.js`, then a `tsc`/typecheck. Expect transient TS errors flagged in §3 to surface here.
17. Verify the upgraded Docker image actually **installs** `oc`, `bossoidc2`, `mozilla_django_oidc`, `oidc_auth`, `drf-oidc-auth`, and the OIDC transitive tree; boot Django and confirm settings load.

### 5.5 Deploy + Playwright verification
18. Deploy per `CLAUDE.md` kpi deploy block (copy `compiled` to both `jsapp/compiled/` and `staticfiles/compiled/`, copy `webpack-stats.json`, `docker restart kpi`).
19. **Ensure ngrok is up** before Playwright (cross-storage iframe handshake requires it).
20. **Playwright flow:** never navigate top-level to `formdesigner.localhost.io`. Always go Study Manager → wekan-oc → **Design button → iframe**. Verify: (a) SSO login lands in the form designer, (b) the Library list renders with the OC item-version/item-type columns, (c) the **econsent_signature** and **pii_encrypted** question types appear in the picker and save, (d) Logic Builder side panel loads, (e) cross-storage session timeout/logout behaves (the at-risk feature from §3).

---

## 6. Honest bottom line

The merge **resolved 85 of 86 conflicts**, both **static probes pass with zero errors**, and **all 7 OC features are wired** in the files inspected. But this is **not** a finished port: **1 conflict file and `requirements.in` markers remain**, the **frontend build is known-broken** by the missing `ownedCollectionsStore`, **only 5 of 53 apply targets** were applied, the **highest-value OC feature (`EditableForm` form builder) is an un-ported paradigm rewrite**, and **39 items need human review/decisions** — several of them load-bearing (auth/OIDC, cross-storage SSO, survey permission bypass, branding, a11y). No runtime, build, or Playwright verification has occurred. Treat the green probes as a syntax/marker smoke test only.
