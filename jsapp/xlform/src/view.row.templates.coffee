module.exports = do ->
  replaceSupportEmail = require('#/textUtils').replaceSupportEmail

  XPATH_DOCS_URL = 'https://servicedesk.openclinica.com/support/solutions/articles/158000436443-form-logic'

  xpathDocLinkHtml = ->
    """<p class="panel__doc-link">#{t('See the')} <a href="#{XPATH_DOCS_URL}" target="_blank" rel="noopener noreferrer">#{t('documentation')}</a> #{t("for more information about XLSForm expressions.")}</p>"""

  # P1.20 AC6: every logic panel's heading shares a row with its AI Assistant
  # button, which mounts into .logic-panel__head after the heading and sits at
  # the row's right edge (_card_settings.scss).
  logicPanelHeadHtml = (headerClass, title) -> """<div class="logic-panel__head"><h2 class="#{headerClass}">#{title}</h2></div>"""

  expandingSpacerHtml = """
      <div class="survey__row__spacer  row clearfix expanding-spacer-between-rows expanding-spacer-between-rows--depr">
        <button type="button" class="js-expand-row-selector js-add-row-button btn btn--addrow"
            ><i class="k-icon k-icon-plus" aria-hidden="true"></i><span class="btn--addrow-label">#{t("Add Item")}</span></button>
        <div class="survey__row__spacer-rule"></div>
        <div class="line">&nbsp;</div>
      </div>
  """

  # OC-28571 AC4: an insertion point above the very first item in a list or
  # group. Prepended (by view.surveyApp.coffee's ensureLeadingSpacer) as the
  # first child of whichever row is currently first in its collection, so it
  # shares the existing `.survey__row:hover > .survey__row__spacer` reveal
  # rule and the `.js-expand-row-selector` click delegation for free. The
  # `--leading` marker is what expandRowSelector uses to insert the new row
  # before this one instead of after it.
  leadingSpacerHtml = """
      <div class="survey__row__spacer  survey__row__spacer--leading  row clearfix expanding-spacer-between-rows expanding-spacer-between-rows--depr">
        <button type="button" class="js-expand-row-selector js-add-row-button btn btn--addrow"
            ><i class="k-icon k-icon-plus" aria-hidden="true"></i><span class="btn--addrow-label">#{t("Add Item")}</span></button>
        <div class="survey__row__spacer-rule"></div>
        <div class="line">&nbsp;</div>
      </div>
  """

  # OC-28572 AC4: a Layout Group with no children has no row to attach a
  # leading/trailing spacer to (GroupView's own render loop never runs), so
  # this is the group's only content — rendered in place of that loop, and
  # kept always visible (see CSS) since there's nothing to hover to reveal
  # it. Its aria-label (AC5) is fixed rather than computed at render time,
  # since this control unambiguously always adds inside this group.
  emptyGroupSpacerHtml = """
      <div class="survey__row__spacer  survey__row__spacer--empty-group  row clearfix expanding-spacer-between-rows expanding-spacer-between-rows--depr">
        <button type="button" class="js-expand-row-selector js-add-row-button btn btn--addrow" aria-label="#{t('Add item inside this group')}" title="#{t('Add item inside this group')}"
            ><i class="k-icon k-icon-plus" aria-hidden="true"></i><span class="btn--addrow-label">#{t("Add Item")}</span></button>
        <div class="survey__row__spacer-rule"></div>
        <div class="line">&nbsp;</div>
      </div>
  """

  iconTooltip = (title, message) ->
    return """
      <div class="k-tooltip"><strong>#{title}</strong><p>#{message}</p></div>
    """

  lockedFeatures = (features) ->
    cantsString = ''
    cansString = ''

    if features isnt null
      features.cants.forEach((cant) ->
        cantsString += "<li><i class='k-icon k-icon-close'></i>#{cant.label}</li>"
        return
      )
      features.cans.forEach((can) ->
        cansString += "<li><i class='k-icon k-icon-check'></i>#{can.label}</li>"
        return
      )

    cansHtml = ''
    if cansString isnt ''
      cansHtml = """
        <ul class="locked-features__list locked-features__list--cans">
          <label>#{t('Unlocked functionalities')}</label>
          #{cansString}
        </ul>
      """

    return """
      <section class="locked-features">
        <ul class="locked-features__list locked-features__list--cants">
          <label>#{t('Locked functionalities')}</label>
          #{cantsString}
        </ul>

        #{cansHtml}
      </section>
    """

  groupSettingsView = ->
    template = """
      <section class="card__settings  row-extras row-extras--depr">
        <i class="card__settings-close k-icon k-icon-close js-toggle-card-settings"></i>
        <ul class="card__settings__tabs">
          <li class="heading"><i class="k-icon k-icon-edit"></i> #{t("Edit")}</li>
          <li data-card-settings-tab-id="row-options" class="card__settings__tabs__tab card__settings__tabs__tab--active">
            #{t("All group settings")}
          </li>
          <li data-card-settings-tab-id="relevant-logic" class="card__settings__tabs__tab">
            #{t("Relevant Logic")}
          </li>
          <li data-card-settings-tab-id="repeat-count" class="card__settings__tabs__tab js-repeat-count-tab repeat-count-tab--hidden">
            #{t("Repeat Count")}
          </li>
          <li data-card-settings-tab-id="locked-features" class="card__settings__tabs__tab locking__ui-hidden">
            #{t("Locked Features")}
          </li>
        </ul>
        <div class="card__settings__content">
          <button type="button" class="card__settings__back js-toggle-card-settings" aria-label="#{t('Back')}">
            <i class="k-icon k-icon-arrow-left" aria-hidden="true"></i>
          </button>
          <ul class="js-card-settings-row-options card__settings__fields card__settings__fields--active"></ul>
          <div class="js-card-settings-appearance card__settings__appearance-section is-collapsed">
            <div class="card__settings__appearance-header js-appearance-toggle" role="button" tabindex="0" aria-expanded="false">
              <span class="card__settings__appearance-title">#{t('Appearance')}</span>
              <span class="js-appearance-pill card__settings__appearance-pill" style="display:none"></span>
              <i class="k-icon k-icon-angle-down card__settings__appearance-toggle__icon" aria-hidden="true"></i>
            </div>
            <div class="js-appearance-body card__settings__appearance-body"></div>
          </div>
          <ul class="js-card-settings-relevant-logic card__settings__fields"></ul>
          <ul class="js-card-settings-repeat-count card__settings__fields card__settings__fields--repeat-count"></ul>
          <ul class="js-card-settings-locked-features card__settings__fields locking__ui-hidden"></ul>
        </div>
      </section>
    """
    return template
  rowSettingsView = ()->
    template = """
      <section class="card__settings  row-extras row-extras--depr">
        <i class="card__settings-close k-icon k-icon-close js-toggle-card-settings"></i>
        <ul class="card__settings__tabs">
          <li class="heading"><i class="k-icon k-icon-edit"></i> #{t("Edit")}</li>
          <li data-card-settings-tab-id="row-options" class="card__settings__tabs__tab--active">
            #{t("Question Options")}
          </li>
          <li data-card-settings-tab-id="relevant-logic" class="card__settings__tabs__tab">
            #{t("Relevant Logic")}
          </li>
          <li data-card-settings-tab-id="validation-criteria" class="card__settings__tabs__tab">
            #{t("Validation Criteria")}
          </li>
          <li data-card-settings-tab-id="required-logic" class="card__settings__tabs__tab js-required-logic-tab">
            <span class="js-required-logic-tab-label">#{t("Required Logic")}</span>
            <span class="js-required-logic-error required-logic-error-badge" style="display:none">!</span>
          </li>
          <li data-card-settings-tab-id="default-value" class="card__settings__tabs__tab js-default-value-tab default-value-tab--hidden">
            #{t("Default Value")}
          </li>
          <li data-card-settings-tab-id="calculation" class="card__settings__tabs__tab js-calculation-tab calculation-tab--hidden">
            <span>#{t("Calculation")}</span>
            <span class="calculation-tab__error js-calculation-tab-error calculation-tab__error--hidden">!</span>
          </li>
          <li data-card-settings-tab-id="locked-features" class="card__settings__tabs__tab locking__ui-hidden">
            #{t("Locked Features")}
          </li>
        </ul>
        <div class="card__settings__content">
          <button type="button" class="card__settings__back js-toggle-card-settings" aria-label="#{t('Back')}">
            <i class="k-icon k-icon-arrow-left" aria-hidden="true"></i>
          </button>
          <div class="js-card-settings-row-options card__settings__fields card__settings__fields--active card__settings__row-options">
            <div class="card__settings__fields-grid js-card-settings-row-options-primary">
              <div class="card__settings__fields-col js-card-settings-col-left"></div>
              <div class="card__settings__fields-col js-card-settings-col-right"></div>
            </div>
            <div class="js-card-settings-appearance card__settings__appearance-section is-collapsed">
              <div class="card__settings__appearance-header js-appearance-toggle" role="button" tabindex="0" aria-expanded="false">
                <span class="card__settings__appearance-title">#{t('Appearance')}</span>
                <span class="js-appearance-pill card__settings__appearance-pill" style="display:none"></span>
                <i class="k-icon k-icon-angle-down card__settings__appearance-toggle__icon" aria-hidden="true"></i>
              </div>
              <div class="js-appearance-body card__settings__appearance-body"></div>
            </div>
            <div class="js-appearance-section appearance-section appearance-section--hidden">
              <div class="card__settings__appearance-header js-appearance-section-toggle" aria-expanded="false">
                <span class="card__settings__appearance-title">#{t('Appearance')}</span>
                <span class="js-appearance-pill card__settings__appearance-pill"></span>
                <i class="k-icon k-icon-angle-down card__settings__appearance-toggle__icon" aria-hidden="true"></i>
              </div>
              <div class="js-appearance-card-content appearance-card-content is-collapsed"></div>
            </div>
            <div class="card__settings__advanced-toggle js-card-settings-advanced-toggle" aria-expanded="false" aria-controls="js-card-settings-row-options-advanced">
              <span>#{t('Advanced options')}</span>
              <i class="k-icon k-icon-angle-down card__settings__advanced-toggle__icon" aria-hidden="true"></i>
            </div>
            <div id="js-card-settings-row-options-advanced" class="card__settings__fields-grid js-card-settings-row-options-advanced is-collapsed"></div>
          </div>
          <ul class="js-card-settings-relevant-logic card__settings__fields"></ul>
          <ul class="js-card-settings-validation-criteria card__settings__fields"></ul>
          <div class="js-card-settings-required-logic card__settings__fields"></div>
          <div class="js-card-settings-default-value card__settings__fields"></div>
          <div class="js-card-settings-calculation card__settings__fields"></div>
          <ul class="js-card-settings-locked-features card__settings__fields locking__ui-hidden"></ul>
        </div>
      </section>
    """
    return template

  xlfRowView = (surveyView) ->
      template = """
      <div class="survey__row__item survey__row__item--question card js-select-row">
        <div class="card__header">
          <div class="card__header--shade"><span></span></div>
          <div class="card__indicator">
            <div class="noop card__indicator__icon"><i class="card__header-icon"></i></div>
          </div>
          <div class="card__text">
            <div class="card__header-name js-cancel-select-row js-cancel-sort"></div>
            <textarea rows="1" placeholder="#{t("Enter question label (required for item to be visible)")}" class="card__header-title js-card-label js-cancel-select-row js-cancel-sort" dir="auto"></textarea>
            <input type="text" placeholder="#{t("Enter question hint (optional)")}" class="card__header-hint js-card-hint js-cancel-select-row js-cancel-sort" dir="auto">
          </div>
          <div class="card__buttons">
            <span class="card__buttons__button card__buttons__button--settings card__buttons__button--gray js-toggle-card-settings" data-button-name="settings"><i class="k-icon k-icon-edit"></i></span>
            <span class="card__buttons__button card__buttons__button--delete card__buttons__button--red js-delete-row" data-button-name="delete"><i class="k-icon k-icon-trash"></i></span>
      """
      if surveyView.features.multipleQuestions
        template += """<span class="card__buttons__button card__buttons__button--copy card__buttons__button--blue js-clone-question" data-button-name="duplicate"><i class="k-icon k-icon-duplicate"></i></span>"""
        if surveyView.canAddToLibrary
          template += """<span class="card__buttons__button card__buttons__button--add card__buttons__button--teal js-add-to-question-library" data-button-name="add-to-library"><i class="k-icon k-icon-folder-plus"></i></span>"""

      return template + """
          </div>
        </div>
      </div>
      #{expandingSpacerHtml}
      """

  # This will be used by row types that are valid XLSForm types but are not yet supported by UI
  unsupportedRowView = () ->
    template = """
    <div style="display: none;">This type of row is not supported by UI yet.</div>
    """
    return template

  # Empty js-group-icon is only sometimes used, but we need to reserve space for it
  groupView = (surveyView)->
    addToLibraryButton = ''
    if surveyView.canAddToLibrary
      addToLibraryButton = """
          <span class="card__buttons__button card__buttons__button--add card__buttons__button--green js-add-group-to-library" data-button-name="add-group-to-library">
            <i class="k-icon k-icon-folder-plus"></i>
          </span>
      """
    template = """
    <div class="survey__row__item survey__row__item--group group card js-select-row">
      <header class="group__header">
        <div class="group__header__icon js-group-icon">
          <i class="k-icon"></i>
        </div>
        <i class="group__caret js-toggle-group-expansion k-icon k-icon-caret-down"></i>
        <input type="text" class="card__header-title js-card-label js-cancel-select-row js-cancel-sort" dir="auto">
        <div class="card__buttons">
          <span class="card__buttons__button card__buttons__button--settings card__buttons__button--gray js-toggle-card-settings">
            <i class="k-icon k-icon-edit"></i>
          </span>

          <span class="card__buttons__button card__buttons__button--delete card__buttons__button--red js-delete-group">
            <i class="k-icon k-icon-trash"></i>
          </span>

          <span class="card__buttons__button card__buttons__button--clone card__buttons__button--gray js-clone-group" data-button-name="duplicate">
            <i class="k-icon k-icon-duplicate"></i>
          </span>

          #{addToLibraryButton}
        </div>
      </header>
      <ul class="group__rows"></ul>
    </div>
    #{expandingSpacerHtml}
    """
    return template

  koboMatrixView = () ->
      template = """
      <div class="survey__row__item survey__row__item--question card js-select-row">
        <div class="card__header">
          <div class="card__header--shade"><span></span></div>
          <div class="card__indicator">
            <div class="noop card__indicator__icon"><i class="card__header-icon k-icon k-icon-matrix"></i></div>
          </div>
          <div class="card__text">
            <input type="text" placeholder="#{t("Item label is required")}" class="card__header-title js-card-label js-cancel-select-row js-cancel-sort" dir="auto">
          </div>
          <div class="card__buttons">
            <span class="card__buttons__button card__buttons__button--settings card__buttons__button--gray js-toggle-card-settings" data-button-name="settings"><i class="k-icon k-icon-edit"></i></span>
            <span class="card__buttons__button card__buttons__button--delete card__buttons__button--red js-delete-row" data-button-name="delete"><i class="k-icon k-icon-trash"></i></span>
          </div>
        </div>
        <p class="kobomatrix-warning">#{t("Note: The Matrix question type only works in Enketo web forms using the 'grid' style.")}</p>

        <div class="card__kobomatrix">
      """
      return template + """
        </div>
      </div>
      #{expandingSpacerHtml}
      """

  scoreView = (template_args={})->
    fillers = []
    cols = []
    for col in template_args.score_choices
      fillers.push """<td class="scorecell__radio"><input type="radio" disabled="disabled"></td>"""
      autoname_class = ""
      autoname_attr = ""
      if col.autoname
        autoname_class = "scorecell__name--automatic"
        autoname_attr = """data-automatic-name="#{col.autoname}" """
      namecell = """
        <p class="scorecell__name #{autoname_class}" #{autoname_attr} contenteditable="true" title="Option value">#{col.name or ''}</p>
      """
      cols.push """
        <th class="scorecell__col" data-cid="#{col.cid}">
          <span class="scorecell__label" contenteditable="true">#{col.label}</span><button class="scorecell__delete js-delete-scorecol">&times;</button>
          #{namecell}
        </th>
        """
    thead_html = cols.join('')
    fillers = fillers.join('')
    tbody_html = for row in template_args.score_rows
      autoname_attr = ""
      autoname_class = ""
      if row.autoname
        autoname_class = "scorelabel__name--automatic"
        autoname_attr = """data-automatic-name="#{row.autoname}" """

      scorelabel__name = """
        <span class="scorelabel__name #{autoname_class}" #{autoname_attr} contenteditable="true" title="#{t("Row name")}">#{row.name or ''}</span>
      """

      """
      <tr data-row-cid="#{row.cid}">
        <td class="scorelabel">
          <span class="scorelabel__edit" contenteditable="true">#{row.label}</span>
          <button class="scorerow__delete js-delete-scorerow">&times;</button>
          <br>
          #{scorelabel__name}
        </td>
        #{fillers}
      </tr>
      """
    table_html = """
    <table class="score_preview__table">
      <thead>
        <th class="scorecell--empty"></th>
        #{thead_html}
        <th class="scorecell--add"><button class="kobo-button kobo-button--small">+</button></th>
      </thead>
      <tbody>
        #{tbody_html.join('')}
      </tbody>
      <tfoot>
        <tr>
        <td class="scorerow--add"><button class="kobo-button kobo-button--small kobo-button--fullwidth">+</button></td>
        </tr>
      </tfoot>
    </table>
    """
    template = """
    <div class="score_preview">
      #{table_html}
    </div>
    """
    return template
  rankView = (s, template_args={})->
    rank_levels_lis = for item in template_args.rank_levels
      autoclass = ""
      autoattr = ""
      autoattr = """data-automatic-name="#{item.automatic}" """
      if item.set_automatic
        autoclass = "rank_items__name--automatic"
      """
      <li class="rank_items__level" data-cid="#{item.cid}">
        <span class="rank_items__level__label">#{item.label}</span><button class="rankcell__delete js-delete-rankcell">&times;</button>
        <br>
        <span class="rank_items__name #{autoclass}" #{autoattr}>#{item.name or ''}</span>
      </li>
      """
    rank_rows_lis = for item in template_args.rank_rows
      autoclass = ""
      autoattr = ""
      autoattr = """data-automatic-name="#{item.automatic}" """
      if item.set_automatic
        autoclass = "rank_items__name--automatic"
      """
      <li class="rank_items__item" data-cid="#{item.cid}">
        <span class="rank_items__item__label">#{item.label}</span><button class="rankcell__delete js-delete-rankcell">&times;</button>
        <br>
        <span class="rank_items__name #{autoclass}" #{autoattr}>#{item.name or ''}</span>
      </li>
      """
    rank_constraint_message_html = """
    <li class="rank_items__constraint_wrap">
      <p class="rank_items__constraint_explanation">
        #{t("A constraint message to be read in case of error:")}
      </p>
      <p class="rank_items__constraint_message">
        #{template_args.rank_constraint_msg}
      </p>
    </li>
    """

    rank_constraint_message_li = """
      #{rank_constraint_message_html}
    """
    template = """
    <div class="rank_preview clearfix">
      <ol class="rank__rows">
        #{rank_rows_lis.join('')}
        <li class="rank_items__add rank_items__add--item"><button class="kobo-button kobo-button--small kobo-button--fullwidth">+</button></li>
      </ol>
      <ul class="rank__levels">
        #{rank_levels_lis.join('')}
        <li class="rank_items__add rank_items__add--level"><button class="kobo-button kobo-button--small kobo-button--fullwidth">+</button></li>
        #{rank_constraint_message_li}
      </ul>
    </div>
    """
    return template

  # NOTE: Textbox value is empty, as we set it in some other place to avoid
  # problems with double quotes.
  mandatorySettingSelector = (uniqueName, currentValue, hideConditional = false, isConditional = false) ->
    # OC-28717: canonical values are 'yes' (Always) and '' (Never).
    # 'true'/'false' are the normalised-boolean stringifications that
    # getChangedValue() returns for forms whose required column was parsed
    # from an older XLSForm — treated as backward-compat aliases.
    # isConditional overrides the model value when the instance is in
    # Conditional mode: '' is ambiguous (Never vs. Conditional-no-expression),
    # so the caller passes its flag to force the Conditional radio.
    if isConditional
      modifier = 'custom'
    else if currentValue is 'yes' or currentValue is 'true'
      modifier = 'yes'
    else if currentValue is '' or currentValue is 'false'
      modifier = ''
    else
      modifier = 'custom'

    template = """
    <div class="card__settings__fields__field">
      <label>#{t('Required')}:</label>
      <span class="settings__input">
        <div class="radio">
          <label class="radio__row mandatory-setting__row mandatory-setting__row--yes">
            <input
              class="radio__input js-mandatory-setting-radio"
              type="radio"
              name="#{uniqueName}"
              value="yes" #{if modifier is 'yes' then 'checked' else ''}
            >
            <span class="radio__label">#{t('Always')}</span>
          </label>
          <label class="radio__row mandatory-setting__row mandatory-setting__row--never">
            <input
              class="radio__input js-mandatory-setting-radio"
              type="radio"
              name="#{uniqueName}"
              value="" #{if modifier is '' then 'checked' else ''}
            >
            <span class="radio__label">#{t('Never')}</span>
          </label>
          #{if hideConditional then '' else """
          <label class="radio__row mandatory-setting__row mandatory-setting__row--custom">
            <input
              class="radio__input js-mandatory-setting-radio"
              type="radio"
              name="#{uniqueName}"
              value="custom" #{if modifier is 'custom' then 'checked' else ''}
            >
            <span class="radio__label">#{t('Conditional')}</span>
          </label>
          """}
        </div>
      </span>
    </div>
    """
    return template

  requiredLogicPanel = () ->
    """
    <div class="required-logic-panel">
      #{logicPanelHeadHtml('required-logic-panel__header', t('Required Logic - when should this item be required?'))}
      <p class="required-logic-panel__status js-required-logic-status" aria-live="polite"></p>
      <label class="text-box text-box--on-white required-logic-panel__input-wrapper">
        <span class="logic-panel__label">#{t('Expression')}</span>
        <input
          type="text"
          class="text-box__input mandatory-setting-custom-text js-mandatory-setting-custom-text"
          value=""
          placeholder="#{t('No required condition yet — type one, or use the AI Assistant.')}"
        >
      </label>
      <p class="required-logic-panel__hint">#{t('This item is required when the expression is true and optional when it is false. To make it always or never required, change Required in Question Options instead.')}</p>
      #{xpathDocLinkHtml()}
    </div>
    """

  paramsSettingsField = ->
    template = """
    <div class="js-params-view card__settings__fields__field params-view__settings-wrapper">
      <label>#{t('Parameters')}:</label>
      <span class="settings__input">
        <div class="params-view"></div>
      </span>
    </div>
    """
    return template

  paramsSimple = ->
    template = """
    <div class="js-params-view params-view__simple-wrapper">
      <div class="params-view"></div>
    </div>
    """
    return template

  selectQuestionExpansion = ->
    template = """
    <div class="card--selectquestion__expansion row__multioptions js-cancel-sort">
      <div class="list-view">
        <ul></ul>
      </div>
    </div>
    """
    return template

  expandChoiceList = ()->
    template = """
    <span class="card__buttons__multioptions js-toggle-row-multioptions js-cancel-select-row"><i class='k-icon k-icon-caret-down' /></span>
    """
    return template

  rowErrorView = (atts)->
    template = """
    <div class="card card--error">
      #{t("Row could not be displayed:")} <pre>#{atts}</pre>
      <em>#{replaceSupportEmail(t("This question could not be imported. Please re-create it manually. Please contact us at help@kobotoolbox.org so we can fix this bug!"))}</em>
    </div>
    #{expandingSpacerHtml}
    """
    return template

  defaultValuePanel = (cid) ->
    """
    <div class="default-value-panel">
      #{logicPanelHeadHtml('default-value-panel__header', t('Default Value - what should this item start with?'))}
      <label class="logic-panel__label" for="#{cid}-default-value">#{t('Expression')}</label>
      <textarea
        id="#{cid}-default-value"
        class="default-value-panel__input js-default-value-input"
        placeholder="#{t('No default value yet — type one, or use the AI Assistant.')}"
      ></textarea>
      <div class="default-value-panel__hint">
        <p>#{t('A Default Value fills in this item automatically when the form is started. For an item in a repeating group, it also fills in the item in each new repeat when that repeat is added.')}</p>
        <p>#{t('The Default Value is applied only once. If a user changes the value or blanks it out, the Default Value is not filled in again, even after the form is closed and reopened. It is applied again only if the whole form is cleared in Study Runner and started again. To keep a value in step with other items, use a Calculation instead.')}</p>
        <p>#{t('The Default Value can be:')}</p>
        <ul>
          <li>#{t("A constant value like")} <code>1</code> #{t("or")} <code>'text'</code></li>
          <li>#{t("An XLSForm expression like")} <code>today()</code> #{t("to fill in today's date")}</li>
        </ul>
        <p>#{t('An item with a Default Value is shown when the form is started, even if its Relevant Logic is false.')}</p>
      </div>
      #{xpathDocLinkHtml()}
    </div>
    """

  calculationPanel = (cid) ->
    """
    <div class="calculation-panel">
      #{logicPanelHeadHtml('calculation-panel__header', t("Calculation - how should this item's value be calculated?"))}
      <div class="calculation-panel__field">
        <label class="logic-panel__label" for="#{cid}-calculation">#{t('Expression')}</label>
        <textarea
          id="#{cid}-calculation"
          class="calculation-panel__textarea js-calculation-input"
          placeholder="#{t('No calculation yet — type one, or use the AI Assistant.')}"
        ></textarea>
      </div>
      <div class="logic-panel__help">
        <p>#{t("This item's value is set by the expression. Unless a trigger item is selected below, it is recalculated whenever data in the form changes and every time the form is opened for editing. That keeps it current with the items it refers to, including data from other forms and time-based values such as")} <code>now()</code>.</p>
        <p>#{t('If this item is a question users see on the form (any type other than Calculate), select')} <strong>#{t('Read only')}</strong> #{t('on the')} <strong>#{t('Question Options')}</strong> #{t('tab, or select a trigger item below. Otherwise the calculation will overwrite anything a user enters. To fill in a starting value only once, use a Default Value instead.')}</p>
      </div>
      <div class="calculation-panel__field">
        <label class="logic-panel__label">#{t('Triggered by')}</label>
        <select class="calculation-panel__select js-calculation-trigger-select">
        </select>
        <p class="calculation-panel__hint">#{t("To control when the value is calculated, select a trigger item. The calculation then runs only when that item's value changes. It does not run when other data changes or when the form is reopened. This lets the calculated value act as a starting point that users can edit. Their edit is overwritten only if the trigger item's value changes.")}</p>
      </div>
      #{xpathDocLinkHtml()}
    </div>
    """

  return {
    xlfRowView: xlfRowView
    unsupportedRowView: unsupportedRowView
    expandChoiceList: expandChoiceList
    mandatorySettingSelector: mandatorySettingSelector
    requiredLogicPanel: requiredLogicPanel
    paramsSettingsField: paramsSettingsField
    paramsSimple: paramsSimple
    selectQuestionExpansion: selectQuestionExpansion
    groupView: groupView
    rowErrorView: rowErrorView
    leadingSpacerHtml: leadingSpacerHtml
    emptyGroupSpacerHtml: emptyGroupSpacerHtml
    calculationPanel: calculationPanel
    koboMatrixView: koboMatrixView
    scoreView: scoreView
    rankView: rankView
    groupSettingsView: groupSettingsView
    rowSettingsView: rowSettingsView
    defaultValuePanel: defaultValuePanel
    iconTooltip: iconTooltip
    lockedFeatures: lockedFeatures
    xpathDocLinkHtml: xpathDocLinkHtml
    logicPanelHeadHtml: logicPanelHeadHtml
  }
