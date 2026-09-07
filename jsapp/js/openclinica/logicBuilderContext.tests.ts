import chai from 'chai'
import configs from '../../xlform/src/model.configs'
import { EXCLUDED_COLUMNS, SENT_COLUMNS, buildFormContext, parseWidthToken, readItemName } from './logicBuilderContext'

// Minimal Backbone/xlform fakes. `columns` are RowDetail values (row.get(col).get('value'));
// getValue mirrors them for the name reader. A select row answers _isSelectQuestion() and hands
// out its choice list via getList(), whose options.models are Backbone models where get('name')
// is the choice VALUE, get('label') its label, get('image') its image filename. A row with
// `children` is a group: it answers isGroup() (how the serializer recognises groups) and, like xlform's
// Group, also has forEachRow and rows.models. A row with `walker` is a rank/score-style QUESTION: it has a
// forEachRow function but is not a group.
type Stored = string | string[] | boolean
interface FakeRowSpec {
  columns?: Record<string, Stored>
  typeId?: string
  select?: Array<{ name: string; label: string; image?: string }>
  children?: any[]
  walker?: boolean
  repeat?: boolean
  error?: boolean
}

function fakeRow(spec: FakeRowSpec): any {
  const columns = spec.columns || {}
  const row: any = {
    get: (col: string) => {
      if (col === 'type' && spec.typeId !== undefined) {
        return { get: (k: string) => (k === 'typeId' ? spec.typeId : k === 'value' ? columns.type : undefined) }
      }
      return col in columns ? { get: (k: string) => (k === 'value' ? columns[col] : undefined) } : undefined
    },
    getValue: (k: string) => {
      const v = columns[k]
      return Array.isArray(v) ? v[0] : (v ?? '')
    },
    _isSelectQuestion: () => Boolean(spec.select),
    getList: () =>
      spec.select
        ? {
            options: {
              models: spec.select.map((o) => ({ get: (k: string) => (o as Record<string, string | undefined>)[k] })),
            },
          }
        : undefined,
    isError: () => Boolean(spec.error),
  }
  if (spec.children) {
    row.isGroup = () => true
    row.forEachRow = () => {}
    row.rows = { models: spec.children }
    row._isRepeat = () => Boolean(spec.repeat)
  }
  if (spec.walker) {
    row.forEachRow = () => {}
  }
  return row
}

/** Wire getSurvey() on every row (recursively) to a survey holding `rows` at its top level. */
function surveyOf(rows: any[]): void {
  const survey = { rows: { models: rows } }
  const attach = (r: any) => {
    r.getSurvey = () => survey
    for (const child of r.rows?.models || []) attach(child)
  }
  rows.forEach(attach)
}

const q = (name: string, extra: FakeRowSpec = {}) =>
  fakeRow({ ...extra, columns: { name, type: 'text', ...(extra.columns || {}) } })

describe('buildFormContext (P1.5)', () => {
  let warnSpy: jest.SpyInstance
  beforeEach(() => {
    warnSpy = jest.spyOn(console, 'warn').mockImplementation(() => {})
  })
  afterEach(() => {
    warnSpy.mockRestore()
  })

  it('serialises every row in form order, nested under its group, target marked (AC1, AC5, AC6)', () => {
    const weight = q('WEIGHT', { columns: { type: 'decimal', label: 'Weight (kg)' } })
    const inner = fakeRow({ columns: { name: 'INNER', type: 'group', label: 'Inner' }, children: [weight] })
    const vitals = fakeRow({ columns: { name: 'VITALS', type: 'group', label: 'Vitals' }, children: [inner] })
    const bmi = q('BMI', { columns: { type: 'decimal', label: 'BMI', calculation: '${WEIGHT} div 2' } })
    surveyOf([vitals, bmi])
    chai.expect(buildFormContext(weight)).to.deep.equal({
      rows: [
        {
          kind: 'group',
          name: 'VITALS',
          type: 'group',
          label: 'Vitals',
          logic: {},
          rows: [
            {
              kind: 'group',
              name: 'INNER',
              type: 'group',
              label: 'Inner',
              logic: {},
              rows: [
                { kind: 'question', name: 'WEIGHT', type: 'decimal', label: 'Weight (kg)', isTarget: true, logic: {} },
              ],
            },
          ],
        },
        { kind: 'question', name: 'BMI', type: 'decimal', label: 'BMI', logic: { calculation: '${WEIGHT} div 2' } },
      ],
    })
    chai.expect(warnSpy.mock.calls.length).to.equal(0)
  })

  it('marks the target by identity even when another row shares its name (AC6)', () => {
    const a = q('DUP')
    const b = q('DUP')
    surveyOf([a, b])
    chai.expect(buildFormContext(b).rows.map((r) => r.isTarget)).to.deep.equal([undefined, true])
  })

  it('omits every empty property and logic key (AC2–AC4)', () => {
    const row = q('A', {
      columns: { label: '', hint: '', appearance: '', readonly: '', required: '', calculation: '' },
    })
    surveyOf([row])
    chai.expect(buildFormContext(row).rows[0]).to.deep.equal({
      kind: 'question',
      name: 'A',
      type: 'text',
      isTarget: true,
      logic: {},
    })
  })

  it('reads every AC2 property and all question logic columns, stringifying a boolean read-only', () => {
    const row = q('EMAIL', {
      typeId: 'text',
      columns: {
        type: 'text',
        label: 'Email',
        hint: 'work address',
        'bind::oc:briefdescription': 'Email',
        'bind::oc:description': 'Primary contact email',
        'instance::oc:contactdata': 'email',
        appearance: 'w2 multiline',
        readonly: true,
        required: 'yes',
        relevant: "${HAS_EMAIL} = 'yes'",
        constraint: "regex(., '@')",
        constraint_message: 'Enter a valid email',
        default: 'none@example.org',
        calculation: 'lower-case(${RAW})',
        trigger: '${RAW}',
      },
    })
    surveyOf([row])
    chai.expect(buildFormContext(row).rows[0]).to.deep.equal({
      kind: 'question',
      name: 'EMAIL',
      type: 'text',
      label: 'Email',
      hint: 'work address',
      shortDisplayName: 'Email',
      description: 'Primary contact email',
      contactDataType: 'email',
      appearance: 'w2 multiline',
      width: 'w2',
      readOnly: 'true',
      isTarget: true,
      logic: {
        required: 'yes',
        relevant: "${HAS_EMAIL} = 'yes'",
        constraint: "regex(., '@')",
        constraintMessage: 'Enter a valid email',
        default: 'none@example.org',
        calculation: 'lower-case(${RAW})',
        trigger: '${RAW}',
      },
    })
  })

  it("sends read-only 'false' as a value, not an omission", () => {
    const row = q('A', { columns: { readonly: false } })
    surveyOf([row])
    chai.expect((buildFormContext(row).rows[0] as any).readOnly).to.equal('false')
  })

  it('uses the type id, dropping a trailing list name', () => {
    const withId = q('A', { typeId: 'select_one', columns: { type: 'select_multiple yesno' } })
    const noId = q('B', { columns: { type: 'select_multiple colors' } })
    surveyOf([withId, noId])
    chai.expect(buildFormContext(withId).rows.map((r) => r.type)).to.deep.equal(['select_one', 'select_multiple'])
  })

  it('takes the first translation of translated columns', () => {
    const row = q('A', {
      columns: { label: ['Peso', 'Weight'], hint: ['en kg', 'in kg'], constraint_message: ['Positivo', 'Positive'] },
    })
    surveyOf([row])
    const r = buildFormContext(row).rows[0] as any
    chai.expect([r.label, r.hint, r.logic.constraintMessage]).to.deep.equal(['Peso', 'en kg', 'Positivo'])
  })

  it('includes choices with an image only when one is defined (AC3)', () => {
    const row = q('P', {
      columns: { type: 'select_one' },
      select: [
        { name: 'yes', label: 'Yes' },
        { name: 'no', label: 'No', image: 'no.png' },
        { name: 'na', label: 'N/A', image: '' },
      ],
    })
    surveyOf([row])
    chai.expect((buildFormContext(row).rows[0] as any).choices).to.deep.equal([
      { value: 'yes', label: 'Yes' },
      { value: 'no', label: 'No', image: 'no.png' },
      { value: 'na', label: 'N/A' },
    ])
  })

  it('sends repeatCount on repeat groups only (AC4)', () => {
    const repeat = fakeRow({
      columns: { name: 'MEDS', type: 'repeat', repeat_count: '${N}', relevant: '${X}' },
      children: [],
      repeat: true,
    })
    const plain = fakeRow({ columns: { name: 'VITALS', type: 'group', repeat_count: '${N}' }, children: [] })
    const target = q('T')
    surveyOf([repeat, plain, target])
    const rows = buildFormContext(target).rows
    chai.expect(rows[0].logic).to.deep.equal({ relevant: '${X}', repeatCount: '${N}' })
    chai.expect(rows[1].logic).to.deep.equal({})
  })

  it("derives a group's type from its live repeat switch, not the stored type", () => {
    // The stored `type` flips to 'repeat' only after save + reload; the UI's
    // switch is the `_isRepeat` detail, which xlform's export also relies on.
    const unsavedRepeat = fakeRow({
      columns: { name: 'MEDS', type: 'group', repeat_count: '${N}' },
      children: [],
      repeat: true,
    })
    const untickedRepeat = fakeRow({ columns: { name: 'OLD', type: 'repeat', repeat_count: '${N}' }, children: [] })
    const matrix = fakeRow({ columns: { name: 'GRID', type: 'kobomatrix' }, children: [] })
    const target = q('T')
    surveyOf([unsavedRepeat, untickedRepeat, matrix, target])
    chai.expect(buildFormContext(target).rows.map((r) => [r.name, r.type, r.logic])).to.deep.equal([
      ['MEDS', 'repeat', { repeatCount: '${N}' }],
      ['OLD', 'group', {}],
      ['GRID', 'kobomatrix', {}],
      ['T', 'text', {}],
    ])
  })

  it('serialises a kobomatrix and its column rows as a group with children', () => {
    const col = q('SCORE', { columns: { type: 'integer' } })
    const matrix = fakeRow({ columns: { name: 'GRID', type: 'kobomatrix', label: 'Grid' }, children: [col] })
    surveyOf([matrix])
    chai.expect(buildFormContext(col).rows[0]).to.deep.equal({
      kind: 'group',
      name: 'GRID',
      type: 'kobomatrix',
      label: 'Grid',
      logic: {},
      rows: [{ kind: 'question', name: 'SCORE', type: 'integer', isTarget: true, logic: {} }],
    })
  })

  it('sends group hint, short display name, description, and contact data type when a group carries them', () => {
    const group = fakeRow({
      columns: {
        name: 'VITALS',
        type: 'group',
        label: 'Vitals',
        hint: 'Measure seated',
        'bind::oc:briefdescription': 'Vitals',
        'bind::oc:description': 'Vital signs block',
        'instance::oc:contactdata': 'email',
        readonly: true,
      },
      children: [],
    })
    const target = q('T')
    surveyOf([group, target])
    chai.expect(buildFormContext(target).rows[0]).to.deep.equal({
      kind: 'group',
      name: 'VITALS',
      type: 'group',
      label: 'Vitals',
      hint: 'Measure seated',
      shortDisplayName: 'Vitals',
      description: 'Vital signs block',
      contactDataType: 'email',
      logic: {},
      rows: [],
    })
  })

  it('reads a plain (non-detail) attribute directly and ignores a bare object', () => {
    const plain = q('P')
    plain.get = (col: string) =>
      col === 'name'
        ? 'P'
        : col === 'type'
          ? 'text'
          : col === 'hint'
            ? 'plain hint'
            : col === 'label'
              ? { odd: true }
              : undefined
    surveyOf([plain])
    chai
      .expect(buildFormContext(plain).rows[0])
      .to.deep.equal({ kind: 'question', name: 'P', type: 'text', hint: 'plain hint', isTarget: true, logic: {} })
  })

  it('serialises a question that merely has a forEachRow (rank/score) as a question, not a group', () => {
    // ScoreRankMixin copies forEachRow onto rank and score QUESTION rows; only
    // xlform's Group class (isGroup()) is a group.
    const score = q('SATISFACTION', {
      typeId: 'score',
      columns: { type: 'score', label: 'Rate each', required: 'yes' },
      walker: true,
    })
    surveyOf([score])
    chai.expect(buildFormContext(score).rows).to.deep.equal([
      {
        kind: 'question',
        name: 'SATISFACTION',
        type: 'score',
        label: 'Rate each',
        isTarget: true,
        logic: { required: 'yes' },
      },
    ])
  })

  it('skips nameless and error rows, except a nameless target', () => {
    const nameless = fakeRow({ columns: { type: 'text' } })
    const err = q('E', { error: true })
    const target = fakeRow({ columns: { type: 'text' } })
    surveyOf([nameless, err, target])
    chai
      .expect(buildFormContext(target).rows)
      .to.deep.equal([{ kind: 'question', name: '', type: 'text', isTarget: true, logic: {} }])
  })

  it('drops a throwing row, keeps its siblings, and warns', () => {
    const hostile: any = {
      get: () => {
        throw new Error('x')
      },
      getValue: () => {
        throw new Error('x')
      },
    }
    const ok = q('OK')
    surveyOf([hostile, ok])
    chai.expect(buildFormContext(ok).rows.map((r) => r.name)).to.deep.equal(['OK'])
    chai.expect(warnSpy.mock.calls.length).to.be.above(0)
  })

  it('yields an empty form when the survey is unreachable', () => {
    chai.expect(buildFormContext(fakeRow({}))).to.deep.equal({ rows: [] })
    chai.expect(buildFormContext(undefined)).to.deep.equal({ rows: [] })
  })
})

describe('parseWidthToken (P1.5 AC2)', () => {
  it('mirrors the host width picker: highest wN token wins, leading zeros ignored', () => {
    chai.expect(parseWidthToken('w2 w4')).to.equal('w4')
    chai.expect(parseWidthToken('field-list')).to.equal('')
    chai.expect(parseWidthToken('w14')).to.equal('w14')
    chai.expect(parseWidthToken('w01')).to.equal('')
    chai.expect(parseWidthToken('')).to.equal('')
  })
})

describe('readItemName (P1.2)', () => {
  let warnSpy: jest.SpyInstance
  beforeEach(() => {
    warnSpy = jest.spyOn(console, 'warn').mockImplementation(() => {})
  })
  afterEach(() => {
    warnSpy.mockRestore()
  })

  it('reads the name off getValue', () => {
    chai.expect(readItemName(q('BMI'))).to.equal('BMI')
    chai.expect(warnSpy.mock.calls.length).to.equal(0)
  })

  it('falls back to the name detail model when getValue yields nothing', () => {
    const row = fakeRow({ columns: { name: 'PREGNANT' } })
    row.getValue = () => ''
    chai.expect(readItemName(row)).to.equal('PREGNANT')
  })

  it("is '' when neither path yields a name", () => {
    chai.expect(readItemName(fakeRow({}))).to.equal('')
    chai.expect(readItemName({})).to.equal('')
  })

  it("is '' and warns when the getValue read throws", () => {
    const hostile = {
      getValue: () => {
        throw new Error('x')
      },
      get: () => ({ get: () => 'NOT_REACHED' }),
    }
    chai.expect(readItemName(hostile)).to.equal('')
    chai.expect(warnSpy.mock.calls.length).to.be.above(0)
  })
})

describe('allow-list drift guard (P1.5)', () => {
  // The column universe is what xlform DECLARES: the export column order plus
  // the default details of a new question and a new group. A column that exists
  // only as a detail-view mixin is outside it until someone declares it.
  it('partitions every column xlform declares into SENT_COLUMNS or EXCLUDED_COLUMNS', () => {
    const declared = new Set<string>([
      ...configs.columns,
      ...Object.keys(configs.newRowDetails),
      ...Object.keys(configs.newGroupDetails),
    ])
    const sent = new Set(SENT_COLUMNS)
    const excluded = new Set(EXCLUDED_COLUMNS)
    chai
      .expect(
        [...sent].filter((c) => excluded.has(c)),
        'a column cannot be both sent and excluded',
      )
      .to.deep.equal([])
    chai
      .expect(
        [...declared].filter((c) => !sent.has(c) && !excluded.has(c)),
        'xlform declares a column the AI context does not place: add it to SENT_COLUMNS (and restate the ' +
          'About AI Generate disclosure + PRD §7 Privacy) or to EXCLUDED_COLUMNS',
      )
      .to.deep.equal([])
    chai
      .expect(
        [...sent, ...excluded].filter((c) => !declared.has(c)),
        'column no longer declared by xlform',
      )
      .to.deep.equal([])
    chai.expect(declared.size).to.equal(24) // bump deliberately when xlform changes
  })
})
