_ = require 'underscore'
Backbone = require 'backbone'
$baseView = require './view.pluggedIn.backboneView'
$viewTemplates = require './view.templates'
$icons = require './view.icons'
$configs = require './model.configs'
writeParameters = require('#/components/formBuilder/formBuilderUtils').writeParameters
econsentSignature = require('../../js/components/formBuilder/econsentSignature')

module.exports = do ->
  viewRowSelector = {}

  class viewRowSelector.RowSelector extends $baseView
    events:
      "click .js-close-row-selector": "shrink"

    initialize: (opts)->
      @options = opts
      @ngScope = opts.ngScope
      @reversible = opts.reversible
      @button = @$el.find(".btn").eq(0)
      @line = @$el.find(".line")
      if opts.action is "click-add-row"
        @expand()
      return

    expand: ->
      @$el.parents('.survey-editor__null-top-row--hidden').removeClass('survey-editor__null-top-row--hidden')
      @show_namer()
      $namer_form = @$el.find('.row__questiontypes__form')
      $namer_form.on 'submit', _.bind @show_picker, @
      $namer_form.find('button').on 'click', (evt) ->
        evt.preventDefault()
        $namer_form.submit()
        return
      @$('input').eq(0).focus()
      return

    show_namer: () ->
      $surveyViewEl = @options.surveyView.$el
      $surveyViewEl.find('.line.expanded').removeClass('expanded').empty()
      $surveyViewEl.find('.btn--hidden').removeClass('btn--hidden')

      @button.addClass('btn--hidden')

      @line.addClass "expanded"
      @line.parents(".survey-editor__null-top-row").addClass "expanded"
      @line.css "height", "inherit"
      @line.html $viewTemplates.$$render('xlfRowSelector.namer')
      @scrollFormBuilder('+=50')

      if (@options.surveyView.features.multipleQuestions)
        $(window).on 'keydown.cancel_add_question',  (evt) =>
          # user presses the escape key
          if evt.which == 27
            @shrink()
          return
      else
        $(window).on 'keydown.cancel_add_question',  (evt) =>
          # user presses the escape key
          if evt.which == 27
            evt.preventDefault()
            @$('input').eq(0).focus()
          return

        $('body').on 'mousedown.cancel_add_question', (evt) =>
          if $(evt.target).closest('.line.expanded').length == 0
            evt.preventDefault()
            @$('input').eq(0).focus()
          return
      return

    show_picker: (evt) ->
      evt.preventDefault()
      @question_name = @line.find('input').val()
      @line.empty()
      @line.html $viewTemplates.$$render('xlfRowSelector.line', "")
      @line.find('.row__questiontypes__new-question-name').val(@question_name)
      $menu = @line.find(".row__questiontypes__list")
      availableFiles = @options.survey.availableFiles || []
      econsentIcon = null
      for mrow in $icons.grouped()
        menurow = $("<div>", class: "questiontypelist__row").appendTo $menu
        for mitem, i in mrow when mitem
          if availableFiles.length is 0 and ['select_one_from_file', 'select_multiple_from_file'].includes(mitem.get('id'))
            continue
          if mitem.get('id') is 'econsent_signature'
            econsentIcon = mitem
            continue
          menurow.append $viewTemplates.$$render('xlfRowSelector.cell', mitem.attributes)

      if econsentIcon and econsentSignature.isEConsentSignatureItemTypeAllowed()
        menurow = $("<div>", class: "questiontypelist__row").appendTo $menu
        menurow.append $viewTemplates.$$render('xlfRowSelector.cell', econsentIcon.attributes)

      @scrollFormBuilder('+=220')
      @$('.questiontypelist__item').click _.bind(@onSelectNewQuestionType, @)
      # OpenClinica: keyboard navigation (arrow keys + ENTER) intentionally removed
      return

    shrink: ->
      # click .js-close-row-selector
      $(window).off 'keydown.cancel_add_question'
      $('body').off 'mousedown.cancel_add_question'
      @line.find("div").eq(0).fadeOut 250, =>
        @line.empty()
        return
      @line.parents(".survey-editor__null-top-row").removeClass "expanded"
      if (@line.parents('.survey-editor').find('.survey__row').length)
        @line.parents(".survey-editor__null-top-row").addClass "survey-editor__null-top-row--hidden"
      @line.removeClass "expanded"
      @line.animate height: "0"
      if @reversible
        @button.removeClass('btn--hidden')
      return

    hide: ->
      @button.removeClass('btn--hidden')
      @line.empty().removeClass("expanded").css "height": 0
      @line.parents(".survey-editor__null-top-row")
          .removeClass("expanded")
          .addClass("survey-editor__null-top-row--hidden")
      return

    ###
    # This is the callback for final step of adding new question to Form Builder.
    # It happens after user chooses question type, and results in new row being added.
    ###
    onSelectNewQuestionType: (evt)->
      @question_name = @line.find('input').val()

      # Here some unknown cleanup of select2 happens, not sure why at this point given it seems to be related to skip
      # logic, which is not being available during question creation
      $rowSelect = $('select.skiplogic__rowselect')
      if $rowSelect.data('select2')
        $rowSelect.select2('destroy')

      # Selected row type is being deducted by checking out data attribute of clicked node.
      rowType = $(evt.target).closest('.questiontypelist__item').data("menuItem")

      # if question name not provided by user, use default one for type or general one
      if @question_name
        questionLabelValue = @question_name.replace(/\t/g, ' ')
      else
        questionLabelValue = ''

      # this is the de facto row object that will end up in Backbone Collection of rows
      rowDetails =
        type: rowType

      if rowType is 'pii_encrypted'
        rowDetails.type = 'text'
        rowDetails['bind::oc:external'] = 'contactdata'
        rowDetails['bind::oc:itemgroup'] = ''
        rowDetails['instance::oc:contactdata'] = ''
        # For PII (Encrypted) items, Description and Brief Description must be blank
        rowDetails['bind::oc:briefdescription'] = ''
        rowDetails['bind::oc:description'] = ''

      if rowType is 'econsent_signature'
        rowDetails.type = 'select_multiple'
        rowDetails['bind::oc:external'] = 'signature'
        rowDetails['bind::oc:itemgroup'] = ''

      rowDetails.label = questionLabelValue

      if questionLabelValue != ''
        rowDetails.name = questionLabelValue.toLowerCase().replace(/ /g,"_").replace(/\W/g, '')
      else
        if rowType is 'calculate'
          rowDetails.name = 'calculation'

      # These options are needed for `addRow` function, so that it knows where to put the row we're adding.
      options = {}
      if (rowBefore = @options.spawnedFromView?.model)
        options.after = rowBefore
        survey = rowBefore.getSurvey()
      else
        survey = @options.survey
        options.at = 0

      # For some questions we start off with some parameters having default values.
      # The code was added mostly for `image` to have some initial `max-pixels`.
      typeConfig = $configs.questionParams[rowType]
      initialParameters = {}
      for configName, configValue of typeConfig
        # We need to allow such values as `0` or `false` here, thus a more lengthy check
        if (configValue.defaultValue isnt null and configValue.defaultValue isnt undefined)
          initialParameters[configName] = configValue.defaultValue
      if (Object.keys(initialParameters).length > 0)
        rowDetails.parameters = writeParameters(initialParameters)

      rowDetails.isNewRow = true

      # Here we add the row to the survey
      newRow = survey.addRow(rowDetails, options)
      # …and link it up (TODO what?)
      newRow.linkUp(warnings: [], errors: [])
      if rowType is 'econsent_signature'
        econsentSignature.ensureEConsentSignatureStructure(newRow, '')
      @hide()
      return

    ###
    # Scrolls the newly opened element into the screen if it is being opened
    # below the fold. Calling the function doesn't cause the scrolling
    # to happen unless it passes the checks.
    ###
    scrollFormBuilder: (scrollBy)->
      $row = @$el.parents('.survey__row')
      if !$row.length
        return

      $fbC = @$el.parents('.form-builder__contents')

      if $row.height() + $row.position().top + 50 > $fbC.height() + $fbC.prop('scrollTop')
        $fbC.animate scrollTop: scrollBy
      return

  return viewRowSelector
