# coding: utf-8
# 😬
import copy
import sys
from collections import OrderedDict
from io import BytesIO

import six
import xlsxwriter

from formpack.utils.kobo_locking import (
    revert_kobo_lock_structure,
)

CUSTOM_COL_APPEND_STRING = 'custom_col_append_string'


class XlsExportableMixin:

    surveyCols = [
        u'type',
        u'name',
        u'label',
        u'bind::oc:itemgroup',
        u'hint',
        u'appearance',
        u'bind::oc:briefdescription',
        u'bind::oc:description',
        u'relevant',
        u'required',
        u'required_message',
        u'constraint',
        u'constraint_message',
        u'default',
        u'calculation',
        u'trigger',
        u'readonly',
        u'image',
        u'repeat_count',
        u'bind::oc:external',
        u'instance::oc:contactdata',
        u'instance::oc:identifier'
    ]

    choicesCols = [
        u'list_name',
        u'label',
        u'name',
        u'image'
    ]

    def ordered_xlsform_content(self, kobo_specific_types=False, append=None):
        # currently, this method depends on "FormpackXLSFormUtilsMixin"
        content = copy.deepcopy(self.content)
        if append:
            self._append(content, **append)
        self._survey_prepare_custom_col_value(content)
        self._adjust_content_media_column_before_standardize(content)
        self._standardize(content)
        self._adjust_content_media_column(content)
        self._survey_revert_custom_col_value(content)
        if not kobo_specific_types:
            self._expand_kobo_qs(content)
            self._autoname(content)
            self._populate_fields_with_autofields(content)
            self._strip_dollar_fields(content)
            revert_kobo_lock_structure(content)
        content = OrderedDict(content)
        self._survey_column_oc_adjustments(content)
        self._settings_ensure_form_id(content)
        self._settings_ensure_required_columns(content)
        self._settings_maintain_key_order(content)
        self._choices_column_oc_adjustments(content)
        self._xlsform_structure(
            content, ordered=True, kobo_specific=kobo_specific_types
        )
        self._survey_maintain_key_order(content)
        self._choices_maintain_key_order(content)
        return content
    
    def _survey_prepare_custom_col_value(self, content):
        survey = content.get('survey', [])
        for survey_col_idx in range(len(survey)):
            survey_col = survey[survey_col_idx]
            if 'required' in survey_col:
                if survey_col['required'] == True:
                    survey_col['required'] = 'yes+{}'.format(CUSTOM_COL_APPEND_STRING)
                elif survey_col['required'] == False:
                    survey_col['required'] = '+{}'.format(CUSTOM_COL_APPEND_STRING)
            if 'readonly' in survey_col:
                if survey_col['readonly'] == 'true':
                    survey_col['oc_readonly'] = 'yes+{}'.format(CUSTOM_COL_APPEND_STRING)
                elif survey_col['readonly'] == 'false':
                    survey_col['oc_readonly'] = '+{}'.format(CUSTOM_COL_APPEND_STRING)
                del survey_col['readonly']
    
    def _survey_revert_custom_col_value(self, content):
        survey = content.get('survey', [])
        for survey_col_idx in range(len(survey)):
            survey_col = survey[survey_col_idx]
            if 'required' in survey_col:
                if CUSTOM_COL_APPEND_STRING in survey_col['required']:
                    req_col_append_string_pos = survey_col['required'].find(CUSTOM_COL_APPEND_STRING)
                    survey_col['required'] = survey_col['required'][:req_col_append_string_pos - 1]
            if 'oc_readonly' in survey_col:
                if CUSTOM_COL_APPEND_STRING in survey_col['oc_readonly']:
                    req_col_append_string_pos = survey_col['oc_readonly'].find(CUSTOM_COL_APPEND_STRING)
                    survey_col['readonly'] = survey_col['oc_readonly'][:req_col_append_string_pos - 1]
                del survey_col['oc_readonly']

    def _survey_column_oc_adjustments(self, content):
        survey = content.get('survey', [])

        if len(survey) > 0:
            for survey_col_idx in range(len(survey)):
                survey_col = survey[survey_col_idx]
                
                for surveyCol in self.surveyCols:
                    if surveyCol not in survey_col:
                        if 'translated' in content.keys() and surveyCol in content['translated']:
                            survey_col[surveyCol] = [u''] * len(content['translations'])
                        else:
                            survey_col[surveyCol] = u''

                if '$given_name' in survey_col:
                    del survey_col['$given_name']

                if 'type' in survey_col:
                    if survey_col['type'] == 'begin_group':
                        survey_col['type'] = 'begin group'
                    elif survey_col['type'] == 'end_group':
                        survey_col['type'] = 'end group'
                    elif survey_col['type'] == 'begin_repeat':
                        survey_col['type'] = 'begin repeat'
                    elif survey_col['type'] == 'end_repeat':
                        survey_col['type'] = 'end repeat'
                    elif survey_col['type'] == 'select_one_from_file':
                        select_one_filename = 'codelist.csv'
                        if 'select_one_from_file_filename' in survey_col and survey_col['select_one_from_file_filename'].strip() != '':
                            select_one_filename = survey_col['select_one_from_file_filename']
                        survey_col['type'] = 'select_one_from_file' + ' ' + select_one_filename

                if 'select_one_from_file_filename' in survey_col:
                    del survey_col['select_one_from_file_filename']
        else:
            cols = OrderedDict()
            for surveyCol in self.surveyCols:
                if 'translated' in content.keys() and surveyCol in content['translated']:
                    cols[surveyCol] = [u''] * len(content['translations'])
                else:
                    cols[surveyCol] = u''
            content['survey'].append(cols)

    def _survey_maintain_key_order(self, content):
        if 'survey' in content:
            survey = content['survey']
            
            # Maintains key order of survey sheet
            surveyKeyOrder = self.surveyCols
            
            for idx, col in enumerate(survey):
                surveyRemainingKeyOrder = []
                for surveyKey in col.keys():
                    if surveyKey not in surveyKeyOrder:
                        surveyRemainingKeyOrder.append(surveyKey)
                surveyKeyOrder = surveyKeyOrder + surveyRemainingKeyOrder

                content['survey'][idx] = OrderedDict(sorted(col.items(), key=lambda i:surveyKeyOrder.index(i[0])))

    def _settings_ensure_form_id(self, content):
        # Show form_id and remove id_string in downloaded xls
        if 'settings' in content:
            settings = content['settings']
            
            # Remove id_string from settings sheet
            if 'id_string' in settings:
                settings['form_id'] = settings['id_string']
                del settings['id_string']

    def _settings_ensure_required_columns(self, content):
        if 'settings' in content:
            settings = content['settings']

            try:
                form_title = self.name
            except Exception as e:
                form_title = "Form Title"

            settings.update(
                {
                    'form_title': form_title,
                    'crossform_references': '',
                    'namespaces': 'oc="http://openclinica.org/xforms" , OpenClinica="http://openclinica.com/odm"',
                    'Read Me - Form template created by OpenClinica Form Designer': ''
                }
            )

    def _settings_maintain_key_order(self, content):
        if 'settings' in content:
            settings = content['settings']
            
            # Maintains key order of settings sheet
            settingsKeyOrder = [
                'form_title',
                'form_id',
                'version', 
                'style',
                'crossform_references',
                'namespaces', 
                'Read Me - Form template created by OpenClinica Form Designer'
            ]
            settingsRemainingKeyOrder = []
            for settingsKey in settings.keys():
                if settingsKey not in settingsKeyOrder:
                    settingsRemainingKeyOrder.append(settingsKey)

            settingsKeyOrder = settingsKeyOrder + settingsRemainingKeyOrder
            content['settings'] = OrderedDict(sorted(settings.items(), key=lambda i:settingsKeyOrder.index(i[0])))

    def _choices_column_oc_adjustments(self, content):
        choices = content.get('choices', [])

        if len(choices) > 0:
            for choices_col_idx in range(len(choices)):
                choices_col = choices[choices_col_idx]

                for choicesCol in self.choicesCols:
                    if choicesCol not in choices_col:
                        if 'translated' in content.keys() and choicesCol in content['translated']:
                            choices_col[choicesCol] = [u''] * len(content['translations'])
                        else:
                            choices_col[choicesCol] = u''
        else:
            cols = OrderedDict()
            for choicesCol in self.choicesCols:
                if 'translated' in content.keys() and choicesCol in content['translated']:
                    cols[choicesCol] = [u''] * len(content['translations'])
                else:
                    cols[choicesCol] = u''
            content[u'choices'] = []
            content[u'choices'].append(cols)

    def _choices_maintain_key_order(self, content):
        if 'choices' in content:
            choices = content['choices']
            
            # Maintains key order of choices sheet
            choiceKeyOrder = self.choicesCols
            
            for idx, choice in enumerate(choices):
                choiceRemainingKeyOrder = []
                for choiceKey in choice.keys():
                    if choiceKey not in choiceKeyOrder:
                        choiceRemainingKeyOrder.append(choiceKey)
                choiceKeyOrder = choiceKeyOrder + choiceRemainingKeyOrder

                content['choices'][idx] = OrderedDict(sorted(choice.items(), key=lambda i:choiceKeyOrder.index(i[0])))

    def to_xlsx_io(self, versioned=False, **kwargs):
        """
        To append rows to one or more sheets, pass `append` as a
        dictionary of lists of dictionaries in the following format:
            `{'sheet name': [{'column name': 'cell value'}]}`
        Extra settings may be included as a dictionary in the same
        parameter.
            `{'settings': {'setting name': 'setting value'}}`
        """
        if versioned:
            append = kwargs.setdefault('append', {})
            # Append the __version__ calculate row to the survey. It will be
            # the last survey row after existing rows and any append rows.
            append.setdefault('survey', []).append({
                'name': '__version__',
                'calculation': "'{}'".format(self.version_id),
                'type': 'calculate',
            })
            # Preserve existing append settings; `version` is added to the
            # settings dict AFTER ordered_xlsform_content() runs so it appears
            # as the last column (bypassing _settings_maintain_key_order).
            append_settings = OrderedDict(append.setdefault('settings', {}))
            append_settings['form_title'] = self.name
            kwargs['append']['settings'] = append_settings
        try:
            def _add_contents_to_sheet(sheet, contents):
                cols = []
                for row in contents:
                    for key in row.keys():
                        if key not in cols:
                            cols.append(key)
                for ci, col in enumerate(cols):
                    sheet.write(0, ci, col)
                for ri, row in enumerate(contents):
                    for ci, col in enumerate(cols):
                        val = row.get(col, None)
                        if val:
                            sheet.write(ri + 1, ci, val)

            # The extra rows and settings should persist within this function
            # and its return value *only*. Calling deepcopy() is required to
            # achieve this isolation.
            ss_dict = self.ordered_xlsform_content(**kwargs)
            # Add `version` to settings after _settings_maintain_key_order
            # runs inside ordered_xlsform_content, so it appears last.
            if versioned and ss_dict.get('settings'):
                ss_dict['settings'][0]['version'] = self.version_number_and_date
            ordered_ss_dict = OrderedDict()
            for t in ['settings', 'choices', 'survey']:
                if t in ss_dict:
                    ordered_ss_dict[t] = ss_dict[t]
            output = BytesIO()
            with xlsxwriter.Workbook(output) as workbook:
                for sheet_name, contents in ordered_ss_dict.items():
                    cur_sheet = workbook.add_worksheet(sheet_name)
                    _add_contents_to_sheet(cur_sheet, contents)
        except Exception as e:
            six.reraise(
                type(e),
                type(e)(
                    "asset.content improperly formatted for XLS "
                    "export: %s" % repr(e)
                ),
                sys.exc_info()[2],
            )

        output.seek(0)
        return output
