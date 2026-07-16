module.exports = do ->

  addOptionButton = () ->
      template = """<div class="card__addoptions js-card-add-options">
          <div class="card__addoptions__layer"></div>
            <ul><li class="multioptions__option  xlf-option-view xlf-option-view--depr">
              <div><div tabIndex="0" class="editable-wrapper"><span class="editable editable-click">+ #{t("click to add another response...")}</span></div><code><label>#{t("Value:")}</label> <span>#{t("AUTOMATIC")}</span></code><code><label>#{t("Image:")}</label> <span>#{t("None")}</span></code></div>
            </li></ul>
        </div>"""
      return template

  return addOptionButton: addOptionButton

