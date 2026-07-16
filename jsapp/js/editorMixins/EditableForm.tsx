import React, { useCallback, useEffect, useRef, useState } from 'react'

import { Text } from '@mantine/core'
import alertify from 'alertifyjs'
import cx from 'classnames'
import clonedeep from 'lodash.clonedeep'
import debounce from 'lodash.debounce'
import last from 'lodash.last'
import DocumentTitle from 'react-document-title'
import Markdown from 'react-markdown'
import { useBeforeUnload, useBlocker, unstable_usePrompt as usePrompt } from 'react-router-dom'
import Select from 'react-select'
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
  getFormBuilderAssetType,
  koboMatrixParser,
  surveyToValidJson,
  unnullifyTranslations,
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
  AVAILABLE_FORM_STYLES,
  AssetTypeName,
  type FormStyleDefinition,
  type FormStyleName,
  NAME_MAX_LENGTH,
  OC_USER_TYPES,
  QuestionTypeName,
  type UpdateStatesValue,
  update_states,
} from '#/constants'
import envStore from '#/envStore'
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

const ErrorMessage = makeBem(null, 'error-message')
const ErrorMessage__strong = makeBem(null, 'error-message__header', 'strong')
bem.CascadePopup = makeBem(null, 'cascade-popup')
bem.CascadePopup__message = makeBem(bem.CascadePopup, 'message')
bem.CascadePopup__buttonWrapper = makeBem(bem.CascadePopup, 'buttonWrapper')

const CHOICE_LIST_SUPPORT_URL = 'cascading_select.html'

// OC fork: OpenClinica Form Designer help docs and a sessionStorage cache for the
// selected form style.
const FORM_DESIGNER_SUPPORT_URL = 'https://docs.openclinica.com/oc4/help-index/form-designer/'
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

    stores.surveyState.listen(onSurveyStateChanged)

    return () => {
      // OC fork: drop the cached form style on unmount.
      sessionStorage.removeItem(FORM_STYLE_CACHE_NAME)
      unpreventClosingTab()
      cleanupAppForSurveyContent()
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

  function onStyleChange(newStyle: null | FormStyleDefinition) {
    let settingsStyle: FormStyleName | undefined
    if (newStyle !== null) {
      settingsStyle = newStyle.value
    }

    setState((currentState) => ({
      ...currentState,
      settings__style: settingsStyle,
    }))
    // OC fork: cache the selected form style so it survives a re-launch.
    sessionStorage.setItem(FORM_STYLE_CACHE_NAME, settingsStyle ?? '')
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

  function getStyleSelectVal(optionVal?: FormStyleName) {
    return AVAILABLE_FORM_STYLES.find((option) => option.value === optionVal)
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

  function previewForm(evt: React.TouchEvent<HTMLButtonElement>) {
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
    if (app?.survey._initialParams?.translations_0) {
      surveyJSON = unnullifyTranslations(surveyJSON, app.survey._initialParams)
    }
    let params: KoboMatrixParserParams & { asset?: string } = { source: surveyJSON }

    params = koboMatrixParser(params)

    if (state.asset && state.asset.url) {
      params.asset = state.asset.url
    }

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

  function saveForm(evt: React.TouchEvent<HTMLButtonElement>) {
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
    if (app.survey._initialParams?.translations_0) {
      surveyJSON = unnullifyTranslations(surveyJSON, app.survey._initialParams)
    }
    // We normally have `content` as an actual object, not a stringified representation, but since
    // `actions.resources.updateAsset` already works with JSON string, let's extend the types
    const params: Partial<AssetRequestObject> & { content: string } = { content: surveyJSON }

    if (state.name) {
      params.name = state.name
    }

    if (state.isNewAsset) {
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
    setState((currentState) => ({
      ...currentState,
      asset_updated: update_states.PENDING_UPDATE,
    }))
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
              tooltipPosition='left'
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
    const { styleValue, versionValue, formIdValue, hasSettings } = buttonStates()

    const isAsideVisible = state.asideLayoutSettingsVisible || state.asideLibrarySearchVisible

    return (
      <bem.FormBuilderAside m={isAsideVisible ? 'visible' : null}>
        {state.asideLayoutSettingsVisible && (
          <bem.FormBuilderAside__content>
            <bem.FormBuilderAside__row>
              {/* OC fork: dropped the kobo "form styles" help anchor; OpenClinica
                  surfaces its own Form Designer help link in the header instead. */}
              <bem.FormBuilderAside__header>{t('Form style')}</bem.FormBuilderAside__header>

              <label className='kobo-select__label' htmlFor='webform-style'>
                {hasSettings
                  ? t('Select the form style that you would like to use. This will only affect web forms.')
                  : t(
                      'Select the form style. This will only affect the Enketo preview, and it will not be saved with the question or block.',
                    )}
              </label>

              <Select
                className='kobo-select'
                classNamePrefix='kobo-select'
                id='webform-style'
                name='webform-style'
                value={getStyleSelectVal(styleValue)}
                onChange={onStyleChange}
                placeholder={AVAILABLE_FORM_STYLES[0].label}
                options={AVAILABLE_FORM_STYLES}
                menuPlacement='bottom'
                isDisabled={isChangingAppearanceRestricted()}
                isSearchable={false}
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
              <AssetNavigator />
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
        <div className='form-builder-wrapper'>
          {renderAside()}

          <bem.FormBuilder>
            {renderFormBuilderHeader()}

            <bem.FormBuilder__contents>
              {state.asset && <FormLockedMessage asset={state.asset} />}

              {hasBackgroundAudio() && renderBackgroundAudioWarning()}

              <div ref={formWrapRef} className='form-wrap'>
                {!state.surveyAppRendered && renderNotLoadedMessage()}
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
        </div>
      </>
    </DocumentTitle>
  )
}
