/**
 * OC fork — P1.5 (OC-28702): serialise the WHOLE form for the AI Generator out
 * of the Backbone/xlform survey model (PRD P1.5 AC1–AC6). Mechanical and
 * best-effort: raw stored values, every optional key omitted when empty, every
 * read guarded so a hostile row is dropped rather than stranding Generate.
 *
 * The property set is an ALLOW-LIST. `SENT_COLUMNS` and `EXCLUDED_COLUMNS`
 * partition every column xlform declares; the drift-guard test in
 * logicBuilderContext.tests.ts fails when a new column is declared but not
 * placed. Adding to SENT_COLUMNS is the cue to restate the "About AI Generate"
 * disclosure and PRD §7 Privacy — the payload must never exceed what they say.
 */
import type { FormChoice, FormContext, FormRow, GroupRow, QuestionRow } from '@openclinica/logic-builder'

/** xlform columns the serializer reads (design spec §4.5). */
export const SENT_COLUMNS: readonly string[] = [
  'name',
  'type',
  'label',
  'hint',
  'appearance',
  'bind::oc:briefdescription',
  'bind::oc:description',
  'instance::oc:contactdata',
  'readonly',
  'required',
  'relevant',
  'constraint',
  'constraint_message',
  'default',
  'calculation',
  'trigger',
  'repeat_count',
]

/** Declared xlform columns deliberately NOT sent, with why (design spec §2.1). */
export const EXCLUDED_COLUMNS: readonly string[] = [
  'file', // choices-file selection: attachment plumbing
  'tags', // Kobo tag list
  'bind::oc:itemgroup', // OC Item Group: dataset organisation, not referenceable in expressions
  'bind::oc:external', // external data-source kind: integration wiring
  'instance::oc:identifier', // identifier type: integration wiring
  'select_one_from_file_filename', // attachment plumbing
  '_isRepeat', // consumed to gate repeatCount; the group's type already says repeat
]

// Nesting deeper than this is not a form; stop rather than recurse without bound.
const MAX_DEPTH = 32

/**
 * The scoped item's name — one reader shared by the AI Generator dialog's
 * header and the serializer, so the two can never disagree about which item is
 * scoped. Falls back to the name detail model because a row mid-edit can hold
 * the name only there.
 */
export function readItemName(row: any): string {
  try {
    return String(row.getValue?.('name') || row.get?.('name')?.get?.('value') || '')
  } catch (e) {
    console.warn('Logic Builder: failed to read the item name for AI context', e)
    return ''
  }
}

/**
 * Raw stored value of one column as a string: a RowDetail's `value`, or the
 * attribute itself on plain-attribute rows (kobomatrix columns). Translated
 * columns store an array — the first translation is used. Booleans (the
 * read-only checkbox writes one) stringify to 'true' / 'false'. '' on any throw.
 */
function readDetail(row: any, column: string): string {
  try {
    const attr = row?.get?.(column)
    const raw = attr !== null && typeof attr === 'object' && typeof attr.get === 'function' ? attr.get('value') : attr
    if (raw === undefined || raw === null) {
      return ''
    }
    if (Array.isArray(raw)) {
      return raw.length ? String(raw[0] ?? '') : ''
    }
    return typeof raw === 'object' ? '' : String(raw)
  } catch (e) {
    console.warn('Logic Builder: failed to read a column for AI context', column, e)
    return ''
  }
}

/**
 * The xlform type id ('select_one', 'group', …): the type detail's typeId when
 * present, else the stored value with any trailing list name dropped.
 */
function readType(row: any): string {
  try {
    const typeId = row?.get?.('type')?.get?.('typeId')
    if (typeof typeId === 'string' && typeId) {
      return typeId
    }
  } catch (e) {
    console.warn('Logic Builder: failed to read the type id for AI context', e)
  }
  return readDetail(row, 'type').split(' ')[0]
}

/**
 * Mirrors view.rowDetail.coffee getWidthTokenFromModelValue (the source of
 * truth): the highest `wN` token in the appearance value wins; leading-zero
 * tokens are not matched. Reimplemented rather than importing the CoffeeScript
 * view module into this bridge.
 */
export function parseWidthToken(appearance: string): string {
  const re = /\bw([1-9]\d*)\b/g
  let best = ''
  let bestN = -1
  let m: RegExpExecArray | null = re.exec(appearance)
  while (m !== null) {
    const n = Number.parseInt(m[1], 10)
    if (n > bestN) {
      bestN = n
      best = m[0]
    }
    m = re.exec(appearance)
  }
  return best
}

/** `{key: value}` when value is non-empty, else `{}` — the omit-when-empty rule. */
function opt<K extends string>(key: K, value: string): Partial<Record<K, string>> {
  return value ? ({ [key]: value } as Record<K, string>) : {}
}

/**
 * Choice list of a select row, as value/label(/image) triples. In xlform an
 * option model's `name` is the stored VALUE, its `label` the display text, and
 * `image` the media filename (P1.5 AC3: omitted when none).
 */
function readRowChoices(row: any): FormChoice[] | undefined {
  try {
    if (typeof row._isSelectQuestion !== 'function' || !row._isSelectQuestion()) {
      return undefined
    }
    const models = row.getList?.()?.options?.models
    if (!Array.isArray(models) || models.length === 0) {
      return undefined
    }
    return models.map((option: any) => ({
      value: String(option?.get?.('name') ?? ''),
      label: String(option?.get?.('label') ?? ''),
      ...opt('image', String(option?.get?.('image') ?? '')),
    }))
  } catch (e) {
    console.warn('Logic Builder: failed to read choices for AI context', e)
    return undefined
  }
}

/**
 * Only xlform's Group class (plain, repeat, and kobomatrix groups) is a group.
 * `forEachRow` is deliberately NOT the test: rank and score QUESTIONS gain a
 * forEachRow via ScoreRankMixin (model.row.coffee) to walk their sub-rows, and
 * would otherwise serialise as empty groups, losing their type and logic.
 */
function isGroupRow(row: any): boolean {
  try {
    if (typeof row?.isGroup === 'function') {
      return Boolean(row.isGroup())
    }
    return row?.constructor?.kls === 'Group'
  } catch (e) {
    console.warn('Logic Builder: failed to classify a row for AI context', e)
    return false
  }
}

function isRepeatRow(row: any): boolean {
  try {
    return typeof row?._isRepeat === 'function' && Boolean(row._isRepeat())
  } catch (e) {
    console.warn('Logic Builder: failed to read the repeat flag for AI context', e)
    return false
  }
}

function buildQuestionRow(row: any, name: string, isTarget: boolean): QuestionRow {
  const appearance = readDetail(row, 'appearance')
  const choices = readRowChoices(row)
  return {
    kind: 'question',
    name,
    type: readType(row),
    ...opt('label', readDetail(row, 'label')),
    ...opt('hint', readDetail(row, 'hint')),
    ...opt('shortDisplayName', readDetail(row, 'bind::oc:briefdescription')),
    ...opt('description', readDetail(row, 'bind::oc:description')),
    ...opt('contactDataType', readDetail(row, 'instance::oc:contactdata')),
    ...opt('appearance', appearance),
    ...opt('width', parseWidthToken(appearance)),
    ...opt('readOnly', readDetail(row, 'readonly')),
    ...(choices ? { choices } : {}),
    ...(isTarget ? { isTarget: true as const } : {}),
    logic: {
      ...opt('required', readDetail(row, 'required')),
      ...opt('relevant', readDetail(row, 'relevant')),
      ...opt('constraint', readDetail(row, 'constraint')),
      ...opt('constraintMessage', readDetail(row, 'constraint_message')),
      ...opt('default', readDetail(row, 'default')),
      ...opt('calculation', readDetail(row, 'calculation')),
      ...opt('trigger', readDetail(row, 'trigger')),
    },
  }
}

function buildGroupRow(row: any, name: string, isTarget: boolean, targetRow: any, depth: number): GroupRow {
  const appearance = readDetail(row, 'appearance')
  // A group's stored `type` only becomes 'repeat' after save AND reload; in the
  // live model the repeat switch is the `_isRepeat` detail, which is also what
  // xlform's own export keys begin_repeat/begin_group on. Derive the effective
  // type from it so an unsaved or not-yet-reloaded repeat group is not sent as
  // a plain group (PR review, 2026-09-07). Other group types (kobomatrix) pass through.
  const storedType = readType(row)
  const type = storedType === 'group' || storedType === 'repeat' ? (isRepeatRow(row) ? 'repeat' : 'group') : storedType
  return {
    kind: 'group',
    name,
    type,
    ...opt('label', readDetail(row, 'label')),
    ...opt('hint', readDetail(row, 'hint')),
    ...opt('shortDisplayName', readDetail(row, 'bind::oc:briefdescription')),
    ...opt('description', readDetail(row, 'bind::oc:description')),
    ...opt('contactDataType', readDetail(row, 'instance::oc:contactdata')),
    ...opt('appearance', appearance),
    ...opt('width', parseWidthToken(appearance)),
    ...(isTarget ? { isTarget: true as const } : {}),
    logic: {
      ...opt('relevant', readDetail(row, 'relevant')),
      ...(isRepeatRow(row) ? opt('repeatCount', readDetail(row, 'repeat_count')) : {}),
    },
    rows: walk(row.rows?.models, targetRow, depth + 1),
  }
}

function walk(models: unknown, targetRow: any, depth: number): FormRow[] {
  if (!Array.isArray(models) || depth > MAX_DEPTH) {
    return []
  }
  const out: FormRow[] = []
  const pushRow = (row: any): void => {
    try {
      if (typeof row?.isError === 'function' && row.isError()) {
        return
      }
      const isTarget = row === targetRow
      const name = readItemName(row)
      if (!name && !isTarget) {
        return // a nameless row cannot be referenced in an expression
      }
      out.push(
        isGroupRow(row) ? buildGroupRow(row, name, isTarget, targetRow, depth) : buildQuestionRow(row, name, isTarget),
      )
    } catch (e) {
      console.warn('Logic Builder: dropping a row the AI context could not serialise', e)
    }
  }
  for (const row of models) {
    pushRow(row)
  }
  return out
}

/**
 * The whole form for the AI Generator (PRD P1.5): every item and group in form
 * order, nested under its group, with `targetRow` marked `isTarget` by object
 * identity. Never throws — an unreachable survey yields `{rows: []}`.
 */
export function buildFormContext(targetRow: any): FormContext {
  try {
    const models = targetRow?.getSurvey?.()?.rows?.models
    if (!Array.isArray(models)) {
      return { rows: [] }
    }
    return { rows: walk(models, targetRow, 0) }
  } catch (e) {
    console.warn('Logic Builder: failed to build the form context; using an empty form', e)
    return { rows: [] }
  }
}
