{expect} = require('../helper/fauxChai')
$ = require('jquery')

window.t ?= (str) -> str

$model = require('../../jsapp/xlform/src/_model')

# P1.20 (OC-28845): logic panel headings and help text.
do ->
  viewRowDetail = require('../../jsapp/xlform/src/view.rowDetail')
  $rowTemplates = require('../../jsapp/xlform/src/view.row.templates')

  renderRelevant = (detail) ->
    detail.facade = {render: ->}
    ctx = $.extend({}, viewRowDetail.DetailViewMixins.relevant, {
      $el: $('<div><div class="relevant__editor"></div></div>')
      model: detail
      rowView: {listenTo: ->}
    })
    ctx.$ = (sel) -> ctx.$el.find(sel)
    ctx.afterRender()
    ctx.$el

  describe 'P1.20: Relevant Logic panel heading and help text', ->
    beforeEach -> window.xlfHideWarnings = true
    afterEach -> window.xlfHideWarnings = false

    it 'says "item" for a question', ->
      survey = new $model.Survey()
      survey.rows.add(type: 'text', name: 'q', label: 'Q')
      $el = renderRelevant(survey.rows.at(0).get('relevant'))
      expect($el.find('.logic-panel__head h2').text()).toBe('Relevant Logic - when should this item be shown?')
      expect($el.find('.logic-panel__help').text()).toBe('This item is shown only when the expression is true. Leave it blank to always show the item.')

    it 'says "group" for a group (AC2)', ->
      survey = new $model.Survey()
      survey.rows.add(type: 'text', name: 'q', label: 'Q')
      survey._addGroup(label: 'G', __rows: [survey.rows.at(0)])
      $el = renderRelevant(survey.rows.at(0).get('relevant'))
      expect($el.find('.logic-panel__head h2').text()).toBe('Relevant Logic - when should this group be shown?')
      expect($el.find('.logic-panel__help').text()).toBe('This group is shown only when the expression is true. Leave it blank to always show the group.')

    it 'keeps the heading and help outside .skiplogic__main, which mode switches empty', ->
      survey = new $model.Survey()
      survey.rows.add(type: 'text', name: 'q', label: 'Q')
      $el = renderRelevant(survey.rows.at(0).get('relevant'))
      $el.find('.skiplogic__main').empty()
      expect($el.find('.logic-panel__head').length).toBe(1)
      expect($el.find('.logic-panel__help').length).toBe(1)

  describe 'P1.20: Validation Criteria help text sits beneath Error message', ->
    insert = (key, $settings) ->
      ctx = $.extend({}, viewRowDetail.DetailViewMixins[key], {el: $("<li class='is-#{key}'/>").get(0)})
      ctx._insertInDOM = (where, how) -> where[how || 'append'](@el)
      ctx.insertInDOM({cardSettingsWrap: $settings})

    order = ($settings) ->
      $settings.find('.js-card-settings-validation-criteria').children().map(-> @className).get()

    help = 'card__settings__fields__field js-validation-help'

    it 'when the constraint view renders first', ->
      $settings = $('<div><ul class="js-card-settings-validation-criteria"></ul></div>')
      insert('constraint', $settings)
      insert('constraint_message', $settings)
      expect(order($settings)).toEqual(['is-constraint', 'is-constraint_message', help])

  describe 'P1.20: Repeat Count panel', ->
    it 'renders the heading row, a labelled Expression input, help text and the doc link', ->
      ctx = $.extend({}, viewRowDetail.DetailViewMixins.repeat_count, {cid: 'c9', $el: $('<div/>'), model: {}})
      ctx.html()
      expect(ctx.$el.find('.logic-panel__head h2').text()).toBe('Repeat Count - how many times should this group repeat?')
      expect(ctx.$el.find('label[for="c9-repeat-count"]').text()).toBe('Expression')
      expect(ctx.$el.find('input#c9-repeat-count').length).toBe(1)
      expect(ctx.$el.find('.logic-panel__help').text()).toBe('Enter a number or an XLSForm expression to set how many times this group repeats. Leave it blank to let users add and remove repeats themselves.')
      expect(ctx.$el.find('.panel__doc-link').text()).toContain('for more information about XLSForm expressions.')

  describe 'P1.20: logic panel templates share the heading row', ->
    for [name, heading] in [
      ['requiredLogicPanel', 'Required Logic - when should this item be required?']
      ['defaultValuePanel', 'Default Value - what should this item start with?']
      ['calculationPanel', "Calculation - how should this item's value be calculated?"]
    ]
      do (name, heading) ->
        it "#{name} renders its heading in .logic-panel__head with the doc link", ->
          $panel = $($rowTemplates[name]('c1'))
          expect($panel.find('.logic-panel__head h2').text()).toBe(heading)
          expect($panel.find('.panel__doc-link').text()).toContain('for more information about XLSForm expressions.')
    return
