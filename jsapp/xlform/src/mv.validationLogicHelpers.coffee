$validationLogicParser = require './model.validationLogicParser'
$skipLogicHelpers = require './mv.skipLogicHelpers'
$syntaxCheckBridge = require '#/openclinica/syntaxCheckBridge'

module.exports = do ->
  validationLogicHelpers = {}

  class validationLogicHelpers.ValidationLogicHelperFactory extends $skipLogicHelpers.SkipLogicHelperFactory
    create_presenter: (criterion_model, criterion_view) ->
      return new validationLogicHelpers.ValidationLogicPresenter criterion_model, criterion_view, @current_question, @survey, @view_factory
    create_builder: () ->
      return new validationLogicHelpers.ValidationLogicBuilder @model_factory, @view_factory, @survey, @current_question, @
    create_context: () ->
      return new validationLogicHelpers.ValidationLogicHelperContext @model_factory, @view_factory, @, @serialized_criteria

  class validationLogicHelpers.ValidationLogicPresenter extends $skipLogicHelpers.SkipLogicPresenter
    change_question: () -> return

  class validationLogicHelpers.ValidationLogicBuilder extends $skipLogicHelpers.SkipLogicBuilder
    _parse_skip_logic_criteria: (criteria) ->
      return $validationLogicParser criteria

    _get_question: () ->
      @current_question

    build_empty_criterion: () ->
      operator_picker_view = @view_factory.create_operator_picker @current_question.get_type()

      response_value_view = @view_factory.create_response_value_view @current_question, @current_question.get_type(), @_operator_type()

      presenter = @build_criterion_logic @model_factory.create_operator('empty'), operator_picker_view, response_value_view

      presenter.model.change_question @current_question.cid

      return presenter

    questions: () ->
      return [@current_question]

    _operator_type: () ->
      operator_type = super()

      if not operator_type?
        operator_type_id = @current_question.get_type().operators[0]
        operator_type = $skipLogicHelpers.operator_types[if operator_type_id == 1 then @current_question.get_type().operators[1] else operator_type_id]
      return operator_type

  class validationLogicHelpers.ValidationLogicHelperContext extends $skipLogicHelpers.SkipLogicHelperContext
    use_mode_selector_helper: () ->
      if !@questionTypeHasResponseType()
        @use_hand_code_helper()
      else
        @state = new validationLogicHelpers.ValidationLogicModeSelectorHelper @view_factory, @
        @render @destination
        # P1.13: the expression is now empty without a check having run — reset
        # the verdict memory (see mv.skipLogicHelpers use_mode_selector_helper).
        row = @helper_factory.current_question
        $syntaxCheckBridge.forgetSyntaxVerdictFor(row, 'constraint')
      return
    use_hand_code_helper: () ->
      @state = new validationLogicHelpers.ValidationLogicHandCodeHelper(@state.serialize(), @builder, @view_factory, @)
      if !@questionTypeHasResponseType()
        @state.button = @view_factory.create_empty()
      @render @destination
      return

    questionTypeHasResponseType: () ->
      typeId = @helper_factory.current_question.get('type').get('typeId')
      # Note: Leszek: seems like a dead code, can't figure out how to setup a test to trigger it.
      if !typeId
        return console.error('no type id found for question', @helper_factory.current_question)
      question_type = $skipLogicHelpers.question_types[typeId] || $skipLogicHelpers.question_types['default']
      return question_type.response_type?

  class validationLogicHelpers.ValidationLogicModeSelectorHelper extends $skipLogicHelpers.SkipLogicModeSelectorHelper
    constructor: (view_factory, context) ->
      @context = context
      super(view_factory, context)
      @handcode_button = view_factory.create_button '<i>${}</i> ' + t("Manually enter your validation logic in XLSForm code"), 'kobo-button kobo-button--blue'

  class validationLogicHelpers.ValidationLogicHandCodeHelper extends $skipLogicHelpers.SkipLogicHandCodeHelper
    @criteria_value = @criteria
    render: ($destination) ->
      # OC fork (PR#273 round-7): render INTO the destination like the skip-logic
      # hand-code helper — replaceWith() detached the constraint panel's render
      # anchor (.skiplogic__main), so every later change:value re-render landed in
      # the detached node, and this input sat outside the .skiplogic__main scope
      # the post-Apply focus lookup searches. The helper context empties the
      # destination before each render, so nothing accumulates; the mode-selector
      # button no longer needs to swap the anchor back, only to switch helpers.
      $destination.append(@$handCode)
      @button.render().attach_to @$handCode
      @button.bind_event 'click', () =>
        @context.use_mode_selector_helper()
      @$handCode.on('change', () =>
        @criteria = @criteria_value.replace(/&quot;/g, '"');
        @context.view_factory.survey.trigger('change')
        # P1.11 AC1: hand-code mode is the only place Constraint has a single
        # free-text field to check; the row-based builder mode has none.
        # Anchor is found by walking up from the field itself, not a
        # document-wide query, so a second open drawer can't be hit.
        row = @context.helper_factory.current_question
        anchor = @textarea.closest('.skiplogic__main').get(0)
        $syntaxCheckBridge.runSyntaxCheck(row, 'constraint', anchor)
      )
    serialize: () ->
      @textarea.val()
    constructor: (criteria, builder, view_factory, context) ->
      super(criteria, builder, view_factory, context)
      @criteria_value = @criteria.replace(/"/g, '&quot;');
      @$handCode = $("""
        <div class="card__settings__fields__field">
          <label class="logic-panel__label" for="#{@context.helper_factory.current_question.cid}-handcode">#{t("Expression")}</label>
          <span class="settings__input">
            <input type="text" name="constraint" id="#{@context.helper_factory.current_question.cid}-handcode" class="text" value="#{@criteria_value}" placeholder="#{t('No constraint yet — type one, or use the AI Assistant.')}">
          </span>
        </div>
      """)
      @textarea = @$handCode.find('#' + @context.helper_factory.current_question.cid + '-handcode')
      # Textarea starts with empty value - setting it in HTML caused error with
      # mangled values (due to " character). Set initial value here, so all the
      # special characters are saved.
      @textarea.val(@criteria)
      return


  validationLogicHelpers
