import clonedeep from 'lodash.clonedeep'
import { ECONSENT_SIGNATURE_EXTERNAL_VALUE } from '#/components/formBuilder/econsentSignature'
import { ASSET_TYPES, type AssetTypeName, GroupTypeBeginName, GroupTypeEndName } from '#/constants'
import type { AssetContent } from '#/dataInterface'
import type { KoboMatrixPlainData } from '#/formbuild/containers/KoboMatrix'
import { recordKeys } from '#/utils'
import type { FlatRow, FlatSurvey, Survey } from '../../../xlform/src/model.survey'

/**
 * Asset type could be either the loaded asset type (editing an existing form)
 * or the desired asset type (creating a new form)
 */
export function getFormBuilderAssetType(assetType?: AssetTypeName, desiredAssetType?: AssetTypeName) {
  if (assetType && ASSET_TYPES[assetType]) {
    return ASSET_TYPES[assetType]
  } else if (desiredAssetType && ASSET_TYPES[desiredAssetType]) {
    return ASSET_TYPES[desiredAssetType]
  }
  return null
}

// OC-27875/OC-28719: these XLSForm row settings are not supported on
// eConsent signature items. Form Designer's row settings drawer already
// clears `bind::oc:itemgroup` for signature rows as a render side effect
// (view.row.coffee), but that never runs for a row whose drawer was never
// opened - e.g. one loaded from an import - so a stale value round-trips
// through save/reopen untouched unless stripped here too. `required_message`
// has no dedicated drawer input at all (the `required` mixin in
// view.rowDetail.coffee only renders Always/Conditional/Never radios), so an
// imported value is retained silently unless stripped here (OC-28719).
// Scoped to `signature` only, per product decision - contactdata/identifier/
// clinicaldata rows are out of scope for this ticket.
const UNSUPPORTED_ECONSENT_SIGNATURE_FIELDS = [
  'bind::oc:itemgroup',
  'appearance',
  'required',
  'required_message',
  'readonly',
  'default',
  'calculation',
  'trigger',
]

// Discards `UNSUPPORTED_ECONSENT_SIGNATURE_FIELDS` from any row using
// `bind::oc:external = "signature"`, so the saved/previewed form definition
// only retains settings eConsent signature items actually support.
//
// Matches by prefix, not just exact key, because a translated property
// (e.g. `required_message` on a form with 2+ languages) round-trips through
// `toFlatJSON()` as one key per language - the primary language under the
// bare field name, every other language under `${field}::${langName}` (see
// `flatten_translated_fields` in model.inputParser.coffee). An exact-key
// delete would silently miss every non-primary-language value.
function discardUnsupportedEConsentSignatureSettings(flatSurvey: FlatSurvey): FlatSurvey {
  flatSurvey.survey?.forEach((row) => {
    if (row['bind::oc:external'] === ECONSENT_SIGNATURE_EXTERNAL_VALUE) {
      Object.keys(row).forEach((key) => {
        const isUnsupported = UNSUPPORTED_ECONSENT_SIGNATURE_FIELDS.some(
          (field) => key === field || key.startsWith(`${field}::`),
        )
        if (isUnsupported) {
          delete row[key]
        }
      })
    }
  })
  return flatSurvey
}

export function surveyToValidJson(survey: Survey) {
  // HACK: This is done as a fix for https://github.com/kobotoolbox/kpi/pull/735
  // I'm not entirely sure what this is about but definitely BAD CODE™!
  //
  // skip logic references only preserved after initial call
  // to "survey.toFlatJSON()"
  survey.toFlatJSON()
  // returning the result of the second call to "toFlatJSON()"
  return JSON.stringify(discardUnsupportedEConsentSignatureSettings(survey.toFlatJSON()))
}

/**
 * This function reverses what `nullifyTranslations` did to the form data.
 */
export function unnullifyTranslations(surveyDataJSON: string, surveyInitialParams: AssetContent) {
  // Here we assume that parsed JSON will be `FlatSurvey`. If we ever pass some other string in here, the code would
  // crash. If this ever happens, let's add some checks.
  const surveyData: FlatSurvey = JSON.parse(surveyDataJSON)

  let translatedProps: string[] = []
  if (surveyInitialParams.translated) {
    translatedProps = surveyInitialParams.translated
  }

  // TRANSLATIONS HACK (Part 2/2):
  // set default_language
  const defaultLang = surveyInitialParams.translations_0 || null
  if (!surveyData.settings[0].default_language && defaultLang !== null) {
    surveyData.settings[0].default_language = defaultLang
  }

  if (defaultLang !== null) {
    // replace every "translatedProp" with "translatedProp::defaultLang"
    if (surveyData.choices) {
      surveyData.choices.forEach((choice) => {
        translatedProps.forEach((translatedProp) => {
          if (typeof choice[translatedProp] !== 'undefined') {
            choice[`${translatedProp}::${defaultLang}`] = choice[translatedProp]
            delete choice[translatedProp]
          }
        })
      })
    }
    if (surveyData.survey) {
      surveyData.survey.forEach((surveyRow) => {
        translatedProps.forEach((translatedProp) => {
          if (typeof surveyRow[translatedProp] !== 'undefined') {
            if (
              typeof surveyData.settings[0] !== 'undefined' &&
              typeof surveyData.settings[0].style === 'string' &&
              surveyData.settings[0].style.includes('theme-grid') &&
              surveyRow.type === 'begin_group' &&
              (surveyRow[translatedProp] === null || surveyRow[translatedProp] === '')
            ) {
              delete surveyRow[translatedProp]
            }
            surveyRow[`${translatedProp}::${defaultLang}`] = surveyRow[translatedProp]
            delete surveyRow[translatedProp]
          }
        })
      })
    }
  }

  return JSON.stringify(surveyData)
}

export function mergeFreshTranslations(
  surveyDataJSON: string,
  freshContent: AssetContent,
  protectedLangName: string | null,
): string {
  if (!freshContent?.translations || !freshContent.translated) {
    return surveyDataJSON
  }
  const surveyData: FlatSurvey = JSON.parse(surveyDataJSON)
  const translatedProps = freshContent.translated

  const langNames: Array<string | null> = freshContent.translations.map((name, i) =>
    i === 0 ? (name ?? freshContent.translations_0 ?? null) : name,
  )

  const applyItem = (flat: Record<string, unknown>, fresh: Record<string, unknown>) => {
    translatedProps.forEach((prop) => {
      // Delete every existing key for this prop, EXCEPT the protected language's key.
      Object.keys(flat).forEach((k) => {
        if (k !== prop && !k.startsWith(`${prop}::`)) return
        const keyLangName = k === prop ? null : k.slice(prop.length + 2)
        if (protectedLangName !== null && keyLangName === protectedLangName) return
        delete flat[k]
      })
      const freshValues = fresh[prop] as Array<string | null> | undefined
      if (!freshValues) return
      langNames.forEach((langName, i) => {
        if (protectedLangName !== null && langName === protectedLangName) return
        const key = langName == null ? prop : `${prop}::${langName}`
        flat[key] = freshValues[i] ?? null
      })
    })
  }

  const rowsByKuid = new Map<string, any>()
  const rowsByName = new Map<string, any>()
  freshContent.survey?.forEach((r: any) => {
    if (r.$kuid) rowsByKuid.set(r.$kuid, r)
    const nm = r.name || r.$autoname
    if (nm) rowsByName.set(nm, r)
  })
  const choicesByKuid = new Map<string, any>()
  const choicesByNameList = new Map<string, any>()
  freshContent.choices?.forEach((c: any) => {
    if (c.$kuid) choicesByKuid.set(c.$kuid, c)
    const nm = c.name || c.$autovalue
    if (nm) choicesByNameList.set(`${nm}::${c.list_name}`, c)
  })

  surveyData.survey?.forEach((row: any) => {
    const rowName = row.name || row.$autoname
    const fresh = (row.$kuid && rowsByKuid.get(row.$kuid)) || (rowName && rowsByName.get(rowName))
    if (fresh) applyItem(row, fresh)
  })
  surveyData.choices?.forEach((ch: any) => {
    const chName = ch.name || ch.$autovalue
    const fresh =
      (ch.$kuid && choicesByKuid.get(ch.$kuid)) || (chName && choicesByNameList.get(`${chName}::${ch.list_name}`))
    if (fresh) applyItem(ch, fresh)
  })

  // OC-28719: `applyItem` above re-applies every translated prop's value
  // straight from `freshContent` (the last-saved asset), with no concept of
  // eConsent signature rows. If `required_message` (or another
  // UNSUPPORTED_ECONSENT_SIGNATURE_FIELDS entry) was translated and already
  // present on a signature row in the saved asset, this step would silently
  // undo `surveyToValidJson`'s discard for it. Re-run the same discard here
  // so the invariant holds regardless of what the merge above just did.
  return JSON.stringify(discardUnsupportedEConsentSignatureSettings(surveyData))
}

/**
 * Resolves the form's current primary-language name and translated-property
 * list, preferring a freshly-fetched asset's actual current state over the
 * Form Builder survey model's frozen mount-time snapshot (`_initialParams`,
 * captured once when the model was built and never updated afterward — see
 * EditableForm.tsx's previewForm()/saveForm(), which both need this and
 * previously duplicated the same fallback logic inline in two places).
 */
export function resolveCurrentPrimaryLanguage(
  freshContent: AssetContent | undefined,
  frozenInitialParams: AssetContent | undefined,
): { primaryLangName: string | null; translatedProps: string[] } {
  // `translations[0]` is normally the real primary-language name, but
  // (mirroring mergeFreshTranslations() above) it can be `null` with the name
  // stored in `translations_0` instead.
  const primaryLangName =
    freshContent?.translations?.[0] ?? freshContent?.translations_0 ?? frozenInitialParams?.translations_0 ?? null
  const translatedProps = freshContent?.translated ?? frozenInitialParams?.translated ?? []
  return { primaryLangName, translatedProps }
}

/**
 * Resolves the current primary language (see resolveCurrentPrimaryLanguage())
 * and, if one exists, unnullifies `surveyDataJSON` against it. Bundles the
 * two steps together since every caller needs both and previously duplicated
 * this same pairing inline in two places (Form Designer's previewForm() and
 * saveForm()).
 */
export function applyFreshPrimaryLanguage(
  surveyDataJSON: string,
  freshContent: AssetContent | undefined,
  frozenInitialParams: AssetContent | undefined,
): { surveyDataJSON: string; primaryLangName: string | null } {
  const { primaryLangName, translatedProps } = resolveCurrentPrimaryLanguage(freshContent, frozenInitialParams)
  if (!primaryLangName) {
    return { surveyDataJSON, primaryLangName }
  }
  const updatedSurveyDataJSON = unnullifyTranslations(surveyDataJSON, {
    ...frozenInitialParams,
    translations_0: primaryLangName,
    translated: translatedProps,
  })

  // The label keys were just written with `primaryLangName`, so `default_language` must
  // name it too. The model's value is stale after an in-session rename, and
  // `unnullifyTranslations()` only fills it when empty, so pyxform rejects it (OC-28515).
  const surveyData: FlatSurvey = JSON.parse(updatedSurveyDataJSON)
  if (surveyData.settings?.[0]) {
    surveyData.settings[0].default_language = primaryLangName
  }
  return { surveyDataJSON: JSON.stringify(surveyData), primaryLangName }
}

/**
 * @typedef NullifiedTranslations
 * @property {object} survey - Modified survey.
 * @property {Array<string|null>} translations - Modified translations.
 * @property {Array<string|null>} translations_0 - The original default language name.
 */
interface NullifiedTranslations {
  survey: FlatRow[]
  translations: Array<string | null>
  translations_0?: string | null
}

/**
 * A function that adjust the translations data to the Form Builder code.
 * Requires the sibling `unnullifyTranslations` function to be called before
 * saving the form.
 * @param {Array<string|null>} [translations]
 * @param {Array<string>} translatedProps
 * @param {Array<object>} survey
 * @param {object} baseSurvey
 * @return {NullifiedTranslations}
 */
export function nullifyTranslations(
  translations: Array<string | null>,
  translatedProps: string[],
  survey: FlatRow[],
  baseSurvey: FlatSurvey,
): NullifiedTranslations {
  const data: NullifiedTranslations = {
    survey: clonedeep(survey) as FlatRow[],
    translations: clonedeep(translations),
  }

  if (typeof translations === 'undefined') {
    data.translations = [null]
    return data
  }

  if (data.translations.length > 1 && data.translations.indexOf(null) !== -1) {
    throw new Error(
      "This form includes columns with languages defined but there are also one or more columns that don't include a language name.\nIf translations are used in your form, every user-facing text and media content column must include a language name as part of its column title.\nPlease revise your form definition spreadsheet, upload it, and open it in Form Designer again.",
    )
  }

  /*
  TRANSLATIONS HACK (Part 1/2):
  all the coffee code assumes first language to be null, and we don't want
  to introduce potential code-breaking refactor in old code, so we store
  first language, then replace with null and reverse this just before saving
  NOTE: when importing assets from Library into form, we need to make sure
  the default language is the same (or force baseSurvey default language)
  */
  if (baseSurvey) {
    const formDefaultLang = baseSurvey._initialParams.translations_0 || null
    if (data.translations[0] === formDefaultLang) {
      // case 1: nothing to do - same default language in both
    } else if (data.translations.includes(formDefaultLang)) {
      // case 2: imported asset has form default language but not as first, so
      // we need to reorder things
      const defaultLangIndex = data.translations.indexOf(formDefaultLang)

      // Remove default lang, then place it at the beginning
      data.translations.splice(data.translations.indexOf(formDefaultLang), 1)
      data.translations.unshift(formDefaultLang)

      data.survey.forEach((row: FlatRow) => {
        translatedProps.forEach((translatedProp) => {
          const transletedPropArr = row[translatedProp] as string[]
          if (transletedPropArr) {
            // Pick the default lang translation, then place it at the beginning
            const defaultLangTranslation = transletedPropArr.splice(defaultLangIndex, 1)[0]
            transletedPropArr.unshift(defaultLangTranslation)
          }
        })
      })
    }

    if (!data.translations.includes(formDefaultLang)) {
      // case 3: imported asset doesn't have form default language, so we
      // force it onto the asset as the first language and try setting some
      // meaningful property value
      data.translations.unshift(formDefaultLang)
      data.survey.forEach((row: FlatRow) => {
        translatedProps.forEach((translatedProp) => {
          if (row[translatedProp]) {
            let propVal = null
            if (row.name) {
              propVal = row.name
            } else if (row.$autoname) {
              propVal = row.$autoname
            }
            row[translatedProp].unshift(propVal)
          }
        })
      })
    }
  }

  // no need to nullify null
  if (data.translations[0] !== null) {
    data.translations_0 = data.translations[0]
    data.translations[0] = null
  }

  return data
}

export interface KoboMatrixParserParams {
  content?: string
  source?: string
}

export function koboMatrixParser(params: KoboMatrixParserParams): KoboMatrixParserParams {
  let content: Partial<FlatSurvey> = {}
  const rawData = params.content || params.source

  if (!rawData) return params
  try {
    content = JSON.parse(rawData)
  } catch (e) {
    return params
  }

  if (!content.survey) return params

  let hasMatrix = false
  let surveyLength = content.survey.length

  // add open/close tags for kobomatrix groups
  for (var i = 0; i < surveyLength; i++) {
    if (content.survey[i].type === 'kobomatrix') {
      content.survey[i].type = GroupTypeBeginName.begin_kobomatrix
      content.survey[i].appearance = 'field-list'
      surveyLength++
      content.survey.splice(i + 1, 0, { type: GroupTypeEndName.end_kobomatrix, $kuid: `/${content.survey[i].$kuid}` })
    }
  }

  // add columns as items in the group
  for (i = 0; i < surveyLength; i++) {
    if (content.survey[i].type === 'begin_kobomatrix') {
      var j = i
      hasMatrix = true
      var matrix = localStorage.getItem(`koboMatrix.${content.survey[i].$kuid}`)

      if (matrix != null) {
        const matrixData = JSON.parse(matrix) as KoboMatrixPlainData
        for (var kuid of matrixData.cols) {
          i++
          surveyLength++
          content.survey.splice(i, 0, matrixData[kuid])
        }

        for (var k of recordKeys(matrixData.choices)) {
          content.choices?.push(matrixData.choices[k])
        }
      }
      // TODO: handle corrupt matrix data
      // See: https://github.com/kobotoolbox/kpi/issues/3915
    }
  }

  if (hasMatrix) {
    if (params.content) params.content = JSON.stringify(content)
    if (params.source) params.source = JSON.stringify(content)
  }
  return params
}

/**
 * This function (in theory) is reversing what `writeParameters` does.
 *
 * For given semicolon-separated (or comma-separated) string of parameters, it returns an object.
 */
export function readParameters(str: string) {
  if (typeof str !== 'string') {
    return null
  }

  const params: { [key: string]: string } = {}

  let separator = ' '
  if (str.includes(';')) {
    separator = ';'
  } else if (str.includes(',')) {
    separator = ','
  }
  const otherSeparators = ';, '.replace(separator, '')
  const cleanStr = str.replace(/ *= */g, '=')
  const parts = cleanStr.split(new RegExp(`[${otherSeparators}]*${separator}[${otherSeparators}]*`, 'g'))

  parts.forEach((part) => {
    if (part.includes('=')) {
      const key = part.slice(0, part.indexOf('='))
      const value = part.slice(key.length + 1)
      params[key] = value
    }
  })

  if (recordKeys(params).length < 1) {
    return null
  }
  return params
}

/**
 * This function takes an object of some row parameters, and:
 * 1. filters out `undefined` and `null` (values) ones
 * 2. stringifies objects
 * 3. blacklists "seed" for some reason
 * …and finally returns a single string of semicolon-separated parameters.
 */
export function writeParameters(obj: { [key: string]: string }) {
  const params: string[] = []
  recordKeys(obj).forEach((key) => {
    if (obj[key] !== undefined && obj[key] !== null) {
      let value = obj[key]
      if (typeof value === 'object') {
        value = JSON.stringify(value)
      }
      // Preventing addition of `seed=` which blocks project from deploying
      if (!(key === 'seed' && value === '')) {
        params.push(`${key}=${value}`)
      }
    }
  })
  return params.join(';')
}
