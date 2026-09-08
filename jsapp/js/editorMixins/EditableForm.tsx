import React, { useCallback, useEffect, useRef, useState } from 'react'

import { Text } from '@mantine/core'
// OC fork (P1.1): AI Generator dialog + Logic Builder wiring.
import { AiGeneratorDialog } from '@openclinica/logic-builder'
import alertify from 'alertifyjs'
import cx from 'classnames'
import clonedeep from 'lodash.clonedeep'
import debounce from 'lodash.debounce'
import last from 'lodash.last'
import DocumentTitle from 'react-document-title'
import Markdown from 'react-markdown'
import { useBeforeUnload, useBlocker, unstable_usePrompt as usePrompt } from 'react-router-dom'
import type { AssetSnapshotResponse } from '#/api/models/assetSnapshotResponse'
import { invalidateItem } from '#/api/mutation-defaults/common'
import { getAssetsRetrieveQueryKey, useAssetsRetrieve } from '#/api/react-query/manage-projects-and-library-content'
import assetUtils from '#/assetUtils'
import bem, { makeBem } from '#/bem'
import Alert from '#/components/common/alert'
import Button from '#/components/common/button'
import LoadingSpinner from '#/components/common/loadingSpinner'
import Modal from '#/components/common/modal'
import TextBox from '#/components/common/textBox'
import { isEConsentSignatureRow } from '#/components/formBuilder/econsentSignature'
import {
  type KoboMatrixParserParams,
  applyFreshPrimaryLanguage,
  getFormBuilderAssetType,
  koboMatrixParser,
  mergeFreshTranslations,
  surveyToValidJson,
} from '#/components/formBuilder/formBuilderUtils'
import FormLockedMessage from '#/components/locking/formLockedMessage'
import { LOCKING_UI_CLASSNAMES, LockingRestrictionName } from '#/components/locking/lockingConstants'
import {
  hasAssetAnyLocking,
  hasAssetRestriction,
  isAssetAllLocked,
  isAssetLockable,
} from '#/components/locking/lockingUtils'
import MetadataEditor from '#/components/metadataEditor'
import {
  ASSET_TYPES,
  AssetTypeName,
  type FormStyleDefinition,
  type FormStyleName,
  MODAL_TYPES,
  NAME_MAX_LENGTH,
  OC_USER_TYPES,
  QuestionTypeName,
  type UpdateStatesValue,
  update_states,
} from '#/constants'
import envStore from '#/envStore'
import { LogicBuilderErrorBoundary } from '#/openclinica/LogicBuilderErrorBoundary'
import {
  applyExpressionToRow,
  focusGenerateButton,
  focusPanelInput,
  readCurrentExpression,
} from '#/openclinica/applyExpression'
import { unmountAll } from '#/openclinica/generateButtonBridge'
import { logicBuilderClient } from '#/openclinica/logicBuilderClient'
import { buildFormContext, readItemName } from '#/openclinica/logicBuilderContext'
import { GENERATE_REQUEST_KEY, columnToTab } from '#/openclinica/logicBuilderTabs'
import { useBuilderInert } from '#/openclinica/useBuilderInert'
import pageState from '#/pageState.store'
import type { RouterProp } from '#/router/legacy'
import { ROUTES } from '#/router/routerConstants'
import sessionStore from '#/stores/session'
import dkobo_xlform from '../../xlform/src/_xlform.init'
import type { Survey } from '../../xlform/src/model.survey'
import type { SurveyDetail } from '../../xlform/src/model.surveyDetail'
import type { SurveyApp } from '../../xlform/src/view.surveyApp'
import { actions } from '../actions'
import {
  type AssetContent,
  type AssetRequestObject,
  type AssetResponse,
  type AssetResponseFile,
  type FailResponse,
  dataInterface,
} from '../dataInterface'
import SurveyScope from '../models/surveyScope'
import { type SurveyStateStoreData, stores } from '../stores'
import { escapeHtml, recordKeys } from '../utils'
import AssetNavigator from './AssetNavigator'
import FormStyleCardGrid from './FormStyleCardGrid'

const ErrorMessage = makeBem(null, 'error-message')
const ErrorMessage__strong = makeBem(null, 'error-message__header', 'strong')
bem.CascadePopup = makeBem(null, 'cascade-popup')
bem.CascadePopup__message = makeBem(bem.CascadePopup, 'message')
bem.CascadePopup__buttonWrapper = makeBem(bem.CascadePopup, 'buttonWrapper')

const CHOICE_LIST_SUPPORT_URL = 'cascading_select.html'

// OC fork: OpenClinica Form Designer help docs and a sessionStorage cache for the
// selected form style.
const FORM_DESIGNER_SUPPORT_URL =
  'https://openclinicaservicedesk.freshdesk.com/support/solutions/articles/158000436442-using-form-designer'
const FORM_STYLE_CACHE_NAME = 'kpi.editable-form.form-style'

const UNSAVED_CHANGES_WARNING = t('You have unsaved changes. Leave form without saving?')
/** Use usePrompt directly instead for functional components */
const Prompt = () => {
  usePrompt({ when: true, message: UNSAVED_CHANGES_WARNING })
  return <></>
}

const ASIDE_CACHE_NAME = 'kpi.editable-form.aside'
const LOCKING_SUPPORT_URL = 'library_locking.html'
const RECORDING_SUPPORT_URL = 'recording-interviews.html'

interface LaunchAppData {
  name: string
  settings__style?: FormStyleName
  // OC fork: round-trip the form id and version number stored in form settings.
  settings__version?: string
  settings__form_id?: string
  files: AssetResponseFile[]
  asset_type: AssetTypeName
  asset: AssetResponse
}

interface EditableFormButtonStates {
  previewDisabled?: boolean
  groupable?: boolean
  showAllAvailable?: boolean
  name?: string
  hasSettings?: boolean
  styleValue?: FormStyleName
  // OC fork: surface the form id and version values for the "Form information" aside row.
  versionValue?: string
  formIdValue?: string
  allButtonsDisabled?: boolean
  saveButtonText?: string
  // OC fork: text for the header "back" button.
  backButtonText?: string
}

interface AsideSettings {
  asideLayoutSettingsVisible: boolean
  asideLibrarySearchVisible: boolean
}

interface EditableFormProps {
  assetUid?: string
  isNewAsset?: boolean
  backRoute: string | null
  parentAssetUid?: string
  // OC fork: lets the dedicated "Create Template" routes set `asset_type: template`
  // on create (otherwise it would fall through to `block`).
  desiredAssetType?: AssetTypeName
  router: RouterProp
}

interface EditableFormState extends SurveyStateStoreData {
  isNewAsset?: boolean
  backRoute?: string
  asideLayoutSettingsVisible: boolean
  asideLibrarySearchVisible: boolean
  asset: AssetResponse | undefined
  asset_updated: UpdateStatesValue
  cascadeMessage?: {
    msgType: 'ready' | 'warning'
    addCascadeMessage?: string
    message?: string
  }
  cascadeReady: boolean
  cascadeReadySurvey?: Survey
  cascadeTextareaValue: string
  desiredAssetType: AssetTypeName | undefined
  enketopreviewError?: string
  enketopreviewOverlay: string | undefined
  isBackgroundAudioBannerDismissed: boolean
  name: string
  preventNavigatingOut: boolean
  settings__style?: FormStyleName
  // OC fork: form id and version number, round-tripped through the form settings.
  settings__version?: string
  settings__form_id?: string
  showCascadePopup: boolean
  cascadeLastSelectedRowIndex?: number
  surveyAppRendered: boolean
  surveyLoadError: string | undefined
  surveySaveFail: boolean
}

/**
 * This is a component that displays Form Builder's header and aside. It is also
 * responsible for rendering the survey editor app (all our coffee code). See
 * the `launchAppForSurveyContent` method below for all the magic.
 */
export default function EditableForm(props: EditableFormProps) {
  const [state, setState] = useState<EditableFormState>({
    asideLayoutSettingsVisible: false,
    asideLibrarySearchVisible: false,
    asset: undefined,
    asset_updated: update_states.UP_TO_DATE,
    cascadeMessage: undefined,
    cascadeReady: false,
    cascadeTextareaValue: '',
    desiredAssetType: props.desiredAssetType,
    enketopreviewOverlay: undefined,
    isBackgroundAudioBannerDismissed: false,
    name: '',
    preventNavigatingOut: false,
    showCascadePopup: false,
    surveyAppRendered: false,
    surveyLoadError: undefined,
    surveySaveFail: false,
    isNewAsset: props.isNewAsset,
    backRoute: props.backRoute === null ? undefined : props.backRoute,
    groupButtonIsActive: false,
    multioptionsExpanded: true,
  })

  const formWrapRef = useRef<HTMLDivElement>(null)
  // OC fork (P1.1 AC2): wraps the scroll container's children so the host can
  // inert the content INSIDE .form-builder__contents without inerting the
  // scroller itself (see the builder-inert effect + makeBuilderInert).
  const builderContentsInnerRef = useRef<HTMLDivElement>(null)
  // OC fork (P1.1): root the builder-inert effect resolves the aside/header
  // from while the AI dialog is open (useBuilderInert). The wrapper itself is
  // NEVER inerted — that would make the scroll container inside it unhittable
  // and break AC2's "scrollable but inert". The dialog portals to <body>, so
  // it stays interactive either way.
  const formBuilderWrapRef = useRef<HTMLDivElement>(null)
  const cascadeRef = useRef<HTMLTextAreaElement>(null)

  const onSurveyChangeDebounced = debounce(onSurveyChange, 200)

  const [app, setApp] = useState<SurveyApp | undefined>(undefined)

  const assetUid = props.assetUid || ''

  const assetQuery = useAssetsRetrieve(
    assetUid,
    {},
    {
      query: {
        queryKey: getAssetsRetrieveQueryKey(assetUid),
        enabled: assetUid !== '',
        // No need to fetch it again, as the code doesn't support updating `asset` after it was already loaded
        refetchOnWindowFocus: false,
      },
    },
  )

  useEffect(() => {
    const assetData = assetQuery.data?.data
    if (assetData && 'uid' in assetData) {
      // TODO: stop casting this as AssetResponse after backend openAPI task DEV-1727 is done
      const assetDataCast = assetData as unknown as AssetResponse
      setState((currentState) => ({
        ...currentState,
        // TODO: storing asset that we already have in `assetQuery` is not nice. I left it like this to avoid requiring
        // too much refactor in here.
        asset: assetDataCast,
      }))
    }
  }, [assetQuery.data?.data])

  useEffect(() => {
    if (state.asset) {
      let settingsStyle: FormStyleName | undefined
      // OC fork: form id and version number live in the form settings alongside `style`.
      let settingsVersion: string | undefined
      let settingsFormId: string | undefined
      if (state.asset.content?.settings && !Array.isArray(state.asset.content?.settings)) {
        settingsStyle = state.asset.content.settings.style
        settingsVersion = state.asset.content.settings.version
        settingsFormId = state.asset.content.settings.form_id
      }
      launchAppForSurveyContent(state.asset.content, {
        name: state.asset.name,
        settings__style: settingsStyle,
        settings__version: settingsVersion,
        settings__form_id: settingsFormId,
        files: state.asset.files,
        asset_type: state.asset.asset_type,
        asset: state.asset,
      })
    }
  }, [state.asset])

  useEffect(() => {
    loadAsideSettings()

    if (state.isNewAsset) {
      launchAppForSurveyContent()
    }

    // OC fork (round-5 #6): capture the unsubscribe so this instance stops
    // hearing surveyState changes on unmount. Without it, every
    // mounted-then-unmounted EditableForm left a live listener, and the
    // `setState` below re-entered all of them.
    const unlistenSurveyState = stores.surveyState.listen(onSurveyStateChanged)

    return () => {
      // OC fork: drop the cached form style on unmount.
      sessionStorage.removeItem(FORM_STYLE_CACHE_NAME)
      unpreventClosingTab()
      cleanupAppForSurveyContent()
      // OC fork (P1.1, PR#273 round-3): leaving the Form Designer bypasses the
      // settings-drawer close path, so release every Generate-button React
      // root and drop any dialog request still pointing at the old form.
      unmountAll()
      if (typeof unlistenSurveyState === 'function') {
        unlistenSurveyState()
      }
      stores.surveyState.setState({ [GENERATE_REQUEST_KEY]: null })
    }
  }, [])

  useBeforeUnload(
    useCallback(
      (event) => {
        if (state.preventNavigatingOut) {
          event.preventDefault()
        }
      },
      [state.preventNavigatingOut],
    ),
  )
  const blocker = useBlocker(
    ({ currentLocation, nextLocation }) =>
      state.preventNavigatingOut && currentLocation.pathname !== nextLocation.pathname,
  )

  function loadAsideSettings() {
    const asideSettings = sessionStorage.getItem(ASIDE_CACHE_NAME)
    if (asideSettings) {
      setState((currentState) => ({
        ...currentState,
        ...JSON.parse(asideSettings),
      }))
    }
  }

  function saveAsideSettings(asideSettings: AsideSettings) {
    sessionStorage.setItem(ASIDE_CACHE_NAME, JSON.stringify(asideSettings))
  }

  function onMetadataEditorChange() {
    onSurveyChangeDebounced()
  }

  function onSurveyStateChanged(storeState: SurveyStateStoreData) {
    setState((currentState) => ({
      ...currentState,
      ...storeState,
    }))
  }

  // OC fork (P1.1): AI Generator dialog open/close/apply, driven by the
  // `generateRequest` pushed onto `stores.surveyState` by the Backbone-side
  // Generate buttons (see openclinica/generateButtonBridge.tsx).
  //
  // Focus-on-close is owned here, not by the package: the dialog is embedded
  // and the builder is inert while it's open, so the package no longer attempts
  // its own focus restore (round-5 B/D). The package calls onApply and closes
  // (onClose) ONLY when onApply reports the write persisted (round-6): a
  // successful apply returns true → the package dismisses and
  // `closeGenerateDialog` runs; a rejected/failed apply returns false → the
  // package keeps the dialog open so the user's prompt + proposal survive, and
  // `closeGenerateDialog` never runs. `closeGenerateDialog` (bound to onClose)
  // remains the SINGLE close + focus site (round-5 #1). This ref tells that
  // close which way to send focus: a successful Apply → the panel's expression
  // field; a dismiss (×/Escape) → the panel's Generate button.
  const closingViaApplyRef = useRef(false)
  function closeGenerateDialog() {
    const wasApply = closingViaApplyRef.current
    closingViaApplyRef.current = false
    const request = state[GENERATE_REQUEST_KEY]
    const attribute = request?.attribute
    // Scope the focus lookup to the row's own settings drawer so a second open
    // drawer — or a group + child row sharing a class — can't be hit (round-5 #2).
    const root: ParentNode = request?.settingsRoot instanceof HTMLElement ? request.settingsRoot : document
    stores.surveyState.setState({ [GENERATE_REQUEST_KEY]: null })
    if (!attribute) {
      return
    }
    // Defer past the dialog unmount + inert clear (focusing an inert element is
    // a silent no-op). One timer, one target — no competing focus writes.
    window.setTimeout(() => {
      if (wasApply) {
        focusPanelInput(attribute, root) // P1.3 AC4
      } else {
        focusGenerateButton(attribute, root) // P1.1 AC6
      }
    }, 0)
  }

  // Bound to the package's onApply. Returns whether the expression was actually
  // persisted: true → the package dismisses the dialog (closeGenerateDialog runs
  // and focuses the panel input); false → the package keeps the dialog open so a
  // rejected/failed apply doesn't discard the user's prompt + proposal (round-6).
  // Never closes the dialog itself — closeGenerateDialog (onClose) is the single
  // close site (round-5 #1).
  function applyGeneratedExpression(expression: string): boolean {
    const request = state[GENERATE_REQUEST_KEY]
    if (!request?.row || !request?.attribute) {
      return false
    }
    // The write path lives in openclinica/applyExpression.ts (unit-tested);
    // this handler only maps the outcome onto user feedback + focus intent.
    const outcome = applyExpressionToRow(request.row, request.attribute, expression)
    if (outcome.status === 'applied') {
      // Persisted. Flag the focus target for the package-driven close (the
      // panel's expression field, not the Generate button) and report success.
      closingViaApplyRef.current = true
      return true
    }
    if (outcome.status === 'rejected') {
      // The facade could not represent the expression and dropped content;
      // applyExpressionToRow already reverted the write, so nothing was
      // persisted (round-5 #5, PR#273 deferred). Return false so the dialog
      // stays open for the user to adjust the prompt and retry.
      console.warn('Logic Builder: refused a lossy apply and reverted', outcome, request.attribute)
      if (outcome.unresolved.length > 0) {
        const names = outcome.unresolved.map((ref) => ref.replace(/^\$\{|\}$/g, '')).join(', ')
        alertify.error(
          t(
            'The generated expression references ##refs## which do not exist on this form, so it was not applied. Nothing was changed.',
          ).replace('##refs##', names),
        )
      } else {
        alertify.error(
          t(
            "The generated expression couldn't be represented by this panel's builder, so it was not applied. Nothing was changed.",
          ),
        )
      }
      return false
    }
    // status === 'error': missing RowDetail, detached row, or a throw mid-write.
    // Keep the dialog open (return false) so the proposal isn't lost.
    console.error('Logic Builder: could not apply generated expression —', outcome.reason, request.attribute)
    alertify.error(t('Could not apply the generated expression. Please try again.'))
    return false
  }

  // Defensive (PR#273 #2): if a generate request ever carries an attribute that
  // maps to no logic tab, the dialog can't render for it — clear the dangling
  // request (so a clicked Generate doesn't silently do nothing) and leave a
  // trace. Done in an effect, not during render, to avoid setState-in-render.
  // In practice unreachable: the Generate button is only mounted for mappable
  // columns (generateButtonBridge.mountGenerateButton).
  const generateRequest = state[GENERATE_REQUEST_KEY]
  // One tab lookup shared by the dangling-request effect, the inert effect,
  // and renderAiGeneratorDialog (review PR#286 — was recomputed per call site).
  const generateTab = generateRequest?.attribute ? columnToTab(generateRequest.attribute) : undefined
  useEffect(() => {
    if (generateRequest?.attribute && !generateTab) {
      console.warn(
        'Logic Builder: no logic tab maps to the generate-request attribute; clearing it',
        generateRequest.attribute,
      )
      stores.surveyState.setState({ [GENERATE_REQUEST_KEY]: null })
    }
  }, [generateRequest, generateTab])

  // OC fork (P1.1 AC2 "scrollable but inert", design §5.4): while the AI
  // Generator dialog is open, inert the builder's interactive regions — the
  // aside, the header, and the contents-inner wrapper — but never the scroll
  // container itself. Inerting the whole .form-builder-wrapper (the original
  // approach, via the package's inertRoot) made hit-testing skip the scroller
  // too, so wheel events never reached it and the form stopped scrolling.
  // Owned by the host because the inert boundary is host-DOM-specific.
  const generateDialogOpen = Boolean(generateRequest?.row && generateTab)
  useBuilderInert(generateDialogOpen, formBuilderWrapRef, builderContentsInnerRef)

  function renderAiGeneratorDialog() {
    const request = generateRequest
    const tab = generateTab
    if (!request?.row || !tab) {
      // No dialog without a row, and none for an unmappable attribute — the
      // dangling-request effect above clears + logs the latter (PR#273 #2).
      // Can't reset state during render.
      return null
    }
    // Same reader the item definition uses, so the dialog header and the
    // prompt's TARGET ITEM can never name different items (review Minor 2).
    const itemName = readItemName(request.row)
    return (
      // P1.4 AC7: if the dialog crashes at render/runtime, degrade to no
      // dialog instead of unwinding the Form Designer tree. onCrash rides
      // the existing single close+focus site — closeGenerateDialog clears
      // GENERATE_REQUEST_KEY, which unmounts this boundary too, so the crash
      // latch naturally resets for the next Generate click.
      <LogicBuilderErrorBoundary onCrash={closeGenerateDialog}>
        <AiGeneratorDialog
          open
          scope={{
            itemName,
            attribute: tab,
            // P1.5: the whole form as a tree, this row marked as the target.
            form: buildFormContext(request.row),
          }}
          client={logicBuilderClient}
          // inertRoot deliberately NOT passed: the host owns the inert boundary
          // (see the builder-inert effect) because inerting the whole wrapper
          // would make the scroll container unhittable and break AC2's
          // "scrollable but inert".
          onApply={applyGeneratedExpression}
          // P1.3 AC2: live raw read of the panel editor at Apply-click time —
          // drives the dialog's inline overwrite confirmation.
          getCurrentExpression={() => readCurrentExpression(request.row, request.attribute)}
          onClose={closeGenerateDialog}
        />
      </LogicBuilderErrorBoundary>
    )
  }

  function onStyleChange(newStyle: FormStyleDefinition) {
    const settingsStyle: FormStyleName = newStyle.value

    setState((currentState) => ({
      ...currentState,
      settings__style: settingsStyle,
    }))
    // OC fork: cache the selected form style so it survives a re-launch.
    sessionStorage.setItem(FORM_STYLE_CACHE_NAME, settingsStyle ?? '')
    // OC fork: notify open Question Options panels to re-render grid-only
    // sections (Columns in Grid, Item Width) immediately on style change.
    document.dispatchEvent(new CustomEvent('ocFormStyleChange'))
    onSurveyChangeDebounced()
  }

  // OC fork: form id and version number round-trip through the form settings.
  // Keep the raw string (even when empty) so that clearing the field persists,
  // mirroring the fork. The save-time `!== undefined` guard still skips fields
  // the user never touched (state initializes them as undefined).
  function onVersionChange(val: string) {
    setState((currentState) => ({
      ...currentState,
      settings__version: val,
    }))
    onSurveyChangeDebounced()
  }

  function onFormIdChange(val: string) {
    setState((currentState) => ({
      ...currentState,
      settings__form_id: val,
    }))
    onSurveyChangeDebounced()
  }

  function onSurveyChange() {
    // OC fork: notify the host (study-runner iframe) that there are unsaved changes.
    window.parent.postMessage('form_saveneeded', '*')
    if (!state.asset_updated !== update_states.UNSAVED_CHANGES) {
      preventClosingTab()
    }
    setState((currentState) => ({
      ...currentState,
      asset_updated: update_states.UNSAVED_CHANGES,
    }))
  }

  function preventClosingTab() {
    setState((currentState) => ({
      ...currentState,
      preventNavigatingOut: true,
    }))
    $(window).on('beforeunload.noclosetab', () => UNSAVED_CHANGES_WARNING)
  }

  function unpreventClosingTab() {
    setState((currentState) => ({
      ...currentState,
      preventNavigatingOut: false,
    }))
    $(window).off('beforeunload.noclosetab')
  }

  function nameChange(evt: React.ChangeEvent<HTMLInputElement>) {
    setState((currentState) => ({
      ...currentState,
      name: assetUtils.removeInvalidChars(evt.target.value),
    }))
    onSurveyChangeDebounced()
  }

  function groupQuestions() {
    app?.groupSelectedRows()
  }

  // OC fork: extra toolbar actions. These methods exist on the CoffeeScript SurveyApp
  // but are not declared in its TS typings, so we reach them via a loose cast.
  function deleteQuestions() {
    ;(app as unknown as { deleteSelectedRows?: () => void })?.deleteSelectedRows?.()
  }

  function duplicateQuestions() {
    ;(app as unknown as { duplicateSelectedRows?: () => void })?.duplicateSelectedRows?.()
  }

  function addQuestionsToLibrary() {
    ;(app as unknown as { addSelectedRowsToLibrary?: () => void })?.addSelectedRowsToLibrary?.()
  }

  function showAll(evt: React.TouchEvent<HTMLButtonElement>) {
    evt.preventDefault()
    evt.currentTarget.blur()
    app?.expandMultioptions()
  }

  function hasMetadataAndDetails() {
    return (
      app &&
      state.asset &&
      (state.asset.asset_type === ASSET_TYPES.survey.id ||
        state.asset.asset_type === ASSET_TYPES.template.id ||
        state.desiredAssetType === ASSET_TYPES.template.id)
    )
  }

  // OC fork: OpenClinica hides the upstream Metadata / Details aside sections.
  function hideMetadata() {
    return true
  }

  function hideDetails() {
    return true
  }

  // OC fork: account-scoped permission checks for the "Add to Library" toolbar action.
  // `customer_shared_infra` is being added to the account type by a sibling change;
  // cast until that lands so this file stays type-clean.
  function isSharedInfraEnabled() {
    return (sessionStore.currentAccount as { customer_shared_infra?: boolean }).customer_shared_infra === true
  }

  function isUserAdmin() {
    return sessionStore.currentAccount.user_type === OC_USER_TYPES.BUSINESS_ADMIN
  }

  function canAddToLibrary() {
    return !isSharedInfraEnabled() || isUserAdmin()
  }

  function needsSave() {
    return state.asset_updated === update_states.UNSAVED_CHANGES
  }

  /**
   * Fetches the asset's current saved state, used by previewForm()/saveForm()
   * to resolve the form's actual current primary language and translations
   * instead of the live model's frozen mount-time snapshot (see the comment
   * on `applyFreshPrimaryLanguage` usage in both functions for why).
   */
  async function fetchFreshAsset(
    uid: string,
  ): Promise<{ freshAsset: AssetResponse | undefined; fetchFailed: boolean }> {
    if (uid === '') {
      return { freshAsset: undefined, fetchFailed: false }
    }
    try {
      const freshAsset = await dataInterface.getAsset({ id: uid })
      return { freshAsset, fetchFailed: false }
    } catch {
      return { freshAsset: undefined, fetchFailed: true }
    }
  }

  async function previewForm(evt: React.TouchEvent<HTMLButtonElement>) {
    // At this point app should really be defined, and if not, there is no point in doing anything
    if (!app) {
      console.error('app is not defined!')
      return
    }

    if (evt && evt.preventDefault) {
      evt.preventDefault()
    }

    if (state.settings__style !== undefined) {
      app?.survey.settings.set('style', state.settings__style)
    }

    if (state.name) {
      app?.survey.settings.set('title', state.name)
    }

    let surveyJSON = surveyToValidJson(app?.survey)

    // Fetch the current saved asset up front, rather than gating unnullify/
    // merge on the live model's frozen mount-time primary-language snapshot
    // (`app.survey._initialParams`, set once in the Survey constructor and
    // never updated — see model.survey.coffee). A primary language set for
    // the first time in this session would otherwise never be picked up,
    // since `_initialParams.translations_0` stays permanently unset for any
    // form that had no primary language when Form Designer first loaded.
    // A failed fetch just falls back to the live model's own (possibly stale
    // or language-blind) translations rather than blocking preview.
    const { freshAsset } = await fetchFreshAsset(assetUid)
    const primaryLangResult = applyFreshPrimaryLanguage(surveyJSON, freshAsset?.content, app?.survey._initialParams)
    surveyJSON = primaryLangResult.surveyDataJSON
    const primaryLangName = primaryLangResult.primaryLangName

    let params: KoboMatrixParserParams & {
      asset?: string
      use_study_designer_preview?: boolean
    } = { source: surveyJSON, use_study_designer_preview: true }

    if (state.asset && state.asset.url) {
      params.asset = state.asset.url
    }

    if (freshAsset?.content && primaryLangName) {
      // Only protect the primary language from the merge when there's an
      // actual unsaved local edit pending in this session (`needsSave()`).
      // Without that, the common case — translate the primary language via
      // Translations Table, then Preview without having touched anything
      // inline — would keep showing the stale primary-language text for no
      // reason, since there's nothing local left to protect.
      const protectedLangName = needsSave() ? primaryLangName : null
      surveyJSON = mergeFreshTranslations(surveyJSON, freshAsset.content, protectedLangName)
      params.source = surveyJSON
    }

    params = koboMatrixParser(params)

    dataInterface
      .createAssetSnapshot(params)
      .done((content: AssetSnapshotResponse) => {
        setState((currentState) => ({
          ...currentState,
          enketopreviewOverlay: content.enketopreviewlink,
        }))
      })
      .fail((jqxhr: FailResponse) => {
        let err
        if (jqxhr && jqxhr.responseJSON && jqxhr.responseJSON.error) {
          err = jqxhr.responseJSON.error
        } else {
          err = t('Unknown Enketo preview error')
        }
        setState((currentState) => ({
          ...currentState,
          enketopreviewError: err,
        }))
      })
  }

  async function saveForm(evt: React.TouchEvent<HTMLButtonElement>) {
    if (evt && evt.preventDefault) {
      evt.preventDefault()
    }
    // At this point app should really be defined, and if not, there is no point in doing anything
    if (!app) {
      console.error('app is not defined!')
      return
    }

    if (state.settings__style !== undefined) {
      app.survey.settings.set('style', state.settings__style)
    }

    // OC fork: persist the form id and version number into the form settings.
    if (state.settings__version !== undefined) {
      app.survey.settings.set('version', state.settings__version)
    }

    if (state.settings__form_id !== undefined) {
      app.survey.settings.set('form_id', state.settings__form_id)
    }

    // OC fork: eConsent save-time guard. Only one signature item is allowed and it
    // must have a single response option with value "1".
    const consentRows = app.survey.rows.filter((row) => isEConsentSignatureRow(row))
    if (consentRows.length > 0) {
      if (consentRows.length > 1) {
        alertify.defaults.theme.ok = 'ajs-cancel'
        const dialog = alertify.dialog('alert')
        dialog
          .set({
            title: t('Error saving form'),
            message: t('Consent forms can have only one signature item.'),
            label: t('Dismiss'),
          })
          .show()
        return
      } else {
        const consentRow = consentRows[0] as unknown as { getConsentItemChoiceValue?: () => string }
        if (consentRow.getConsentItemChoiceValue?.() !== '1') {
          alertify.defaults.theme.ok = 'ajs-cancel'
          const dialog = alertify.dialog('alert')
          dialog
            .set({
              title: t('Error saving form'),
              message: t('Consent items must have a value of "1"'),
              label: t('Dismiss'),
            })
            .show()
          return
        }
      }
    }

    let surveyJSON = surveyToValidJson(app.survey)
    const surveyJSONWithMatrix = koboMatrixParser({ source: surveyJSON }).source
    if (surveyJSONWithMatrix) {
      surveyJSON = surveyJSONWithMatrix
    }

    // Fetch the current saved asset up front, rather than gating unnullify/
    // merge on the live model's frozen mount-time primary-language snapshot
    // (`app.survey._initialParams`, set once in the Survey constructor and
    // never updated — see model.survey.coffee, and the same comment in
    // previewForm()). Only relevant once the asset actually exists server-side.
    const { freshAsset, fetchFailed: freshFetchFailed } = await fetchFreshAsset(assetUid)

    // If the live model has never known about a primary language this
    // session (i.e. one was set for the first time via Manage Languages,
    // after this page loaded) AND we couldn't confirm the asset's actual
    // current language state from the server, saving now would silently
    // overwrite (delete) any language(s) added this session — abort rather
    // than risk it.
    if (assetUid !== '' && !app.survey._initialParams?.translations_0 && freshFetchFailed) {
      alertify.defaults.theme.ok = 'ajs-cancel'
      const dialog = alertify.dialog('alert')
      dialog
        .set({
          title: t('Error saving form'),
          message: t("Could not verify the form's current languages before saving. Please try again."),
          label: t('Dismiss'),
        })
        .show()
      return
    }

    const primaryLangResult = applyFreshPrimaryLanguage(surveyJSON, freshAsset?.content, app.survey._initialParams)
    surveyJSON = primaryLangResult.surveyDataJSON
    const primaryLangName = primaryLangResult.primaryLangName

    // We normally have `content` as an actual object, not a stringified representation, but since
    // `actions.resources.updateAsset` already works with JSON string, let's extend the types
    const params: Partial<AssetRequestObject> & { content: string } = { content: surveyJSON }

    if (state.name) {
      params.name = state.name
    }

    if (state.isNewAsset) {
      setState((currentState) => ({
        ...currentState,
        asset_updated: update_states.PENDING_UPDATE,
      }))
      // we're intentionally leaving after creating new asset,
      // so there is nothing unsaved here
      unpreventClosingTab()

      // create new asset
      if (state.desiredAssetType) {
        params.asset_type = state.desiredAssetType
      } else {
        params.asset_type = AssetTypeName.block
      }
      if (props.parentAssetUid) {
        params.parent = assetUtils.buildAssetUrl(props.parentAssetUid)
      }
      actions.resources.createResource.triggerAsync(params).then(() => {
        // OC fork: tell the host iframe the save is done and always return to the Library.
        window.parent.postMessage('form_savecomplete', '*')
        props.router.navigate(ROUTES.LIBRARY)
      })
    } else if (assetUid !== '') {
      setState((currentState) => ({
        ...currentState,
        asset_updated: update_states.PENDING_UPDATE,
      }))

      if (freshAsset?.content && primaryLangName) {
        // Only protect the primary language when there was an actual unsaved
        // local edit pending before this save started (`needsSave()`, read
        // here before it flips to PENDING_UPDATE above — the `state` this
        // closure captured at render time doesn't change until next
        // render, so this still reads the pre-save value). See the same
        // comment in previewForm() for why this matters.
        const protectedLangName = needsSave() ? primaryLangName : null
        params.content = mergeFreshTranslations(params.content, freshAsset.content, protectedLangName)
      }

      // TODO: change this into react-query mutation
      actions.resources.updateAsset
        .triggerAsync(assetUid, params)
        .then(() => {
          // OC fork: tell the host iframe the save is done.
          window.parent.postMessage('form_savecomplete', '*')
          unpreventClosingTab()
          // We need to invalidate it here to force it to fetch fresh data. Without this a bug will happen with Form
          // Builder showing old data in some scenarios (e.g. after closing Form Builder and immediately visiting again).
          invalidateItem(getAssetsRetrieveQueryKey(assetUid))
          setState((currentState) => ({
            ...currentState,
            asset_updated: update_states.UP_TO_DATE,
            surveySaveFail: false,
          }))
        })
        .catch((resp: FailResponse) => {
          var errorMsg = `${t('Your changes could not be saved, likely because of a lost internet connection.')}&nbsp;${t('Keep this window open and try saving again while using a better connection.')}&nbsp;${t('Please contact your administrator if this message persists.')}`
          if (resp.statusText !== 'error') {
            errorMsg = escapeHtml(resp.statusText)
          }

          alertify.defaults.theme.ok = 'ajs-cancel'
          const dialog = alertify.dialog('alert')
          const opts = {
            title: t('Error saving form'),
            message: errorMsg,
            label: t('Dismiss'),
          }
          dialog.set(opts).show()

          setState((currentState) => ({
            ...currentState,
            surveySaveFail: true,
            asset_updated: update_states.SAVE_FAILED,
          }))
        })
    }
  }

  function buttonStates() {
    var ooo: EditableFormButtonStates = {}
    if (app) {
      ooo.previewDisabled = true
      if (app && app.survey) {
        ooo.previewDisabled = app.survey.rows.length < 1
      }
      ooo.groupable = !!state.groupButtonIsActive
      ooo.showAllAvailable = (() => {
        var hasSelect = false
        app.survey.forEachRow((row) => {
          if (row._isSelectQuestion()) {
            hasSelect = true
          }
        })
        return hasSelect
      })()
      ooo.name = state.name
      ooo.hasSettings = state.backRoute === ROUTES.FORMS
      ooo.styleValue = state.settings__style
      // OC fork: form id and version number for the "Form information" aside row.
      ooo.versionValue = state.settings__version
      ooo.formIdValue = state.settings__form_id
    } else {
      ooo.allButtonsDisabled = true
    }

    // OC fork: context-dependent save/back button labels.
    const isNewLibraryAsset = state.backRoute === ROUTES.LIBRARY && !state.asset && state.isNewAsset === true

    let saveButtonText = t('save')
    let backButtonText = t('back')

    if (state.asset?.asset_type === ASSET_TYPES.survey.id) {
      saveButtonText = t('save draft')
    } else {
      // eslint-disable-next-line no-lonely-if
      if (isNewLibraryAsset) {
        saveButtonText = t('create')
      } else {
        saveButtonText = t('save changes')
      }
      if (state.backRoute === ROUTES.LIBRARY) {
        backButtonText = t('back to library')
      }
    }

    if (state.isNewAsset) {
      ooo.saveButtonText = t('create')
    } else if (state.surveySaveFail) {
      ooo.saveButtonText = `${saveButtonText} (${t('retry')}) `
    } else {
      ooo.saveButtonText = `${saveButtonText}`
    }
    ooo.backButtonText = `${backButtonText}`

    return ooo
  }

  function toggleAsideLibrarySearch(evt: React.TouchEvent<HTMLButtonElement>) {
    evt.currentTarget.blur()
    const asideSettings: AsideSettings = {
      asideLayoutSettingsVisible: false,
      asideLibrarySearchVisible: !state.asideLibrarySearchVisible,
    }
    setState((currentState) => ({
      ...currentState,
      ...asideSettings,
    }))
    saveAsideSettings(asideSettings)
  }

  function manageLanguages() {
    if (state.asset) {
      pageState.showModal({
        type: MODAL_TYPES.FORM_LANGUAGES,
        asset: state.asset,
        hasUnsavedChanges: needsSave(),
      })
    }
  }

  function toggleAsideLayoutSettings(evt: React.TouchEvent<HTMLButtonElement>) {
    evt.currentTarget.blur()
    const asideSettings: AsideSettings = {
      asideLayoutSettingsVisible: !state.asideLayoutSettingsVisible,
      asideLibrarySearchVisible: false,
    }
    setState((currentState) => ({
      ...currentState,
      ...asideSettings,
    }))
    saveAsideSettings(asideSettings)
  }

  function hidePreview() {
    setState((currentState) => ({
      ...currentState,
      enketopreviewOverlay: undefined,
    }))
  }

  function hideCascade() {
    setState((currentState) => ({
      ...currentState,
      showCascadePopup: false,
    }))
  }

  /**
   * Cleanup some things in the rendered app
   */
  function cleanupAppForSurveyContent() {
    if (app?.survey) {
      app.survey.off('change')
      app.survey.rows.off('change')
      app.survey.rows.off('sort')
    }
  }

  /**
   * The de facto function that is running our Form Builder survey editor app.
   * It builds `dkobo_xlform.view.SurveyApp` using asset data and then appends
   * it to `.form-wrap` node.
   */
  function launchAppForSurveyContent(assetContent?: AssetContent, _state?: LaunchAppData) {
    // If we already rendered the app in the formWrapRef container, there is no need to do it again. Without this check
    // we would end up adding copies of the app in HTML
    if (app !== undefined) {
      return
    }

    const newState: Partial<EditableFormState> & Partial<LaunchAppData> = _state || {}

    // asset content is being mutated somewhere during form builder initialisation
    // so we need to make sure this stays untouched
    const rawAssetContent = Object.freeze(clonedeep(assetContent))

    // OC fork: seed the form-style cache from the launched asset.
    sessionStorage.setItem(FORM_STYLE_CACHE_NAME, newState.settings__style ?? '')

    const isEmptySurvey =
      assetContent &&
      assetContent.settings &&
      recordKeys(assetContent.settings).length === 0 &&
      assetContent.survey?.length === 0

    let survey: Survey | null = null

    try {
      if (assetContent) {
        survey = dkobo_xlform.model.Survey.loadDict(clonedeep(assetContent))
        if (newState.files && newState.files.length > 0) {
          survey.availableFiles = newState.files
        }
        if (isEmptySurvey) {
          survey.surveyDetails.importDefaults()
        }
      } else {
        survey = dkobo_xlform.model.Survey.create()
      }
    } catch (err) {
      const errObject = (err as unknown as { message?: string }) || {}
      newState.surveyLoadError = errObject.message || 'dkobo_xlform failed'
      newState.surveyAppRendered = false
    }

    if (survey && !newState.surveyLoadError) {
      newState.surveyAppRendered = true

      var skp = new SurveyScope({
        survey: survey,
        rawSurvey: rawAssetContent,
        assetType: getFormBuilderAssetType(state.asset?.asset_type, state.desiredAssetType),
      })

      const newApp = new dkobo_xlform.view.SurveyApp({
        survey: survey,
        stateStore: stores.surveyState,
        ngScope: skp,
        // OC fork: gate the "Add to Library" row action by account permissions.
        // Not declared in SurveyAppOptions typings, so cast the options object.
        canAddToLibrary: canAddToLibrary(),
      } as ConstructorParameters<typeof dkobo_xlform.view.SurveyApp>[0])

      setApp(newApp)

      const formWrapEl = formWrapRef.current

      if (formWrapEl instanceof Element === false) {
        throw new Error('form-wrap element not found!')
      }

      newApp.$el.appendTo(formWrapEl)
      newApp.render()
      survey.rows.on('change', onSurveyChange)
      survey.rows.on('sort', onSurveyChange)
      survey.on('change', onSurveyChange)
    }

    setState((currentState) => ({
      ...currentState,
      ...newState,
    }))
  }

  function clearPreviewError() {
    setState((currentState) => ({
      ...currentState,
      enketopreviewError: undefined,
    }))
  }

  // OC fork: derive the parent collection uid from the asset's `parent` URL.
  function getParentUid() {
    if (state.asset?.parent) {
      const parentArr = state.asset.parent.split('/')
      const parentAssetUid = parentArr[parentArr.length - 2]
      return parentAssetUid
    } else {
      return null
    }
  }

  function safeNavigateToList() {
    // OC fork: notify the host iframe that we are leaving the form builder.
    window.parent.postMessage('form_savecomplete', '*')
    if (state.backRoute) {
      props.router.navigate(state.backRoute)
    } else if (props.router.location.pathname.startsWith(ROUTES.LIBRARY)) {
      props.router.navigate(ROUTES.LIBRARY)
    } else {
      props.router.navigate(ROUTES.FORMS)
    }
  }

  // OC fork: navigate back to the parent collection (or the library root when the
  // asset has no parent).
  function safeNavigateToCollection() {
    // OC fork: notify the host iframe that we are leaving the form builder.
    window.parent.postMessage('form_savecomplete', '*')
    let targetRoute = state.backRoute
    if (state.backRoute === ROUTES.LIBRARY) {
      const parentUid = getParentUid()
      if (parentUid) {
        targetRoute = ROUTES.LIBRARY_ITEM.replace(':uid', parentUid)
      } else {
        targetRoute = ROUTES.LIBRARY
      }
    }
    if (targetRoute) {
      props.router.navigate(targetRoute)
    }
  }

  function safeNavigateToAsset() {
    if (!state.asset || !state.backRoute) {
      return
    }

    // OC fork: notify the host iframe that we are leaving the form builder.
    window.parent.postMessage('form_savecomplete', '*')

    let targetRoute = state.backRoute
    if (state.backRoute === ROUTES.FORMS) {
      if (assetUid !== '') {
        targetRoute = ROUTES.FORM.replace(':uid', assetUid)
      }
    } else if (state.backRoute === ROUTES.LIBRARY) {
      // Check if the the uid is undefined to prevent getting an Access Denied screen
      if (assetUid !== '') {
        targetRoute = ROUTES.LIBRARY_ITEM.replace(':uid', assetUid)
      }
    }

    props.router.navigate(targetRoute)
  }

  // OC fork: gate the "back to list" header button. Only show it for non-survey
  // assets or while on a "/library/new" creation route.
  function canNavigateToList() {
    return (
      state.surveyAppRendered &&
      (state.asset?.asset_type !== ASSET_TYPES.survey.id || props.router.location.pathname.startsWith('/library/new'))
    )
  }

  function isAddingQuestionsRestricted() {
    return (
      state.asset?.content &&
      isAssetLockable(state.asset.asset_type) &&
      hasAssetRestriction(state.asset.content, LockingRestrictionName.question_add)
    )
  }

  function isAddingGroupsRestricted() {
    return (
      state.asset?.content &&
      isAssetLockable(state.asset.asset_type) &&
      hasAssetRestriction(state.asset.content, LockingRestrictionName.group_add)
    )
  }

  function isChangingAppearanceRestricted() {
    return (
      state.asset?.content &&
      isAssetLockable(state.asset.asset_type) &&
      hasAssetRestriction(state.asset.content, LockingRestrictionName.form_appearance)
    )
  }

  function isChangingMetaQuestionsRestricted() {
    return (
      state.asset?.content &&
      isAssetLockable(state.asset.asset_type) &&
      hasAssetRestriction(state.asset.content, LockingRestrictionName.form_meta_edit)
    )
  }

  function hasBackgroundAudio() {
    return app?.survey?.surveyDetails.filter(
      (sd: SurveyDetail) => sd.attributes.name === QuestionTypeName['background-audio'],
    )[0].attributes.value
  }

  // rendering methods

  function renderFormBuilderHeader() {
    const { previewDisabled, groupable, showAllAvailable, saveButtonText, backButtonText } = buttonStates()

    return (
      <bem.FormBuilderHeader>
        {/* OC fork: dropped the kobo logo cell (form designer runs inside the
            study-runner iframe, where a KoboToolbox logo is the wrong context). */}
        <bem.FormBuilderHeader__row m='primary'>
          <bem.FormBuilderHeader__cell m='name'>
            <bem.FormModal__item>
              {renderAssetLabel()}
              <input
                type='text'
                maxLength={NAME_MAX_LENGTH}
                onChange={nameChange}
                value={state.name}
                title={state.name}
                id='nameField'
                dir='auto'
              />
            </bem.FormModal__item>
          </bem.FormBuilderHeader__cell>

          <bem.FormBuilderHeader__cell m={'buttonsTopRight'}>
            {/* OC fork: replaced upstream's close (X) button with an outlined "back"
                button, gated by canNavigateToList(). Shown before Save. */}
            {canNavigateToList() && (
              <Button
                type='secondary'
                size='l'
                isUpperCase
                isDisabled={!state.surveyAppRendered || !!state.surveyLoadError}
                onClick={safeNavigateToList}
                label={backButtonText}
              />
            )}

            <Button
              type='primary'
              size='l'
              isPending={state.asset_updated === update_states.PENDING_UPDATE}
              isDisabled={!state.surveyAppRendered || !!state.surveyLoadError}
              onClick={saveForm}
              isUpperCase
              label={
                <>
                  {saveButtonText}
                  {state.asset_updated === update_states.SAVE_FAILED || (needsSave() && <>&nbsp;*</>)}
                </>
              }
            />
          </bem.FormBuilderHeader__cell>
        </bem.FormBuilderHeader__row>

        <bem.FormBuilderHeader__row m={'secondary'}>
          <bem.FormBuilderHeader__cell m={'toolsButtons'}>
            <Button
              type='text'
              size='m'
              isDisabled={previewDisabled}
              onClick={previewForm}
              tooltip={t('Preview form')}
              tooltipPosition='left'
              startIcon='view'
            />

            <Button
              type='text'
              size='m'
              isDisabled={!showAllAvailable}
              onClick={showAll}
              tooltip={t('Expand / collapse questions')}
              tooltipPosition='left'
              startIcon='view-all'
            />

            <Button
              type='text'
              size='m'
              isDisabled={!groupable}
              onClick={groupQuestions}
              tooltip={
                groupable
                  ? t('Create group with selected questions')
                  : t('Grouping disabled. Please select at least one question.')
              }
              tooltipPosition='left'
              startIcon='group'
              className={cx({
                [LOCKING_UI_CLASSNAMES.DISABLED]: isAddingGroupsRestricted(),
              })}
            />

            {/* OC fork: delete / duplicate / add-to-library row actions. Like the
                group button, these operate on the selected questions and so are
                disabled when nothing is selected (i.e. !groupable). */}
            <Button
              type='text'
              size='m'
              isDisabled={!groupable}
              onClick={deleteQuestions}
              tooltip={
                groupable
                  ? t('Delete selected questions')
                  : t('Delete questions disabled. Please select at least one question.')
              }
              tooltipPosition='left'
              startIcon='trash'
            />

            <Button
              type='text'
              size='m'
              isDisabled={!groupable}
              onClick={duplicateQuestions}
              tooltip={
                groupable
                  ? t('Duplicate selected questions')
                  : t('Duplicate questions disabled. Please select at least one question.')
              }
              tooltipPosition='left'
              startIcon='duplicate'
            />

            {canAddToLibrary() && (
              <span
                className='button-container left-tooltip'
                data-tip={
                  groupable
                    ? t('Add selected questions to library')
                    : t('Add selected questions to library disabled. Please select at least one question.')
                }
              >
                <bem.FormBuilderHeader__button
                  m={['group', { groupable: !!groupable }]}
                  onClick={addQuestionsToLibrary}
                  disabled={!groupable}
                  className='add-questions-to-library'
                >
                  <i className='k-icon-folder'>
                    <i className='k-icon-plus' />
                  </i>
                </bem.FormBuilderHeader__button>
              </span>
            )}

            {/* OpenClinica: cascading select not available */}
          </bem.FormBuilderHeader__cell>

          <bem.FormBuilderHeader__cell m='verticalRule' />

          <bem.FormBuilderHeader__cell m='spacer' />

          {/* OC fork: link to the OpenClinica Form Designer help docs. */}
          <bem.FormBuilderHeader__cell m='supportUrl'>
            <a href={FORM_DESIGNER_SUPPORT_URL} target='_blank' data-tip={t('Learn more about Form Designer')}>
              <i className='k-icon k-icon-help' />
            </a>
          </bem.FormBuilderHeader__cell>

          <bem.FormBuilderHeader__cell m='verticalRule' />

          {state.asset?.asset_type === ASSET_TYPES.survey.id && (
            <bem.FormBuilderHeader__cell>
              <Button
                type='text'
                size='m'
                onClick={manageLanguages}
                tooltip={t('Manage languages for this form')}
                tooltipPosition='left'
                startIcon='language'
                label={t('Manage Languages')}
              />
            </bem.FormBuilderHeader__cell>
          )}

          {state.asset?.asset_type === ASSET_TYPES.survey.id && <bem.FormBuilderHeader__cell m={'verticalRule'} />}

          <bem.FormBuilderHeader__cell>
            <Button
              type='text'
              size='m'
              onClick={toggleAsideLibrarySearch}
              tooltip={t('Add an item from the library')}
              tooltipPosition='left'
              startIcon={state.asideLibrarySearchVisible ? 'close' : 'library'}
              label={t('Add from Library')}
            />
          </bem.FormBuilderHeader__cell>

          <bem.FormBuilderHeader__cell m={'verticalRule'} />

          <bem.FormBuilderHeader__cell>
            <Button
              type='text'
              size='m'
              onClick={toggleAsideLayoutSettings}
              tooltip={hasMetadataAndDetails() ? t('Change form layout and settings') : t('Change form layout')}
              tooltipPosition='right'
              startIcon={state.asideLayoutSettingsVisible ? 'close' : 'settings'}
              label={hasMetadataAndDetails() ? t('Layout & Settings') : t('Layout')}
            />
          </bem.FormBuilderHeader__cell>
        </bem.FormBuilderHeader__row>
      </bem.FormBuilderHeader>
    )
  }

  function renderBackgroundAudioWarning() {
    if (state.isBackgroundAudioBannerDismissed) return null
    let bannerText = t(
      'This form will automatically [record audio in the background](##SUPPORT_LINK##). Consider adding with a meaningful consent question to inform respondents or data collectors that they will be recorded while completing this survey.',
    )

    if (envStore.isReady && envStore.data.support_url) {
      bannerText = bannerText.replace('##SUPPORT_LINK##', envStore.data.support_url + RECORDING_SUPPORT_URL)
    } else {
      // Replaces the link for the text only if link is not available
      bannerText = bannerText.replace(/\[(.+)]\(##SUPPORT_LINK##\)/, '$1')
    }

    return (
      <Alert
        type='info'
        iconName='information'
        p='sm'
        maw={1024}
        mb='sm'
        m='auto'
        closeButtonLabel={t('Dismiss')}
        onClose={() => {
          setState((currentState) => ({
            ...currentState,
            isBackgroundAudioBannerDismissed: true,
          }))
        }}
        withCloseButton
      >
        <Markdown
          components={{
            // Custom link component to open link on target _blank
            a: (props) => (
              <a href={props.href} target='_blank'>
                {props.children}
              </a>
            ),
            // Custom paragraph component to use mantine Text instead of <p>
            p: (props) => (
              <Text c='blue.4' mr='lg'>
                {props.children}
              </Text>
            ),
          }}
        >
          {bannerText}
        </Markdown>
      </Alert>
    )
  }

  function renderAside() {
    const { styleValue, versionValue, formIdValue } = buttonStates()

    const isAsideVisible = state.asideLayoutSettingsVisible || state.asideLibrarySearchVisible

    return (
      <bem.FormBuilderAside m={isAsideVisible ? 'visible' : null}>
        {state.asideLayoutSettingsVisible && (
          <bem.FormBuilderAside__content>
            <bem.FormBuilderAside__row>
              {/* OC fork: dropped the kobo "form styles" help anchor; OpenClinica
                  surfaces its own Form Designer help link in the header instead. */}
              <bem.FormBuilderAside__header>{t('Form style')}</bem.FormBuilderAside__header>

              <FormStyleCardGrid
                styleValue={styleValue}
                onChange={onStyleChange}
                isDisabled={isChangingAppearanceRestricted()}
              />
            </bem.FormBuilderAside__row>

            {/* OC fork: form id and version number, round-tripped through form settings. */}
            <bem.FormBuilderAside__row>
              <bem.FormBuilderAside__header>{t('Form information')}</bem.FormBuilderAside__header>

              <bem.FormModal__item>
                <TextBox type='text' label={t('Form ID')} value={formIdValue || ''} onChange={onFormIdChange} />
              </bem.FormModal__item>

              <bem.FormModal__item>
                <TextBox
                  type='text'
                  label={t('Version number')}
                  value={versionValue || ''}
                  onChange={onVersionChange}
                />
              </bem.FormModal__item>
            </bem.FormBuilderAside__row>

            {hasMetadataAndDetails() && !hideMetadata() && (
              <bem.FormBuilderAside__row>
                <bem.FormBuilderAside__header>{t('Metadata')}</bem.FormBuilderAside__header>

                <MetadataEditor
                  survey={app?.survey}
                  onChange={onMetadataEditorChange}
                  isDisabled={isChangingMetaQuestionsRestricted()}
                  {...state}
                />
              </bem.FormBuilderAside__row>
            )}
          </bem.FormBuilderAside__content>
        )}

        {state.asideLibrarySearchVisible && (
          <bem.FormBuilderAside__content
            className={isAddingQuestionsRestricted() ? LOCKING_UI_CLASSNAMES.DISABLED : ''}
          >
            <bem.FormBuilderAside__row>
              <bem.FormBuilderAside__header>{t('Search Library')}</bem.FormBuilderAside__header>
            </bem.FormBuilderAside__row>

            <bem.FormBuilderAside__row>
              <AssetNavigator
                onAdd={(uid: string) => {
                  app?.ngScope?.handleItem?.({
                    position: app.survey?.rows.length ?? 0,
                    itemUid: uid,
                  })
                }}
              />
            </bem.FormBuilderAside__row>
          </bem.FormBuilderAside__content>
        )}
      </bem.FormBuilderAside>
    )
  }

  function renderNotLoadedMessage() {
    if (state.surveyLoadError) {
      return (
        <ErrorMessage>
          <ErrorMessage__strong>{t('Error loading form:')}</ErrorMessage__strong>
          <p>{state.surveyLoadError}</p>
        </ErrorMessage>
      )
    }

    return <LoadingSpinner />
  }

  function renderAssetLabel() {
    if (!state.asset) {
      return null
    }

    const rawLabel = getFormBuilderAssetType(state.asset.asset_type, state.desiredAssetType)?.label || 'asset'
    const assetTypeLabel = rawLabel.charAt(0).toUpperCase() + rawLabel.slice(1)

    // Case 1: there is no asset yet (creting a new) or asset is not locked
    if (!state.asset?.content || !hasAssetAnyLocking(state.asset.content)) {
      return assetTypeLabel
      // Case 2: asset is locked fully or partially
    } else {
      let lockedLabel = t('Partially locked ##type##').replace('##type##', assetTypeLabel)
      if (isAssetAllLocked(state.asset.content)) {
        lockedLabel = t('Fully locked ##type##').replace('##type##', assetTypeLabel)
      }
      return (
        <span className='locked-asset-type-label'>
          <i className='k-icon k-icon-lock' />

          {lockedLabel}

          {envStore.isReady && envStore.data.support_url && (
            <a
              href={envStore.data.support_url + LOCKING_SUPPORT_URL}
              target='_blank'
              data-tip={t('Read more about Locking')}
            >
              <i className='k-icon k-icon-help' />
            </a>
          )}
        </span>
      )
    }
  }

  function toggleCascade() {
    var lastSelectedRow = last(app?.selectedRows()),
      lastSelectedRowIndex = lastSelectedRow ? app?.survey.rows.indexOf(lastSelectedRow) : -1

    setState((currentState) => ({
      ...currentState,
      showCascadePopup: !state.showCascadePopup,
      cascadeTextareaValue: '',
      cascadeLastSelectedRowIndex: lastSelectedRowIndex,
    }))
  }

  function cancelCascade() {
    setState((currentState) => ({
      ...currentState,
      cascadeReady: false,
      cascadeReadySurvey: undefined,
      cascadeTextareaValue: '',
      showCascadePopup: false,
    }))
  }

  function cascadePopupChange() {
    const cascadeEl = cascadeRef.current

    if (cascadeEl === null) {
      return
    }

    const textareaEl = cascadeEl as HTMLTextAreaElement

    var s: Partial<EditableFormState> & Pick<EditableFormState, 'cascadeTextareaValue'> = {
      cascadeTextareaValue: textareaEl.value,
    }
    // if (s.cascadeTextareaValue.length === 0) {
    //   return cancelCascade();
    // }
    try {
      var inp = dkobo_xlform.model.utils.split_paste(s.cascadeTextareaValue)
      var tmpSurvey = new dkobo_xlform.model.Survey({
        survey: [],
        choices: inp,
      })
      if (tmpSurvey.choices.length === 0) {
        throw new Error(
          // this message is presented to the user
          t('Paste your formatted table from excel in the box below.'),
        )
      }
      tmpSurvey.choices.at(0).create_corresponding_rows()
      /*
      tmpSurvey._addGroup({
        __rows: tmpSurvey.rows.models,
        label: '',
      });
      */
      var rowCount = tmpSurvey.rows.length
      if (rowCount === 0) {
        throw new Error(
          // this message is presented to the user
          t('Paste your formatted table from excel in the box below.'),
        )
      }
      s.cascadeReady = true
      s.cascadeReadySurvey = tmpSurvey
      s.cascadeMessage = {
        msgType: 'ready',
        addCascadeMessage: t('add cascade with # questions').replace('#', rowCount.toString()),
      }
    } catch (err) {
      const errObject = (err as unknown as { message?: string }) || {}
      s.cascadeReady = false
      s.cascadeMessage = {
        msgType: 'warning',
        message: errObject.message,
      }
    }
    setState((currentState) => ({
      ...currentState,
      ...s,
    }))
  }

  function renderCascadePopup() {
    return (
      <bem.CascadePopup>
        {state.cascadeMessage ? (
          <bem.CascadePopup__message m={state.cascadeMessage.msgType}>
            {state.cascadeMessage.message}
          </bem.CascadePopup__message>
        ) : (
          <bem.CascadePopup__message m='instructions'>
            {t('Paste your formatted table from excel in the box below.')}
          </bem.CascadePopup__message>
        )}

        {state.cascadeReady ? <bem.CascadePopup__message m='ready'>{t('OK')}</bem.CascadePopup__message> : null}

        <textarea ref={cascadeRef} onChange={cascadePopupChange} value={state.cascadeTextareaValue} />

        {envStore.isReady && envStore.data.support_url && (
          <div className='cascade-help right-tooltip'>
            <a
              href={envStore.data.support_url + CHOICE_LIST_SUPPORT_URL}
              target='_blank'
              data-tip={t('Learn more about importing cascading lists from Excel')}
            >
              <i className='k-icon k-icon-help' />
            </a>
          </div>
        )}

        <bem.CascadePopup__buttonWrapper>
          <Button
            type='primary'
            size='l'
            isDisabled={!state.cascadeReady}
            onClick={() => {
              if (state.cascadeReadySurvey) {
                app?.survey?.insertSurvey(state.cascadeReadySurvey, state.cascadeLastSelectedRowIndex)
                cancelCascade()
              }
            }}
            label={t('DONE')}
          />
        </bem.CascadePopup__buttonWrapper>
      </bem.CascadePopup>
    )
  }

  var docTitle = state.name || t('Untitled')

  if (!state.isNewAsset && !state.asset) {
    return (
      <DocumentTitle title={`${docTitle} | OpenClinica`}>
        <LoadingSpinner />
      </DocumentTitle>
    )
  }

  return (
    <DocumentTitle title={`${docTitle} | OpenClinica`}>
      <>
        {
          /*
            TODO: Try to fix quirks that arise from this <Prompt/> usage
            Issue: https://github.com/kobotoolbox/kpi/issues/4154
          */
          state.preventNavigatingOut && <Prompt />
        }
        <div className='form-builder-wrapper' ref={formBuilderWrapRef}>
          {renderAside()}

          <bem.FormBuilder>
            {renderFormBuilderHeader()}

            <bem.FormBuilder__contents>
              {/* OC fork (P1.1 AC2): layout-neutral wrapper so the AI dialog's
                  inert boundary can cover the scroller's CONTENT while the
                  scroll container itself stays hit-testable (scrollable). */}
              <div ref={builderContentsInnerRef} className='form-builder__contents-inner'>
                {state.asset && <FormLockedMessage asset={state.asset} />}

                {hasBackgroundAudio() && renderBackgroundAudioWarning()}

                <div ref={formWrapRef} className='form-wrap'>
                  {!state.surveyAppRendered && renderNotLoadedMessage()}
                </div>
              </div>
            </bem.FormBuilder__contents>
          </bem.FormBuilder>

          {state.enketopreviewOverlay && (
            <Modal open large onClose={hidePreview} title={t('Form Preview')}>
              <Modal.Body>
                <div className='enketo-holder'>
                  <iframe src={state.enketopreviewOverlay} />
                </div>
              </Modal.Body>
            </Modal>
          )}

          {!state.enketopreviewOverlay && state.enketopreviewError && (
            // This used to have `error` prop, but `modal.tsx` no longer has the prop. I am leaving this comment here
            // as I am not sure how to test this, and maybe the popup should appear differently?
            <Modal open onClose={clearPreviewError} title={t('Error generating preview')}>
              <Modal.Body>{state.enketopreviewError}</Modal.Body>
            </Modal>
          )}

          {state.showCascadePopup && (
            <Modal open onClose={hideCascade} title={t('Import Cascading Select Questions')}>
              <Modal.Body>{renderCascadePopup()}</Modal.Body>
            </Modal>
          )}

          {/* OC fork (P1.1): AI Generator dialog (portals to document.body itself). */}
          {renderAiGeneratorDialog()}
        </div>
      </>
    </DocumentTitle>
  )
}
