import React from 'react'

import alertify from 'alertifyjs'
import ReactTable from 'react-table'
import TextareaAutosize from 'react-textarea-autosize'
import { actions } from '#/actions'
import { invalidateItem } from '#/api/mutation-defaults/common'
import { getAssetsRetrieveQueryKey } from '#/api/react-query/manage-projects-and-library-content'
import bem from '#/bem'
import Button from '#/components/common/button'
import LoadingSpinner from '#/components/common/loadingSpinner'
import { ECONSENT_SIGNATURE_EXTERNAL_VALUE } from '#/components/formBuilder/econsentSignature'
import { LockingRestrictionName } from '#/components/locking/lockingConstants'
import { hasRowRestriction } from '#/components/locking/lockingUtils'
import { GROUP_TYPES_BEGIN, MODAL_TYPES, QUESTION_TYPES } from '#/constants'
import pageState from '#/pageState.store'
import { stores } from '#/stores'
import { recordKeys } from '#/utils'

const SAVE_BUTTON_TEXT = {
  DEFAULT: t('Save translations'),
  UNSAVED: t('* Save translations'),
  PENDING: t('Saving…'),
}

const ELEMENT_TYPE_LABELS = {
  hint: t('Hint'),
  constraint_message: t('Constraint message'),
  required_message: t('Required message'),
  guidance_hint: t('Guidance hint'),
  'media::image': t('Image'),
  'media::audio': t('Audio'),
  'media::video': t('Video'),
}

// Derives a human-readable "Element" column label (e.g. "Group label",
// "Question label", "Choice label", "Hint") from the translatable property
// name and, for survey rows, the row's type. Falls back to a humanized
// version of the property name for any translatable column pyxform may
// produce that isn't explicitly mapped above.
function getElementTypeLabel(contentProp, itemProp, rowType) {
  if (contentProp === 'choices') {
    return t('Choice label')
  }
  if (itemProp === 'label') {
    return rowType && GROUP_TYPES_BEGIN[rowType] ? t('Group label') : t('Question label')
  }
  if (ELEMENT_TYPE_LABELS[itemProp]) {
    return ELEMENT_TYPE_LABELS[itemProp]
  }
  return itemProp
    .replace(/^media::/, '')
    .replace(/_/g, ' ')
    .replace(/^\w/, (c) => c.toUpperCase())
}

export class TranslationTable extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      saveChangesButtonText: SAVE_BUTTON_TEXT.DEFAULT,
      isSaveChangesButtonPending: false,
      tableData: [],
    }
    stores.translations.setTranslationTableUnsaved(false)
    const { translated, survey, choices, translations } = props.asset.content
    const langIndex = props.langIndex
    const lockedChoiceLists = []

    // add each translatable property for survey items to translation table
    survey.forEach((row) => {
      let isLabelLocked = false
      if (row?.label) {
        isLabelLocked = this.isRowLabelLocked(row.type, row.name)
      }

      // choices don't know what questions use them so we keep track of the
      // choice lists here to know if a question that uses them has
      // `choice_label_edit` enabled
      if (this.isChoiceLabelLocked(row.name) && row.select_from_list_name) {
        lockedChoiceLists.push(row.select_from_list_name)
      }

      translated.forEach((property) => {
        // OC-28719: required_message isn't supported on eConsent signature
        // items (see UNSUPPORTED_ECONSENT_SIGNATURE_FIELDS in
        // formBuilderUtils.ts). Without this check, a translated
        // required_message left over on a signature row from before that
        // discard existed still surfaces as an editable "Required message"
        // row here, letting a user set values the save step immediately
        // strips.
        if (property === 'required_message' && row['bind::oc:external'] === ECONSENT_SIGNATURE_EXTERNAL_VALUE) {
          return
        }
        if (row[property] && row[property][0]) {
          this.state.tableData.push({
            original: row[property][0],
            value: row[property][langIndex],
            name: row.name || row.$autoname,
            itemProp: property,
            contentProp: 'survey',
            elementType: getElementTypeLabel('survey', property, row.type),
            isLabelLocked: isLabelLocked,
          })
        }
      })
    })

    // add choice options to translation table
    if (choices && choices.length) {
      choices.forEach((choice) => {
        const isLabelLocked = lockedChoiceLists.includes(choice.list_name)
        if (choice.label && choice.label[0]) {
          this.state.tableData.push({
            original: choice.label[0],
            value: choice.label[langIndex],
            name: choice.name || choice.$autovalue,
            listName: choice.list_name,
            itemProp: 'label',
            contentProp: 'choices',
            elementType: getElementTypeLabel('choices', 'label'),
            isLabelLocked: isLabelLocked,
          })
        }
      })
    }

    this.columns = [
      {
        Header: t('Element'),
        accessor: 'elementType',
        width: 150,
      },
      {
        Header: t('Original string'),
        accessor: 'original',
        width: 353,
        Cell: (cellInfo) => (
          // Disabling has no effect on this cell, but we do it to gray out the
          // text to indicate that the label is locked
          // TODO: Figure out what to do for the case of adding a new language
          // when there are locked labels. These labels should be unlocked
          // for the newly added languages and their translations only.
          // See: https://github.com/kobotoolbox/kpi/issues/3920
          <div className={cellInfo.original.isLabelLocked ? 'rt-td--disabled' : ''}>{cellInfo.original.original}</div>
        ),
      },
      {
        Header: translations[langIndex],
        accessor: 'translation',
        className: 'translation',
        Cell: (cellInfo) => (
          <TextareaAutosize
            onChange={(e) => {
              const data = [...this.state.tableData]
              data[cellInfo.index].value = e.target.value
              this.setState({ data })
              this.markFormUnsaved()
            }}
            value={this.state.tableData[cellInfo.index].value || ''}
            disabled={cellInfo.original.isLabelLocked}
            dir='auto'
          />
        ),
      },
    ]
  }

  markFormUnsaved() {
    this.setState({
      saveChangesButtonText: SAVE_BUTTON_TEXT.UNSAVED,
      isSaveChangesButtonPending: false,
    })
    stores.translations.setTranslationTableUnsaved(true)
  }

  markFormPending() {
    this.setState({
      saveChangesButtonText: SAVE_BUTTON_TEXT.PENDING,
      isSaveChangesButtonPending: true,
    })
    stores.translations.setTranslationTableUnsaved(true)
  }

  markFormIdle() {
    this.setState({
      saveChangesButtonText: SAVE_BUTTON_TEXT.DEFAULT,
      isSaveChangesButtonPending: false,
    })
    stores.translations.setTranslationTableUnsaved(false)
  }

  saveChanges() {
    const content = this.props.asset.content,
      rows = this.state.tableData,
      langIndex = this.props.langIndex
    for (var i = 0, len = rows.length; i < len; i++) {
      const item = content[rows[i].contentProp].find(
        (o) =>
          (o.name === rows[i].name || o.$autoname === rows[i].name || o.$autovalue === rows[i].name) &&
          o.list_name === rows[i].listName,
      )
      const itemProp = rows[i].itemProp

      if (item[itemProp][langIndex] !== rows[i].value) {
        item[itemProp][langIndex] = rows[i].value
      }
    }

    this.markFormPending()
    actions.resources.updateAsset(
      this.props.asset.uid,
      {
        content: JSON.stringify(content),
      },
      {
        onComplete: () => {
          this.markFormIdle()
          // Keep the React Query asset cache in sync so Form Designer's live
          // preview/save reads the freshly-saved translations.
          invalidateItem(getAssetsRetrieveQueryKey(this.props.asset.uid))
        },
        onFailed: this.markFormUnsaved.bind(this),
      },
    )
  }

  onBack() {
    if (stores.translations.state.isTranslationTableUnsaved) {
      const dialog = alertify.dialog('confirm')
      const opts = {
        title: t('Go back?'),
        message: t('You will lose all unsaved changes.'),
        labels: { ok: t('Confirm'), cancel: t('Cancel') },
        onok: this.showManageLanguagesModal.bind(this),
        oncancel: dialog.destroy,
      }
      dialog.set(opts).show()
    } else {
      this.showManageLanguagesModal()
    }
  }

  showManageLanguagesModal() {
    pageState.switchModal({
      type: MODAL_TYPES.FORM_LANGUAGES,
      asset: this.props.asset,
    })
  }

  // Compare current row type agaisnt those with lockable labels and return if
  // the relevant label restriction applies
  isRowLabelLocked(rowType, rowName) {
    if (rowType === GROUP_TYPES_BEGIN.begin_group) {
      return hasRowRestriction(this.props.asset.content, rowName, LockingRestrictionName.group_label_edit)
    } else if (recordKeys(QUESTION_TYPES).includes(rowType)) {
      return hasRowRestriction(this.props.asset.content, rowName, LockingRestrictionName.question_label_edit)
    } else {
      return false
    }
  }

  isChoiceLabelLocked(rowName) {
    return hasRowRestriction(this.props.asset.content, rowName, LockingRestrictionName.choice_label_edit)
  }

  render() {
    return (
      <bem.FormModal m='translation-table'>
        <div className='translation-table-container'>
          <ReactTable
            data={this.state.tableData}
            columns={this.columns}
            defaultPageSize={30}
            showPageSizeOptions={false}
            previousText={t('Prev')}
            nextText={t('Next')}
            minRows={1}
            loadingText={<LoadingSpinner />}
            // Enables RTL support in table cells
            getTdProps={() => {
              return { dir: 'auto' }
            }}
          />
        </div>

        <bem.Modal__footer m='translation-table'>
          <Button
            type='primary'
            size='l'
            onClick={this.saveChanges.bind(this)}
            isDisabled={this.state.isSaveChangesButtonPending}
            label={this.state.saveChangesButtonText}
          />

          <Button type='secondary' size='l' onClick={this.onBack.bind(this)} label={t('Cancel')} />

          <span className='translation-table-footer__help'>
            {t('Saving adds the translations to the form definition.')}
          </span>
        </bem.Modal__footer>
      </bem.FormModal>
    )
  }
}

export default TranslationTable
