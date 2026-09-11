import { ECONSENT_SIGNATURE_EXTERNAL_VALUE } from '#/components/formBuilder/econsentSignature'
import {
  applyFreshPrimaryLanguage,
  mergeFreshTranslations,
  nullifyTranslations,
  readParameters,
  resolveCurrentPrimaryLanguage,
  surveyToValidJson,
  unnullifyTranslations,
  writeParameters,
} from '#/components/formBuilder/formBuilderUtils'

describe('translations hack', () => {
  describe('nullifyTranslations', () => {
    it('should return array with null for no translations', () => {
      const test = {
        survey: [
          {
            label: ['Hello'],
          },
        ],
      }
      const target = {
        survey: [{ label: ['Hello'] }],
        translations: [null],
      }
      expect(nullifyTranslations(test.translations, test.translated, test.survey, test.baseSurvey)).to.deep.equal(
        target,
      )
    })

    it('should throw if there are unnamed translations', () => {
      const test = {
        survey: [
          {
            label: ['Hello'],
          },
        ],
        translations: [null, 'English (en)'],
      }
      expect(() => {
        nullifyTranslations(test.translations, test.translated, test.survey, test.baseSurvey)
      }).to.throw()
    })

    it('should not reorder anything if survey has same default language as base survey', () => {
      const test = {
        baseSurvey: { _initialParams: { translations_0: 'English (en)' } },
        survey: [
          {
            label: ['Hello', 'Cześć'],
          },
        ],
        translations: ['English (en)', 'Polski (pl)'],
        translated: ['label'],
      }
      const target = {
        survey: [
          {
            label: ['Hello', 'Cześć'],
          },
        ],
        translations: [null, 'Polski (pl)'],
        translations_0: 'English (en)',
      }
      expect(nullifyTranslations(test.translations, test.translated, test.survey, test.baseSurvey)).to.deep.equal(
        target,
      )
    })

    it('should reorder translated props if survey has same default language as base survey but in different order (as last)', () => {
      const test = {
        baseSurvey: { _initialParams: { translations_0: 'English (en)' } },
        survey: [
          {
            label: ['Allo', 'Cześć', 'Hello'],
          },
        ],
        translations: ['Francais (fr)', 'Polski (pl)', 'English (en)'],
        translated: ['label'],
      }
      const target = {
        survey: [
          {
            label: ['Hello', 'Allo', 'Cześć'],
          },
        ],
        translations: [null, 'Francais (fr)', 'Polski (pl)'],
        translations_0: 'English (en)',
      }
      expect(nullifyTranslations(test.translations, test.translated, test.survey, test.baseSurvey)).to.deep.equal(
        target,
      )
    })

    it('should reorder translated props if survey has same default language as base survey but in different order (as not last)', () => {
      const test = {
        baseSurvey: { _initialParams: { translations_0: 'English (en)' } },
        survey: [
          {
            label: ['Allo', 'Cześć', 'Hello', 'Hallo'],
          },
        ],
        translations: ['Francais (fr)', 'Polski (pl)', 'English (en)', 'Deutsch (de)'],
        translated: ['label'],
      }
      const target = {
        survey: [
          {
            label: ['Hello', 'Allo', 'Cześć', 'Hallo'],
          },
        ],
        translations: [null, 'Francais (fr)', 'Polski (pl)', 'Deutsch (de)'],
        translations_0: 'English (en)',
      }
      expect(nullifyTranslations(test.translations, test.translated, test.survey, test.baseSurvey)).to.deep.equal(
        target,
      )
    })

    it("should add base survey's default language if survey doesn't have it", () => {
      const test = {
        baseSurvey: { _initialParams: { translations_0: 'English (en)' } },
        survey: [
          {
            label: ['Allo', 'Cześć'],
            name: 'welcome_message',
          },
        ],
        translations: ['Francais (fr)', 'Polski (pl)'],
        translated: ['label'],
      }
      const target = {
        survey: [
          {
            label: ['welcome_message', 'Allo', 'Cześć'],
            name: 'welcome_message',
          },
        ],
        translations: [null, 'Francais (fr)', 'Polski (pl)'],
        translations_0: 'English (en)',
      }
      expect(nullifyTranslations(test.translations, test.translated, test.survey, test.baseSurvey)).to.deep.equal(
        target,
      )
    })

    it('should add null language if base survey has no translations but survey does', () => {
      const test = {
        baseSurvey: { _initialParams: {} },
        survey: [
          {
            label: ['Allo', 'Cześć'],
            name: 'welcome_message',
          },
        ],
        translations: ['Francais (fr)', 'Polski (pl)'],
        translated: ['label'],
      }
      const target = {
        survey: [
          {
            label: ['welcome_message', 'Allo', 'Cześć'],
            name: 'welcome_message',
          },
        ],
        translations: [null, 'Francais (fr)', 'Polski (pl)'],
      }
      expect(nullifyTranslations(test.translations, test.translated, test.survey, test.baseSurvey)).to.deep.equal(
        target,
      )
    })

    it('should do nothing if neither base survey nor survey have translations', () => {
      const test = {
        baseSurvey: { _initialParams: {} },
        survey: [
          {
            label: ['Hello'],
          },
        ],
        translations: [null],
        translated: [],
      }
      const target = {
        survey: [
          {
            label: ['Hello'],
          },
        ],
        translations: [null],
      }
      expect(nullifyTranslations(test.translations, test.translated, test.survey, test.baseSurvey)).to.deep.equal(
        target,
      )
    })
  })

  describe('unnullifyTranslations', () => {
    it("should set default language if it's not set already", () => {
      const test = {
        surveyDataJSON: JSON.stringify({
          survey: [
            {
              label: 'Cheese?',
            },
          ],
          settings: [{}],
        }),
        assetContent: {
          translated: ['label'],
          translations_0: 'English (en)',
        },
      }
      const target = JSON.stringify({
        survey: [
          {
            'label::English (en)': 'Cheese?',
          },
        ],
        settings: [
          {
            default_language: 'English (en)',
          },
        ],
      })
      expect(unnullifyTranslations(test.surveyDataJSON, test.assetContent)).to.deep.equal(target)
    })

    it('should replace nullified props with translated ones', () => {
      const test = {
        surveyDataJSON: JSON.stringify({
          survey: [
            {
              label: 'Cheese?',
              'label::Polski (pl)': 'Ser?',
            },
          ],
          choices: [
            {
              label: 'Yes',
            },
            {
              label: 'No',
              'label::Polski (pl)': 'Nie',
            },
          ],
          settings: [
            {
              default_language: 'English (en)',
            },
          ],
        }),
        assetContent: {
          translated: ['label'],
          translations_0: 'English (en)',
        },
      }
      const target = JSON.stringify({
        survey: [
          {
            'label::Polski (pl)': 'Ser?',
            'label::English (en)': 'Cheese?',
          },
        ],
        choices: [
          {
            'label::English (en)': 'Yes',
          },
          {
            'label::Polski (pl)': 'Nie',
            'label::English (en)': 'No',
          },
        ],
        settings: [
          {
            default_language: 'English (en)',
          },
        ],
      })
      expect(unnullifyTranslations(test.surveyDataJSON, test.assetContent)).to.deep.equal(target)
    })
  })
})

describe('readParameters', () => {
  const validReadPairs = [
    {
      str: 'foo=',
      obj: { foo: '' },
      note: 'empty parameter',
    },
    {
      str: 'foo=;bar=1;fum=;baz=',
      obj: { foo: '', bar: '1', fum: '', baz: '' },
      note: 'empty parameters',
    },
    {
      str: 'foo=bar',
      obj: { foo: 'bar' },
      note: 'single parameter',
    },
    {
      str: 'foo=1 bar=10 fum=1',
      obj: { foo: '1', bar: '10', fum: '1' },
      note: 'space-separated parameters',
    },
    {
      str: 'foo=1,bar=10,fum=1',
      obj: { foo: '1', bar: '10', fum: '1' },
      note: 'comma-separated parameters',
    },
    {
      str: 'foo=1;bar=10;fum=1',
      obj: { foo: '1', bar: '10', fum: '1' },
      note: 'semicolon-separated parameters',
    },
    {
      str: 'foo  = 1    bar  =  10    fum  =  1',
      obj: { foo: '1', bar: '10', fum: '1' },
      note: 'space-dirty space-separated parameters',
    },
    {
      str: 'foo = 1 , bar = 10 , fum = 1',
      obj: { foo: '1', bar: '10', fum: '1' },
      note: 'space-dirty comma-separated parameters',
    },
    {
      str: 'foo = 1  ; bar = 10 ; fum = 1',
      obj: { foo: '1', bar: '10', fum: '1' },
      note: 'space-dirty semicolon-separated parameters',
    },
    {
      str: 'foo=1 bar=10,fum=1;baz=0',
      obj: { foo: '1 bar=10,fum=1', baz: '0' },
      note: 'parameters with mixed separators',
    },
    {
      str: 'foo    =2',
      obj: { foo: '2' },
      note: 'left-space-dirty single parameter',
    },
    {
      str: 'foo     =   2',
      obj: { foo: '2' },
      note: 'both-space-dirty single parameter',
    },
    {
      str: 'foo=      2',
      obj: { foo: '2' },
      note: 'right-space-dirty single parameter',
    },
    {
      str: 'foo = 2, 4  ; bar =  4 , , 4 a   ,  ; fum=baz',
      obj: { foo: '2, 4', bar: '4 , , 4 a', fum: 'baz' },
      note: 'dirty parameters with mixed separators',
    },
  ]

  validReadPairs.forEach((pair) => {
    it(`should return valid object from ${pair.note}`, () => {
      chai.expect(readParameters(pair.str)).to.deep.equal(pair.obj)
    })
  })

  it('should read parameters values as strings', () => {
    const obj = readParameters('foo=1;bar=false;fum=0.5;baz=[1,2,3]')
    chai.expect(typeof obj.foo).to.equal('string')
    chai.expect(typeof obj.bar).to.equal('string')
    chai.expect(typeof obj.fum).to.equal('string')
    chai.expect(typeof obj.baz).to.equal('string')
  })

  it('should return null for invalid parameter string', () => {
    chai.expect(readParameters('abc:1')).to.equal(null)
    chai.expect(readParameters('1')).to.equal(null)
    chai.expect(readParameters('')).to.equal(null)
    chai.expect(readParameters(0)).to.equal(null)
    chai.expect(readParameters(false)).to.equal(null)
    chai.expect(readParameters(null)).to.equal(null)
    chai.expect(readParameters(undefined)).to.equal(null)
    chai.expect(readParameters({})).to.equal(null)
    chai.expect(readParameters([])).to.equal(null)
  })
})

describe('writeParameters', () => {
  const validWritePairs = [
    {
      str: 'foo=1;bar=10;fum=1',
      obj: { foo: '1', bar: '10', fum: '1' },
      note: 'valid string from object with multiple parameters',
    },
    {
      str: 'foo=2',
      obj: { foo: '2' },
      note: 'valid string from object with single parameter',
    },
    {
      str: 'bar=0;baz=false',
      obj: { foo: null, bar: 0, fum: undefined, baz: false },
      note: 'valid string omitting empty values from object with multiple parameters',
    },
    {
      str: 'foo={"bar":"a","fum":{"baz":"b"}}',
      obj: { foo: { bar: 'a', fum: { baz: 'b' } } },
      note: 'valid string from nested object',
    },
  ]

  validWritePairs.forEach((pair) => {
    it(`should return ${pair.note}`, () => {
      chai.expect(writeParameters(pair.obj)).to.equal(pair.str)
    })
  })
})

describe('mergeFreshTranslations', () => {
  // Returns the parsed survey after merging.
  const merge = (surveyData, freshContent, protectedLangName) =>
    JSON.parse(mergeFreshTranslations(JSON.stringify(surveyData), freshContent, protectedLangName))

  it("1. updates a $kuid-matched row's non-protected-language translation from fresh content", () => {
    const result = merge(
      {
        survey: [
          { $kuid: 'q1', name: 'q1', type: 'text', 'label::English (en)': 'Hello', 'label::Polski (pl)': 'STALE' },
        ],
      },
      {
        translated: ['label'],
        translations: ['English (en)', 'Polski (pl)'],
        survey: [{ $kuid: 'q1', name: 'q1', label: ['Hello', 'Cześć'] }],
      },
      'English (en)',
    )
    expect(result.survey[0]['label::English (en)']).to.equal('Hello') // protected, untouched
    expect(result.survey[0]['label::Polski (pl)']).to.equal('Cześć') // updated
  })

  it('2. falls back to name matching when the row has no $kuid', () => {
    const result = merge(
      { survey: [{ name: 'q1', type: 'text', 'label::English (en)': 'Hello', 'label::Polski (pl)': 'STALE' }] },
      {
        translated: ['label'],
        translations: ['English (en)', 'Polski (pl)'],
        survey: [{ $kuid: 'q1', name: 'q1', label: ['Hello', 'Cześć'] }],
      },
      'English (en)',
    )
    expect(result.survey[0]['label::Polski (pl)']).to.equal('Cześć')
  })

  it('3. never touches the protected language key even when fresh content differs there', () => {
    const result = merge(
      { survey: [{ name: 'q1', 'label::English (en)': 'IN PROGRESS EDIT', 'label::Polski (pl)': 'old' }] },
      {
        translated: ['label'],
        translations: ['English (en)', 'Polski (pl)'],
        survey: [{ name: 'q1', label: ['Different English', 'Nowy'] }],
      },
      'English (en)',
    )
    expect(result.survey[0]['label::English (en)']).to.equal('IN PROGRESS EDIT') // protected suffixed key preserved
    expect(result.survey[0]['label::Polski (pl)']).to.equal('Nowy')
  })

  it('4. leaves no phantom key for a language removed from fresh translations', () => {
    const result = merge(
      {
        survey: [
          { name: 'q1', 'label::English (en)': 'Hello', 'label::Polski (pl)': 'Cześć', 'label::Deutsch (de)': 'Hallo' },
        ],
      },
      {
        translated: ['label'],
        translations: ['English (en)', 'Polski (pl)'], // Deutsch removed
        survey: [{ name: 'q1', label: ['Hello', 'Cześć'] }],
      },
      'English (en)',
    )
    expect(result.survey[0]).to.not.have.property('label::Deutsch (de)')
    expect(result.survey[0]['label::Polski (pl)']).to.equal('Cześć')
  })

  it('5. creates a new key for a language added to fresh translations', () => {
    const result = merge(
      { survey: [{ name: 'q1', 'label::English (en)': 'Hello', 'label::Polski (pl)': 'Cześć' }] },
      {
        translated: ['label'],
        translations: ['English (en)', 'Polski (pl)', 'Deutsch (de)'], // Deutsch added
        survey: [{ name: 'q1', label: ['Hello', 'Cześć', 'Hallo'] }],
      },
      'English (en)',
    )
    expect(result.survey[0]['label::Deutsch (de)']).to.equal('Hallo')
  })

  it('6. leaves a row present in surveyData but absent from fresh content completely untouched', () => {
    const result = merge(
      {
        survey: [
          { name: 'q1', 'label::English (en)': 'Hello', 'label::Polski (pl)': 'Cześć' },
          { name: 'q2', 'label::English (en)': 'New Q', 'label::Polski (pl)': 'unsaved' }, // newly added, unsaved
        ],
      },
      {
        translated: ['label'],
        translations: ['English (en)', 'Polski (pl)'],
        survey: [{ name: 'q1', label: ['Hello', 'Zmienione'] }],
      },
      'English (en)',
    )
    expect(result.survey[1]['label::English (en)']).to.equal('New Q')
    expect(result.survey[1]['label::Polski (pl)']).to.equal('unsaved') // untouched
  })

  it('7. updates a choice matched by name + list_name (no $kuid)', () => {
    const result = merge(
      { choices: [{ name: 'yes', list_name: 'yn', 'label::English (en)': 'Yes', 'label::Polski (pl)': 'STALE' }] },
      {
        translated: ['label'],
        translations: ['English (en)', 'Polski (pl)'],
        choices: [{ name: 'yes', list_name: 'yn', label: ['Yes', 'Tak'] }],
      },
      'English (en)',
    )
    expect(result.choices[0]['label::Polski (pl)']).to.equal('Tak')
    expect(result.choices[0]['label::English (en)']).to.equal('Yes')
  })

  it('8. resolves langNames[0] from translations_0 when translations[0] is null', () => {
    // protectedLangName is null here so the index-0 write is observable: if the
    // translations_0 fallback works, the value lands under `label::English (en)`
    // (suffixed); if it failed, it would land under the bare `label` key.
    const result = merge(
      { survey: [{ name: 'q1' }] },
      {
        translated: ['label'],
        translations: [null, 'Polski (pl)'],
        translations_0: 'English (en)',
        survey: [{ name: 'q1', label: ['Hello', 'Cześć'] }],
      },
      null,
    )
    expect(result.survey[0]['label::English (en)']).to.equal('Hello')
    expect(result.survey[0]['label::Polski (pl)']).to.equal('Cześć')
    expect(result.survey[0]).to.not.have.property('label')
  })

  it("9. doesn't reintroduce required_message on a signature row from fresh content (OC-28719)", () => {
    // Reproduces the reviewer-reported gap: `surveyToValidJson` already
    // stripped `required_message` from this signature row, but the
    // last-saved asset (`freshContent`) still has it translated - a
    // plausible pre-fix save, or a value pyxform kept from the original
    // XLSForm import. Without re-running the discard after the merge, this
    // step would silently restore it in every language.
    const result = merge(
      {
        survey: [
          {
            name: 'q1',
            type: 'select_multiple',
            'bind::oc:external': ECONSENT_SIGNATURE_EXTERNAL_VALUE,
          },
        ],
      },
      {
        translated: ['required_message'],
        translations: ['English (en)', 'Spanish (es)'],
        survey: [
          {
            name: 'q1',
            'bind::oc:external': ECONSENT_SIGNATURE_EXTERNAL_VALUE,
            required_message: ['This field is required', 'Este campo es obligatorio'],
          },
        ],
      },
      'English (en)',
    )
    const row = result.survey[0]
    expect(row).to.not.have.property('required_message')
    expect(row).to.not.have.property('required_message::English (en)')
    expect(row).to.not.have.property('required_message::Spanish (es)')
  })
})

describe('resolveCurrentPrimaryLanguage', () => {
  it('1. prefers the fresh asset primary language over the frozen mount snapshot', () => {
    const result = resolveCurrentPrimaryLanguage(
      { translations: ['French (fr)', 'English (en)'], translated: ['label'] },
      { translations_0: 'English (en)', translated: ['label', 'hint'] },
    )
    expect(result.primaryLangName).to.equal('French (fr)')
    expect(result.translatedProps).to.deep.equal(['label'])
  })

  it('2. falls back to translations_0 when fresh translations[0] is null', () => {
    const result = resolveCurrentPrimaryLanguage(
      { translations: [null, 'Polski (pl)'], translations_0: 'English (en)', translated: ['label'] },
      undefined,
    )
    expect(result.primaryLangName).to.equal('English (en)')
  })

  it('3. falls back to the frozen mount snapshot when there is no fresh content', () => {
    const result = resolveCurrentPrimaryLanguage(undefined, { translations_0: 'English (en)', translated: ['label'] })
    expect(result.primaryLangName).to.equal('English (en)')
    expect(result.translatedProps).to.deep.equal(['label'])
  })

  it('4. returns null and an empty list when neither source has a primary language', () => {
    const result = resolveCurrentPrimaryLanguage(undefined, undefined)
    expect(result.primaryLangName).to.equal(null)
    expect(result.translatedProps).to.deep.equal([])
  })
})

describe('surveyToValidJson - discard unsupported eConsent signature settings (OC-27875)', () => {
  // `survey.toFlatJSON()` is called twice by `surveyToValidJson`; return a
  // fresh shallow copy of each row every call so the two calls can't leak
  // mutations into one another (matching the real Backbone model, which
  // recomputes its flat representation from scratch each time).
  const fakeSurvey = (rows) => ({
    toFlatJSON: () => ({ survey: rows.map((row) => ({ ...row })), settings: [{}] }),
  })

  const toValidSurvey = (rows) => JSON.parse(surveyToValidJson(fakeSurvey(rows)))

  const unsupportedRow = (externalValue) => ({
    type: 'select_multiple',
    name: 'q1',
    'bind::oc:external': externalValue,
    'bind::oc:itemgroup': 'group1',
    appearance: 'multiline',
    required: 'yes',
    required_message: 'This field is required',
    readonly: 'yes',
    default: 'today()',
    calculation: 'today()+3',
    trigger: '${other_question}',
  })

  it('strips item group, appearance, required, required message, readonly, default, calculation and trigger from a "signature" row', () => {
    const result = toValidSurvey([unsupportedRow(ECONSENT_SIGNATURE_EXTERNAL_VALUE)])
    const row = result.survey[0]
    expect(row).to.not.have.property('bind::oc:itemgroup')
    expect(row).to.not.have.property('appearance')
    expect(row).to.not.have.property('required')
    expect(row).to.not.have.property('required_message')
    expect(row).to.not.have.property('readonly')
    expect(row).to.not.have.property('default')
    expect(row).to.not.have.property('calculation')
    expect(row).to.not.have.property('trigger')
  })
  ;['clinicaldata', 'contactdata', 'identifier'].forEach((externalValue) => {
    it(`leaves a "${externalValue}" row untouched (out of scope for OC-27875)`, () => {
      const result = toValidSurvey([unsupportedRow(externalValue)])
      const row = result.survey[0]
      expect(row['bind::oc:itemgroup']).to.equal('group1')
      expect(row.appearance).to.equal('multiline')
      expect(row.required).to.equal('yes')
      expect(row.required_message).to.equal('This field is required')
      expect(row.readonly).to.equal('yes')
      expect(row.default).to.equal('today()')
      expect(row.calculation).to.equal('today()+3')
      expect(row.trigger).to.equal('${other_question}')
    })
  })

  it('leaves a row with an unrecognized bind::oc:external value untouched', () => {
    const result = toValidSurvey([unsupportedRow('some_future_value')])
    const row = result.survey[0]
    expect(row['bind::oc:itemgroup']).to.equal('group1')
    expect(row.appearance).to.equal('multiline')
  })

  it('preserves supported settings on a signature row untouched (AC4)', () => {
    const result = toValidSurvey([
      {
        type: 'select_multiple',
        name: 'q1',
        label: 'I consent',
        hint: 'Please confirm',
        relevant: '${some_question} = 1',
        'bind::oc:external': ECONSENT_SIGNATURE_EXTERNAL_VALUE,
      },
    ])
    const row = result.survey[0]
    expect(row.label).to.equal('I consent')
    expect(row.hint).to.equal('Please confirm')
    expect(row.relevant).to.equal('${some_question} = 1')
    expect(row['bind::oc:external']).to.equal(ECONSENT_SIGNATURE_EXTERNAL_VALUE)
  })

  it('leaves a non-eConsent row (no bind::oc:external) completely untouched', () => {
    const result = toValidSurvey([
      {
        type: 'text',
        name: 'q1',
        'bind::oc:itemgroup': 'group1',
        appearance: 'multiline',
        required: 'yes',
        required_message: 'This field is required',
        readonly: 'yes',
        default: 'today()',
        calculation: 'today()+3',
        trigger: '${other_question}',
      },
    ])
    const row = result.survey[0]
    expect(row['bind::oc:itemgroup']).to.equal('group1')
    expect(row.appearance).to.equal('multiline')
    expect(row.required).to.equal('yes')
    expect(row.required_message).to.equal('This field is required')
    expect(row.readonly).to.equal('yes')
    expect(row.default).to.equal('today()')
    expect(row.calculation).to.equal('today()+3')
    expect(row.trigger).to.equal('${other_question}')
  })

  it("doesn't add a field a signature row never had in the first place", () => {
    const result = toValidSurvey([
      { type: 'select_multiple', name: 'q1', 'bind::oc:external': ECONSENT_SIGNATURE_EXTERNAL_VALUE },
    ])
    expect(result.survey[0]).to.not.have.property('appearance')
  })

  it("doesn't add required_message to a signature row that never had it", () => {
    const result = toValidSurvey([
      { type: 'select_multiple', name: 'q1', 'bind::oc:external': ECONSENT_SIGNATURE_EXTERNAL_VALUE },
    ])
    expect(result.survey[0]).to.not.have.property('required_message')
  })

  it('strips required_message for every language, not just the primary one', () => {
    const result = toValidSurvey([
      {
        type: 'select_multiple',
        name: 'q1',
        'bind::oc:external': ECONSENT_SIGNATURE_EXTERNAL_VALUE,
        required_message: 'This field is required',
        'required_message::Spanish (es)': 'Este campo es obligatorio',
      },
    ])
    const row = result.survey[0]
    expect(row).to.not.have.property('required_message')
    expect(row).to.not.have.property('required_message::Spanish (es)')
  })

  it('only strips fields on the matching signature row, leaving other rows in the same survey untouched', () => {
    const result = toValidSurvey([
      { type: 'text', name: 'q1', 'bind::oc:external': 'contactdata', 'bind::oc:itemgroup': 'group1' },
      unsupportedRow(ECONSENT_SIGNATURE_EXTERNAL_VALUE),
    ])
    expect(result.survey[0]['bind::oc:itemgroup']).to.equal('group1')
    expect(result.survey[1]).to.not.have.property('bind::oc:itemgroup')
  })
})

describe('applyFreshPrimaryLanguage', () => {
  it('1. unnullifies the survey JSON when a primary language is found', () => {
    const surveyDataJSON = JSON.stringify({ settings: [{}], survey: [{ name: 'q1', label: 'Hello' }] })
    const result = applyFreshPrimaryLanguage(
      surveyDataJSON,
      { translations: ['English (en)'], translated: ['label'] },
      undefined,
    )
    expect(result.primaryLangName).to.equal('English (en)')
    const survey = JSON.parse(result.surveyDataJSON)
    expect(survey.survey[0]['label::English (en)']).to.equal('Hello')
  })

  it('2. leaves the survey JSON untouched when no primary language is found', () => {
    const surveyDataJSON = JSON.stringify({ settings: [{}], survey: [{ name: 'q1', label: 'Hello' }] })
    const result = applyFreshPrimaryLanguage(surveyDataJSON, undefined, undefined)
    expect(result.primaryLangName).to.equal(null)
    expect(result.surveyDataJSON).to.equal(surveyDataJSON)
  })

  it('3. overwrites a stale default_language with the fresh primary language', () => {
    const surveyDataJSON = JSON.stringify({
      settings: [{ default_language: 'English' }],
      survey: [{ name: 'q1', label: 'Hello' }],
    })
    const result = applyFreshPrimaryLanguage(
      surveyDataJSON,
      { translations: ['English (en)'], translated: ['label'] },
      { translations_0: 'English', translated: ['label'] },
    )
    const survey = JSON.parse(result.surveyDataJSON)
    expect(survey.settings[0].default_language).to.equal('English (en)')
    expect(survey.survey[0]['label::English (en)']).to.equal('Hello')
  })

  it('4. still fills an empty default_language', () => {
    const surveyDataJSON = JSON.stringify({ settings: [{}], survey: [{ name: 'q1', label: 'Hello' }] })
    const result = applyFreshPrimaryLanguage(
      surveyDataJSON,
      { translations: ['English (en)'], translated: ['label'] },
      undefined,
    )
    expect(JSON.parse(result.surveyDataJSON).settings[0].default_language).to.equal('English (en)')
  })

  it('5. leaves default_language alone when no primary language is found', () => {
    const surveyDataJSON = JSON.stringify({
      settings: [{ default_language: 'English' }],
      survey: [{ name: 'q1', label: 'Hello' }],
    })
    const result = applyFreshPrimaryLanguage(surveyDataJSON, undefined, undefined)
    expect(result.surveyDataJSON).to.equal(surveyDataJSON)
  })
})
