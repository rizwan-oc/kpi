import React from 'react';
import ReactDOM from 'react-dom';
import autoBind from 'react-autobind';
import $ from 'jquery';
import Select from 'react-select';
import _ from 'underscore';
import DocumentTitle from 'react-document-title';
import Checkbox from '../components/checkbox';
import TextBox from '../components/textBox';
import SurveyScope from '../models/surveyScope';
import cascadeMixin from './cascadeMixin';
import AssetNavigator from './assetNavigator';
import {hashHistory} from 'react-router';
import alertify from 'alertifyjs';
import ProjectSettings from '../components/modalForms/projectSettings';
import {
  surveyToValidJson,
  unnullifyTranslations,
  assign,
  t,
  koboMatrixParser
} from '../utils';
import {
  ASSET_TYPES,
  AVAILABLE_FORM_STYLES,
  PROJECT_SETTINGS_CONTEXTS,
  update_states,
} from '../constants';
import ui from '../ui';
import bem from '../bem';
import stores from '../stores';
import actions from '../actions';
import dkobo_xlform from '../../xlform/src/_xlform.init';
import {dataInterface} from '../dataInterface';

const ErrorMessage = bem.create('error-message');
const ErrorMessage__strong = bem.create('error-message__header', '<strong>');

var formDesignerSupportUrl = 'https://docs.openclinica.com/oc4/design-study/form-designer';

const UNSAVED_CHANGES_WARNING = t('You have unsaved changes. Leave form without saving?');

class FormSettingsEditor extends React.Component {
  constructor(props) {
    super(props);
    autoBind(this);
  }

  render () {
    return (
      <bem.FormBuilderMeta>
        <bem.FormBuilderMeta__column>
          {this.props.meta.map((mtype) => {
            if (!mtype.key) {
              mtype.key = `meta-${mtype.name}`;
            }
            return (
              <Checkbox
                key={mtype.key}
                label={mtype.label}
                checked={mtype.value}
                onChange={this.props.onCheckboxChange.bind(this, mtype.name)}
              />
            );
          })}
        </bem.FormBuilderMeta__column>
        <bem.FormBuilderMeta__column>
          {this.props.phoneMeta.map((mtype) => {
            if (!mtype.key) {
              mtype.key = `meta-${mtype.name}`;
            }
            return (
              <Checkbox
                key={mtype.key}
                label={mtype.label}
                checked={mtype.value}
                onChange={this.props.onCheckboxChange.bind(this, mtype.name)}
              />
            );
          })}
        </bem.FormBuilderMeta__column>
      </bem.FormBuilderMeta>
    );
  }
  focusSelect () {
    this.refs.webformStyle.focus();
  }
}

class FormSettingsBox extends React.Component {
  constructor(props) {
    super(props);
    var formId = this.props.survey.settings.get('form_id');
    this.state = {
      xform_id_string: formId,
      meta: [],
      phoneMeta: []
    };
    this.META_PROPERTIES = ['start', 'end', 'today', 'deviceid'];
    this.PHONE_META_PROPERTIES = ['username', 'simserial', 'subscriberid', 'phonenumber'];
    autoBind(this);
  }

  componentDidMount() {
    this.updateState();
  }

  updateState(newState = {}) {
    this.META_PROPERTIES.forEach(this.passValueIntoObj('meta', newState));
    this.PHONE_META_PROPERTIES.map(this.passValueIntoObj('phoneMeta', newState));
    this.setState(newState);
  }

  getSurveyDetail(sdId) {
    return this.props.survey.surveyDetails.filter(function(sd){
      return sd.attributes.name === sdId;
    })[0];
  }

  passValueIntoObj(category, newState) {
    newState[category] = [];
    return (id) => {
      var sd = this.getSurveyDetail(id);
      if (sd) {
        newState[category].push(assign({}, sd.attributes));
      }
    };
  }

  onCheckboxChange(name, isChecked) {
    this.getSurveyDetail(name).set('value', isChecked);
    this.updateState();
    if (typeof this.props.onChange === 'function') {
      this.props.onChange();
    }
  }

  onFieldChange(evt) {
    const fieldId = evt.target.id;
    const value = evt.target.value;

    if (fieldId === 'form_id') {
      this.props.survey.settings.set('form_id', value);
    }

    this.setState({
      xform_id_string: this.props.survey.settings.get('form_id')
    });
  }

  render() {
    return (
      <FormSettingsEditor {...this.state} onCheckboxChange={this.onCheckboxChange.bind(this)} />
    );
  }
}

const ASIDE_CACHE_NAME = 'kpi.editable-form.aside';
const FORM_STYLE_CACHE_NAME = 'kpi.editable-form.form-style';

export default assign({
  componentDidMount() {
    this.props.router.setRouteLeaveHook(this.props.route, this.routerWillLeave);

    document.body.classList.add('hide-edge');

    this.loadAsideSettings();

    if (this.state.editorState === 'existing') {
      let uid = this.props.params.assetid;
      stores.allAssets.whenLoaded(uid, (asset) => {
        this.setState({asset: asset});

        this.launchAppForSurveyContent(asset.content, {
          name: asset.name,
          settings__style: asset.settings__style,
          settings__version: asset.settings__version,
          settings__form_id: asset.settings__form_id,
          asset_uid: asset.uid,
          asset_type: asset.asset_type,
        });
      });
    } else {
      this.launchAppForSurveyContent();
    }

    document.querySelector('.page-wrapper__content').addEventListener('scroll', this.handleScroll);
    this.listenTo(stores.surveyState, this.surveyStateChanged);
  },

  componentWillUnmount () {
    if (this.app && this.app.survey) {
      document.querySelector('.page-wrapper__content').removeEventListener('scroll', this.handleScroll);
      this.app.survey.off('change');
    }
    sessionStorage.removeItem(FORM_STYLE_CACHE_NAME);
    this.unpreventClosingTab();
  },

  routerWillLeave() {
    if (this.state.preventNavigatingOut) {
      return UNSAVED_CHANGES_WARNING;
    }
  },

  loadAsideSettings() {
    const asideSettings = sessionStorage.getItem(ASIDE_CACHE_NAME);
    if (asideSettings) {
      this.setState(JSON.parse(asideSettings));
    }
  },

  saveAsideSettings(asideSettings) {
    sessionStorage.setItem(ASIDE_CACHE_NAME, JSON.stringify(asideSettings));
  },

  onFormSettingsBoxChange() {
    this.onSurveyChange();
  },

  onProjectDetailsChange({fieldName, fieldValue}) {
    const settingsNew = this.state.settingsNew || {};
    settingsNew[fieldName] = fieldValue;
    this.setState({
      settingsNew: settingsNew
    });
    this.onSurveyChange();
  },

  surveyStateChanged(state) {
    this.setState(state);
  },

  onStyleChange(evt) {
    let settingsStyle = null;
    if (evt !== null) {
      settingsStyle = evt.value;
    }

    this.setState({
      settings__style: settingsStyle
    });
    sessionStorage.setItem(FORM_STYLE_CACHE_NAME, settingsStyle);
    this.onSurveyChange();
  },

  onVersionChange(val) {
    let settingsVersion = null;
    if (val !== null) {
      settingsVersion = val;
    }
    this.setState({
      settings__version: settingsVersion
    });
    this.onSurveyChange();
  },

  onFormIdChange(val) {
    let settingsFormId = null;
    if (val !== null) {
      settingsFormId = val;
    }
    this.setState({
      settings__form_id: settingsFormId
    });
    this.onSurveyChange();
  },

  getStyleSelectVal(optionVal) {
    return _.find(AVAILABLE_FORM_STYLES, (option) => {
      return option.value === optionVal;
    });
  },

  onSurveyChange: _.debounce(function () {
    window.parent.postMessage('form_saveneeded', '*');
    this.setState({
      asset_updated: update_states.UNSAVED_CHANGES,
    });
  }, 200),

  preventClosingTab() {
    this.setState({preventNavigatingOut: true});
    $(window).on('beforeunload.noclosetab', function(){
      return UNSAVED_CHANGES_WARNING;
    });
  },

  unpreventClosingTab() {
    this.setState({preventNavigatingOut: false});
    $(window).off('beforeunload.noclosetab');
  },

  nameChange(evt) {
    this.setState({
      name: evt.target.value,
    });
    this.onSurveyChange();
  },

  groupQuestions() {
    this.app.groupSelectedRows();
  },

  deleteQuestions() {
    this.app.deleteSelectedRows();
  },

  duplicateQuestions() {
    this.app.duplicateSelectedRows();
  },

  addQuestionsToLibrary() {
    this.app.addSelectedRowsToLibrary();
  },

  showAll(evt) {
    evt.preventDefault();
    evt.currentTarget.blur();
    this.app.expandMultioptions();
  },

  hasMetadataAndDetails() {
    return this.app && (
      this.state.asset_type === ASSET_TYPES.survey.id ||
      this.state.asset_type === ASSET_TYPES.template.id ||
      this.state.desiredAssetType === ASSET_TYPES.template.id
    );
  },

  hideMetadata() {
    return true;
  },

  hideDetails() {
    return true;
  },

  needsSave() {
    return this.state.asset_updated === update_states.UNSAVED_CHANGES;
  },

  previewForm(evt) {
    if (evt && evt.preventDefault) {
      evt.preventDefault();
    }

    if (this.state.settings__style !== undefined) {
      this.app.survey.settings.set('style', this.state.settings__style);
    }

    if (this.state.name) {
      this.app.survey.settings.set('title', this.state.name);
    }

    let surveyJSON = surveyToValidJson(this.app.survey);
    if (this.state.asset) {
      surveyJSON = unnullifyTranslations(surveyJSON, this.state.asset.content);
    }
    let params = {source: surveyJSON};

    params = koboMatrixParser(params);

    if (this.state.asset && this.state.asset.url) {
      params.asset = this.state.asset.url;
    }

    dataInterface.createAssetSnapshot(params).done((content) => {
      this.setState({
        enketopreviewOverlay: content.enketopreviewlink,
      });
    }).fail((jqxhr) => {
      let err;
      if (jqxhr && jqxhr.responseJSON && jqxhr.responseJSON.error) {
        err = jqxhr.responseJSON.error;
      } else {
        err = t('Unknown Enketo preview error');
      }
      this.setState({
        enketopreviewError: err,
      });
    });
  },

  saveForm(evt) {
    if (evt && evt.preventDefault) {
      evt.preventDefault();
    }

    if (this.state.settings__style !== undefined) {
      this.app.survey.settings.set('style', this.state.settings__style);
    }

    if (this.state.settings__version !== undefined) {
      this.app.survey.settings.set('version', this.state.settings__version);
    }

    if (this.state.settings__form_id !== undefined) {
      this.app.survey.settings.set('form_id', this.state.settings__form_id);
    }

    let surveyJSON = surveyToValidJson(this.app.survey)
    if (this.state.asset) {
      surveyJSON = unnullifyTranslations(surveyJSON, this.state.asset.content);
    }
    let params = {content: surveyJSON};

    if (this.state.name) {
      params.name = this.state.name;
    }

    // handle settings update (if any changed)
    if (this.state.settingsNew) {
      let settings = {};
      if (this.state.asset) {
        settings = this.state.asset.settings;
      }

      if (this.state.settingsNew.description) {
        settings.description = this.state.settingsNew.description;
      }
      if (this.state.settingsNew.sector) {
        settings.sector = this.state.settingsNew.sector;
      }
      if (this.state.settingsNew.country) {
        settings.country = this.state.settingsNew.country;
      }
      if (this.state.settingsNew['share-metadata']) {
        settings['share-metadata'] = this.state.settingsNew['share-metadata'];
      }
      params.settings = JSON.stringify(settings);
    }

    params = koboMatrixParser(params);

    if (this.state.editorState === 'new') {
      // we're intentionally leaving after creating new asset,
      // so there is nothing unsaved here
      this.unpreventClosingTab();

      // create new asset
      if (this.state.desiredAssetType) {
        params.asset_type = this.state.desiredAssetType;
      } else {
        params.asset_type = 'block';
      }
      actions.resources.createResource.triggerAsync(params)
        .then(() => {
          window.parent.postMessage('form_savecomplete', '*');
          hashHistory.push('/library');
        });
    } else {
      // update existing asset
      var assetId = this.props.params.assetid;

      actions.resources.updateAsset.triggerAsync(assetId, params)
        .then(() => {
          window.parent.postMessage('form_savecomplete', '*');
          this.unpreventClosingTab();
          this.setState({
            asset_updated: update_states.UP_TO_DATE,
            surveySaveFail: false,
          });
        })
        .catch((resp) => {
          var errorMsg = `${t('Your changes could not be saved, likely because of a lost internet connection.')}&nbsp;${t('Keep this window open and try saving again while using a better connection.')}&nbsp;${t('Please contact your administrator if this message persists.')}`;
          if (resp.statusText !== 'error') {
            errorMsg = resp.statusText;
          }

          alertify.defaults.theme.ok = 'ajs-cancel';
          let dialog = alertify.dialog('alert');
          let opts = {
            title: t('Error saving form'),
            message: errorMsg,
            label: t('Dismiss'),
          };
          dialog.set(opts).show();

          this.setState({
            surveySaveFail: true,
            asset_updated: update_states.SAVE_FAILED
          });
        });
    }
    this.setState({
      asset_updated: update_states.PENDING_UPDATE,
    });
  },

  handleScroll(evt) {
    var scrollTop = evt.target.scrollTop;
    if (!this.state.formHeaderFixed && scrollTop > 40) {
      var fhfh = $('.asset-view__row--header').height();
      this.setState({
        formHeaderFixed: true,
        formHeaderFixedHeight: fhfh,
      });
    } else if (this.state.formHeaderFixed && scrollTop <= 32) {
      this.setState({
        formHeaderFixed: false
      });
    }
  },

  buttonStates() {
    var ooo = {};
    if (!this.app) {
      ooo.allButtonsDisabled = true;
    } else {
      ooo.previewDisabled = true;
      if (this.app && this.app.survey) {
        ooo.previewDisabled = this.app.survey.rows.length < 1;
      }
      ooo.groupable = !!this.state.groupButtonIsActive;
      ooo.showAllOpen = !!this.state.multioptionsExpanded;
      ooo.showAllAvailable = (() => {
        var hasSelect = false;
        this.app.survey.forEachRow(function(row){
          if (row._isSelectQuestion()) {
            hasSelect = true;
          }
        });
        return hasSelect;
      })(); // todo: only true if survey has select questions
      ooo.name = this.state.name;
      ooo.hasSettings = this.state.backRoute === '/forms';
      ooo.styleValue = this.state.settings__style;
      ooo.versionValue = this.state.settings__version;
      ooo.formIdValue = this.state.settings__form_id;
    }

    var saveButtonText = 'save';
    var backButtonText = 'back';
    if (this.state.asset_type === 'survey') {
      saveButtonText = 'save draft';
    } else {
      saveButtonText = 'save changes';
      backButtonText = 'back to library';
    }

    if (this.state.editorState === 'new') {
      ooo.saveButtonText = t('create');
    } else if (this.state.surveySaveFail) {
      ooo.saveButtonText = `${t(saveButtonText)} (${t('retry')}) `;
    } else {
      ooo.saveButtonText = `${t(saveButtonText)}`;
    }
    ooo.backButtonText = `${t(backButtonText)}`;
    return ooo;
  },

  toggleAsideLibrarySearch(evt) {
    evt.target.blur();
    const asideSettings = {
      asideLayoutSettingsVisible: false,
      asideLibrarySearchVisible: !this.state.asideLibrarySearchVisible,
    };
    this.setState(asideSettings);
    this.saveAsideSettings(asideSettings);
  },

  toggleAsideLayoutSettings(evt) {
    evt.target.blur();
    const asideSettings = {
      asideLayoutSettingsVisible: !this.state.asideLayoutSettingsVisible,
      asideLibrarySearchVisible: false
    };
    this.setState(asideSettings);
    this.saveAsideSettings(asideSettings);
  },

  hidePreview() {
    this.setState({
      enketopreviewOverlay: false
    });
  },

  hideCascade() {
    this.setState({
      showCascadePopup: false
    });
  },

  launchAppForSurveyContent(survey, _state = {}) {
    if (_state.name) {
      _state.savedName = _state.name;
    }

    sessionStorage.setItem(FORM_STYLE_CACHE_NAME, _state.settings__style);

    let isEmptySurvey = (
        survey &&
        Object.keys(survey.settings).length === 0 &&
        survey.survey.length === 0
      );

    try {
      if (!survey) {
        survey = dkobo_xlform.model.Survey.create();
      } else {
        survey = dkobo_xlform.model.Survey.loadDict(survey);
        if (isEmptySurvey) {
          survey.surveyDetails.importDefaults();
        }
      }
    } catch (err) {
      _state.surveyLoadError = err.message;
      _state.surveyAppRendered = false;
    }

    if (!_state.surveyLoadError) {
      _state.surveyAppRendered = true;

      var skp = new SurveyScope({
        survey: survey
      });
      this.app = new dkobo_xlform.view.SurveyApp({
        survey: survey,
        stateStore: stores.surveyState,
        ngScope: skp,
      });
      this.app.$el.appendTo(ReactDOM.findDOMNode(this.refs['form-wrap']));
      this.app.render();
      survey.rows.on('change', this.onSurveyChange);
      survey.rows.on('sort', this.onSurveyChange);
      survey.on('change', this.onSurveyChange);
    }

    this.setState(_state);
  },

  clearPreviewError() {
    this.setState({
      enketopreviewError: false,
    });
  },

  // navigating out of form builder

  safeNavigateToRoute(route) {
    if (!this.needsSave()) {
      hashHistory.push(route);
    } else {
      let dialog = alertify.dialog('confirm');
      let opts = {
        title: UNSAVED_CHANGES_WARNING,
        message: '',
        labels: {ok: t('Yes, leave form'), cancel: t('Cancel')},
        onok: () => {
          window.parent.postMessage('form_savecomplete', '*');
          hashHistory.push(route);
        },
        oncancel: dialog.destroy
      };
      dialog.set(opts).show();
    }
  },

  safeNavigateToList() {
    if (this.state.asset_type) {
      if (this.state.asset_type === 'survey') {
        this.safeNavigateToRoute('/forms/');
      } else {
        this.safeNavigateToRoute('/library/');
      }
    } else if (this.props.location.pathname.startsWith('/library/new')) {
      this.safeNavigateToRoute('/library/');
    } else {
      this.safeNavigateToRoute('/forms/');
    }
  },

  safeNavigateToForm() {
    var backRoute = this.state.backRoute;
    if (this.state.backRoute === '/forms') {
      backRoute = `/forms/${this.state.asset_uid}`;
    }
    this.safeNavigateToRoute(backRoute);
  },

  canNavigateToList() {
    return this.state.surveyAppRendered && 
      (this.state.asset_type !== 'survey' || this.props.location.pathname.startsWith('/library/new'));
  },

  // rendering methods

  renderFormBuilderHeader () {
    let {
      previewDisabled,
      groupable,
      showAllOpen,
      showAllAvailable,
      saveButtonText,
      backButtonText,
    } = this.buttonStates();

    let nameFieldLabel;
    switch (this.state.asset_type) {
      case ASSET_TYPES.template.id:
        nameFieldLabel = ASSET_TYPES.template.label;
        break;
      case ASSET_TYPES.survey.id:
        nameFieldLabel = ASSET_TYPES.survey.label;
        break;
      case ASSET_TYPES.block.id:
        nameFieldLabel = ASSET_TYPES.block.label;
        break;
      case ASSET_TYPES.question.id:
        nameFieldLabel = ASSET_TYPES.question.label;
        break;
      default:
        nameFieldLabel = null;
    }

    if (
      nameFieldLabel === null &&
      this.state.desiredAssetType === ASSET_TYPES.template.id
    ) {
      nameFieldLabel = ASSET_TYPES.template.label;
    }

    if (
      nameFieldLabel &&
      nameFieldLabel === ASSET_TYPES.survey.label
    ) {
      nameFieldLabel = `${nameFieldLabel} title`;
    }

    return (
      <bem.FormBuilderHeader>
        <bem.FormBuilderHeader__row m='primary'>

          <bem.FormBuilderHeader__cell m={'name'} >
            <bem.FormModal__item>
              {nameFieldLabel &&
                <label>{nameFieldLabel}</label>
              }
              <input
                type='text'
                onChange={this.nameChange}
                value={this.state.name}
                title={this.state.name}
                id='nameField'
              />
            </bem.FormModal__item>
          </bem.FormBuilderHeader__cell>

          <bem.FormBuilderHeader__cell m={'buttonsTopRight'} >

            {this.canNavigateToList() &&
              <bem.FormBuilderHeader__button
                m={['back']}
                onClick={this.safeNavigateToList}
                disabled={!this.state.surveyAppRendered || !!this.state.surveyLoadError}
              >
                {backButtonText}
              </bem.FormBuilderHeader__button>
            }

            <bem.FormBuilderHeader__button
              m={['save', {
                savepending: this.state.asset_updated === update_states.PENDING_UPDATE,
                savecomplete: this.state.asset_updated === update_states.UP_TO_DATE,
                savefailed: this.state.asset_updated === update_states.SAVE_FAILED,
                saveneeded: this.needsSave(),
              }]}
              onClick={this.saveForm}
              disabled={!this.state.surveyAppRendered || !!this.state.surveyLoadError}
            >
              <i />
              {saveButtonText}
            </bem.FormBuilderHeader__button>

          </bem.FormBuilderHeader__cell>
        </bem.FormBuilderHeader__row>

        <bem.FormBuilderHeader__row m={'secondary'} >
          <bem.FormBuilderHeader__cell m={'toolsButtons'} >
            <bem.FormBuilderHeader__button
              m={['preview', {previewdisabled: previewDisabled}]}
              onClick={this.previewForm}
              disabled={previewDisabled}
              data-tip={t('Preview form')}
            >
              <i className='k-icon-view' />
            </bem.FormBuilderHeader__button>

            { showAllAvailable &&
              <bem.FormBuilderHeader__button m={['show-all', {
                    open: showAllOpen,
                  }]}
                  onClick={this.showAll}
                  data-tip={t('Expand / collapse questions')}>
                <i className='k-icon-view-all-alt' />
              </bem.FormBuilderHeader__button>
            }

            <bem.FormBuilderHeader__button
              m={['group', {groupable: groupable}]}
              onClick={this.groupQuestions}
              disabled={!groupable}
              data-tip={groupable ? t('Create group with selected questions') : t('Grouping disabled. Please select at least one question.')}
            >
              <i className='k-icon-group' />
            </bem.FormBuilderHeader__button>

            <bem.FormBuilderHeader__button
              m={['group', {groupable: groupable}]}
              onClick={this.deleteQuestions}
              disabled={!groupable}
              data-tip={groupable ? t('Delete selected questions') : t('Delete questions disabled. Please select at least one question.')}
            >
              <i className='k-icon-trash' />
            </bem.FormBuilderHeader__button>

            <bem.FormBuilderHeader__button
              m={['group', {groupable: groupable}]}
              onClick={this.duplicateQuestions}
              disabled={!groupable}
              data-tip={groupable ? t('Duplicate selected questions') : t('Duplicate questions disabled. Please select at least one question.')}
            >
              <i className='k-icon-clone' />
            </bem.FormBuilderHeader__button>

            <bem.FormBuilderHeader__button
              m={['group', {groupable: groupable}]}
              onClick={this.addQuestionsToLibrary}
              disabled={!groupable}
              data-tip={groupable ? t('Add selected questions to library') : t('Add selected questions to library disabled. Please select at least one question.')}
              className='add-questions-to-library'
            >
              <i class='k-icon-folder'>
                <i className='k-icon-plus' />
              </i>
            </bem.FormBuilderHeader__button>

            <bem.FormBuilderHeader__button
              m={['download']}
              data-tip={t('Download form')}
              className='is-edge'
            >
              <i className='k-icon-download' />
            </bem.FormBuilderHeader__button>

            <bem.FormBuilderHeader__button
              m={['attach']}
              data-tip={t('Attach media files')}
              className='is-edge'
            >
              <i className='k-icon-attach' />
            </bem.FormBuilderHeader__button>

          </bem.FormBuilderHeader__cell>

          <bem.FormBuilderHeader__cell m='verticalRule'/>

          <bem.FormBuilderHeader__cell m='spacer'/>

          <bem.FormBuilderHeader__cell m='verticalRule'/>

          <bem.FormBuilderHeader__cell>
            <bem.FormBuilderHeader__button
              m={['panel-toggle', this.state.asideLibrarySearchVisible ? 'active' : null]}
              onClick={this.toggleAsideLibrarySearch}
            >
              <i className={['k-icon', this.state.asideLibrarySearchVisible ? 'k-icon-close' : 'k-icon-library' ].join(' ')} />
              <span className='panel-toggle-name'>{t('Add from Library')}</span>
            </bem.FormBuilderHeader__button>
          </bem.FormBuilderHeader__cell>

          <bem.FormBuilderHeader__cell m={'verticalRule'} />

          <bem.FormBuilderHeader__cell>
            <bem.FormBuilderHeader__button
              m={['panel-toggle', this.state.asideLayoutSettingsVisible ? 'active' : null]}
              onClick={this.toggleAsideLayoutSettings}
            >
              <i className={['k-icon', this.state.asideLayoutSettingsVisible ? 'k-icon-close' : 'k-icon-settings' ].join(' ')} />
              <span className='panel-toggle-name'>
                {this.hasMetadataAndDetails() &&
                  t('Layout & Settings')
                }
                {!this.hasMetadataAndDetails() &&
                  t('Layout')
                }
              </span>
            </bem.FormBuilderHeader__button>
          </bem.FormBuilderHeader__cell>
        </bem.FormBuilderHeader__row>
      </bem.FormBuilderHeader>
    );
  },

  renderAside() {
    let {
      styleValue,
      versionValue,
      formIdValue,
      hasSettings
    } = this.buttonStates();

    const isAsideVisible = (
      this.state.asideLayoutSettingsVisible ||
      this.state.asideLibrarySearchVisible
    );

    return (
      <bem.FormBuilderAside m={isAsideVisible ? 'visible' : null}>
        { this.state.asideLayoutSettingsVisible &&
          <bem.FormBuilderAside__content>
            <bem.FormBuilderAside__row>
              <bem.FormBuilderAside__header>
                {t('Form style')}
                <a
                  href={formDesignerSupportUrl}
                  target='_blank'
                  data-tip={t('Learn more about Form Designer')}
                >
                  <i className='k-icon k-icon-help'/>
                </a>
              </bem.FormBuilderAside__header>

              <label
                className='kobo-select-label'
                htmlFor='webform-style'
              >
                { hasSettings ?
                  t('Select the form style that you would like to use. This will only affect web forms.')
                  :
                  t('Select the form style. This will only affect the Enketo preview, and it will not be saved with the question or block.')
                }
              </label>

              <Select
                className='kobo-select'
                classNamePrefix='kobo-select'
                id='webform-style'
                name='webform-style'
                ref='webformStyle'
                value={this.getStyleSelectVal(styleValue)}
                onChange={this.onStyleChange}
                placeholder={AVAILABLE_FORM_STYLES[0].label}
                options={AVAILABLE_FORM_STYLES}
                menuPlacement='bottom'
              />
            </bem.FormBuilderAside__row>

            <bem.FormBuilderAside__row>
              <bem.FormBuilderAside__header>
                {t('Form information')}
              </bem.FormBuilderAside__header>

              <bem.FormModal__item>
                <TextBox
                  type='text'
                  label={t('Form ID')}
                  value={formIdValue}
                  onChange={this.onFormIdChange}
                />
              </bem.FormModal__item>

              <bem.FormModal__item>
                <TextBox
                  type='text'
                  label={t('Version number')}
                  value={versionValue}
                  onChange={this.onVersionChange}
                />
              </bem.FormModal__item>
            </bem.FormBuilderAside__row>

            {this.hasMetadataAndDetails() && !this.hideMetadata() &&
              <bem.FormBuilderAside__row>
                <bem.FormBuilderAside__header>
                  {t('Metadata')}
                </bem.FormBuilderAside__header>

                <FormSettingsBox
                  survey={this.app.survey}
                  onChange={this.onFormSettingsBoxChange}
                  {...this.state}
                />
              </bem.FormBuilderAside__row>
            }

            {this.hasMetadataAndDetails() && !this.hideDetails() &&
              <bem.FormBuilderAside__row>
                <bem.FormBuilderAside__header>
                  {t('Details')}
                </bem.FormBuilderAside__header>

                <ProjectSettings
                  context={PROJECT_SETTINGS_CONTEXTS.BUILDER}
                  onProjectDetailsChange={this.onProjectDetailsChange}
                  formAsset={this.state.asset}
                />
              </bem.FormBuilderAside__row>
            }
          </bem.FormBuilderAside__content>
        }
        { this.state.asideLibrarySearchVisible &&
          <bem.FormBuilderAside__content>
            <bem.FormBuilderAside__row>
              <bem.FormBuilderAside__header>
                {t('Search Library')}
              </bem.FormBuilderAside__header>
            </bem.FormBuilderAside__row>

            <bem.FormBuilderAside__row>
              <AssetNavigator/>
            </bem.FormBuilderAside__row>
          </bem.FormBuilderAside__content>
        }
      </bem.FormBuilderAside>
    );
  },

  renderNotLoadedMessage() {
    if (this.state.surveyLoadError) {
      return (
        <ErrorMessage>
          <ErrorMessage__strong>
            {t('Error loading form:')}
          </ErrorMessage__strong>
          <p>
            {this.state.surveyLoadError}
          </p>
        </ErrorMessage>
      );
    }

    return (
      <bem.Loading>
        <bem.Loading__inner>
          <i />
          {t('loading...')}
        </bem.Loading__inner>
      </bem.Loading>
    );
  },

  render() {
    var docTitle = this.state.name || t('Untitled');

    return (
      <DocumentTitle title={`${docTitle} | OpenClinica`}>
        <ui.Panel m={['transparent', 'fixed']}>
          {this.renderAside()}

          <bem.FormBuilder>
            {this.renderFormBuilderHeader()}

            <bem.FormBuilder__contents>
              <div ref='form-wrap' className='form-wrap'>
                {!this.state.surveyAppRendered &&
                  this.renderNotLoadedMessage()
                }
              </div>
            </bem.FormBuilder__contents>
          </bem.FormBuilder>

          {this.state.enketopreviewOverlay &&
            <ui.Modal
              open
              large
              onClose={this.hidePreview}
              title={t('Form Preview')}
            >
              <ui.Modal.Body>
                <div className='enketo-holder'>
                  <iframe src={this.state.enketopreviewOverlay} />
                </div>
              </ui.Modal.Body>
            </ui.Modal>
          }

          {!this.state.enketopreviewOverlay && this.state.enketopreviewError &&
            <ui.Modal
              open
              error
              onClose={this.clearPreviewError}
              title={t('Error generating preview')}
            >
              <ui.Modal.Body>{this.state.enketopreviewError}</ui.Modal.Body>
            </ui.Modal>
          }

          {this.state.showCascadePopup &&
            <ui.Modal
              open
              onClose={this.hideCascade}
              title={t('Import Cascading Select Questions')}
            >
              <ui.Modal.Body>{this.renderCascadePopup()}</ui.Modal.Body>
            </ui.Modal>
          }
        </ui.Panel>
      </DocumentTitle>
    );
  },
}, cascadeMixin);
