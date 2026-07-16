_ = require 'underscore'
Validator = require './view.utils.validator'

module.exports = do ->
  viewUtils = {}
  viewUtils.Validator = Validator

  # replaces characters that jQuery can't handle in event name
  viewUtils.normalizeEventName = (eventName) ->
    regex = new RegExp('[: ()]', 'g')
    eventName = eventName.replace(regex, '-');
    return eventName

  viewUtils.makeEditable = (that, model, selector, {property, transformFunction, options, edit_callback}) ->
    if !(selector instanceof jQuery)
      origSelector = selector
      selector =that.$el.find(selector)

    if selector.length is 0
      console?.error("makeEditable called on nonexistent element:", origSelector)

    if selector.data('madeEditable')
      console?.error "makeEditable called 2x on the same element: ", selector
    selector.data('madeEditable', true)

    if !transformFunction?
      transformFunction = (value) -> value
    if !property?
      property = 'value'

    if !edit_callback?
      edit_callback = _.bind (ent) ->
          ent = transformFunction ent
          ent = ent.replace(/\t/g, ' ')
          model.set(property, ent, validate: true)
          if(model.validationError && model.validationError[property])
            return model.validationError[property]

          newValue: ent
        , that


    selector.on 'shown', (e, obj) -> obj.input.$input.on 'paste', (e) -> e.stopPropagation()


    enable_edit = () ->
      parent_element = selector.parent()
      parent_element.find('.error-message').remove()
      current_value = selector.text().replace new RegExp(String.fromCharCode(160), 'g'), ''
      edit_box = $('<input />', type:'text', value: current_value, class:'js-cancel-sort js-blur-on-select-row')
      selector.after edit_box
      selector.hide()
      edit_box.select()

      commit_edit = (source) ->
        parent_element.find('.error-message').remove()
        
        if source.type is 'blur' or source.which is 13
          edit_box.remove()
          selector.show()
          return

        if options? && options.validate? && options.validate(edit_box.val())?
          new_value = options.validate(edit_box.val())
        else
          new_value = edit_callback edit_box.val()

        if !new_value?
          new_value = newValue: edit_box.val()

        if new_value.newValue?
          displayValue = _.escape(new_value.newValue) 
          selector.html(displayValue)
          edit_box.val(displayValue)
        else
          error_box = $('<div class="error-message">' + new_value + '</div>')
          parent_element.append(error_box)

      edit_box.blur commit_edit
      edit_box.keyup (event) ->
        if event.which == 13
          commit_edit event
        else
          commit_edit event


    selector.on 'click', enable_edit


  # DEAD CODE TODO: Doesn't seem to be used anywhere?
  viewUtils.reorderElemsByData = (selector, parent, dataAttribute)->
    arr = []
    parentEl = false
    $(parent).find(selector).each (i)->
      if i is 0
        parentEl = @parentElement
      else if @parentElement isnt parentEl
        throw new Error("All reordered items must be siblings")

      $el = $(@).detach()
      val = $el.data(dataAttribute)
      arr[val] = $el  if _.isNumber(val)
      return
    $el.appendTo(parentEl)  for $el in arr when $el
    return

  viewUtils.cleanStringify = (atts)->
    attArr = []
    for key, val of atts when val isnt ""
      attArr.push """<span class="atts"><i>#{key}</i>="<em>#{val}</em>"</span>"""
    return attArr.join("&nbsp;")

  # DEAD CODE TODO: unused?
  viewUtils.debugFrame = do ->
    $div = false
    debugFrameStyle =
      position: "fixed"
      width: "95%"
      height: "80%"
      bottom: 10
      left: "2.5%"
      overflow: "auto"
      zIndex: 100
      backgroundColor: "rgba(255,255,255,0.7)"

    showFn = (txt)->
      html = txt.split("\n").join("<br>")
      $div = $("<div>", class: "well debug-frame").html("<code>#{html}</code>")
        .css(debugFrameStyle)
        .appendTo("body")
      return
    showFn.close = ->
      if $div
        $div.remove()
        $div = false
        return
    return showFn

  # DEAD CODE TODO: unused?
  viewUtils.launchQuestionLibrary = do ->
    launch = (opts={})->
      wrap = $("<div>", class: "js-click-remove-iframe iframe-bg-shade")
      $("<div>").text("""
        Launch question library in this element
        <section koboform-question-library=""></section>
      """).appendTo(wrap)
      wrap.click ()-> wrap.remove()
      return wrap

    return launch

  # DEAD CODE TODO: unused?
  viewUtils.enketoIframe = do ->
    enketoServer = "https://enketo.org"
    enketoPreviewUri = "/webform/preview"
    buildUrl = (previewUrl)->
      return """#{enketoServer}#{enketoPreviewUri}?form=#{previewUrl}"""

    _loadConfigs = (options)->
      if options.enketoPreviewUri
        enketoPreviewUri = options.enketoPreviewUri
      if options.enketoServer
        enketoServer = options.enketoServer
      return

    clickCloserBackground = ->
      return $("<div>", class: "js-click-remove-iframe")

    launch = (previewUrl, options={})->
      _loadConfigs(options)
      $(".enketo-holder").append $("<iframe>", src: buildUrl(previewUrl))
      return $(".enketo-holder iframe").load ()->
        # alert "iframe loaded yo!"
        return $(".enketo-loading-message").remove()

    launch.close = ()->
      $(".iframe-bg-shade").remove()
      return $(".enketo-holder").remove()

    # DEAD CODE TODO: unused?
    launch.fromCsv = (surveyCsv, options={})->
      # Probably dead code? Can't find it being called anywhere, and the
      # endpoint it uses doesn't exist anymore. -jnm 20230207
      holder = $("<div>", class: "enketo-holder").html("""
        <div class='enketo-iframe-icon'></div>
        <div class="enketo-loading-message">
          <p>
          <i class="k-spin k-icon k-icon-spinner"></i>
          <br/>
          Loading Preview
        </p>
        <p>
          This will take a few seconds depending on the size of your form.
        </p>
        </div>
      """)
      wrap = $("<div>", class: "js-click-remove-iframe iframe-bg-shade")
      holder.appendTo('body')
      wrap.appendTo('body')

      wrap.click ()->
        wrap.remove()
        return holder.remove()

      $('.enketo-holder .enketo-iframe-icon').click ()->
        wrap.remove()
        return holder.remove()

      previewServer = options.previewServer or ""
      data = JSON.stringify(body: surveyCsv)
      _loadConfigs(options)
      onError = options.onError or (args...)-> console?.error.apply(console, args)

      $.ajax
        url: "#{previewServer}/koboform/survey_preview/"
        method: "POST"
        data: data
        complete: (jqhr, status)=>
          response = jqhr.responseJSON
          if status is "success" and response and response.unique_string
            unique_string = response.unique_string
            launch("#{previewServer}/koboform/survey_preview/#{unique_string}")
            return options.onSuccess()  if options.onSuccess?
          else if status isnt "success"
            wrap.remove()
            holder.remove()
            informative_message = jqhr.responseText or jqhr.statusText
            if informative_message.split("\n").length > 0
              return informative_message = informative_message.split("\n")[0..2].join("<br>")
            return onError informative_message, title: 'Error launching preview'
          else if response and response.error
            wrap.remove()
            holder.remove()
            return onError response.error
          else
            wrap.remove()
            holder.remove()
            return onError "SurveyPreview response JSON is not recognized"
      return

    return launch

  return viewUtils
