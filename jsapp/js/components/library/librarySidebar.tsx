import React from 'react'

import PropTypes from 'prop-types'
import autoBind from 'react-autobind'
import Dropzone from 'react-dropzone'
import reactMixin from 'react-mixin'
import Reflux from 'reflux'
import { deleteAsset, manageAssetSettings } from '#/assetQuickActions'
import assetUtils from '#/assetUtils'
import bem, { makeBem } from '#/bem'
import { navigatePreservingEConsent } from '#/components/formBuilder/econsentSignature'
import { ASSET_TYPES, MODAL_TYPES } from '#/constants'
import mixins from '#/mixins'
import subdomainLibraryStore from '#/oc/subdomainLibraryStore'
import pageState from '#/pageState.store'
import PopoverMenu from '#/popoverMenu'
import { routerIsActive, withRouter } from '#/router/legacy'
import { ROUTES } from '#/router/routerConstants'
import sessionStore from '#/stores/session'
import { validFileTypes } from '#/utils'
// OC fork: upstream renamed `ownedCollectionsStore` to `managedCollectionsStore`.
import managedCollectionsStore from './managedCollectionsStore'
import './librarySidebar.scss'

// OC fork: these BEM elements used to live in the fork's bemComponents, but
// upstream only defines `FormSidebar`/`__label`/`__labelText`/`__labelCount`.
// (Re-)define the collection-list elements here so the fork sidebar styles in
// `librarySidebar.scss` (`.form-sidebar__grouping`, `.form-sidebar__item`,
// `.form-sidebar__itemlink`) resolve.
if (!bem.FormSidebar__grouping) {
  bem.FormSidebar__grouping = makeBem(bem.FormSidebar, 'grouping')
}
if (!bem.FormSidebar__item) {
  bem.FormSidebar__item = makeBem(bem.FormSidebar, 'item')
}
if (!bem.FormSidebar__itemlink) {
  bem.FormSidebar__itemlink = makeBem(bem.FormSidebar, 'itemlink')
}

const TEMPLATE_TYPE = {
  value: ASSET_TYPES.template.id,
  label: ASSET_TYPES.template.label,
}

/**
 * OpenClinica fork: study-EDC-oriented library sidebar.
 *
 * Replaces the stock Kobo sidebar (single "new" modal button + "My
 * Library"/"Public Collections" NavLinks) with:
 *  - a "NEW" PopoverMenu (Question / Template / Upload / Collection);
 *  - a single "Library" root link with the root-asset count;
 *  - an owned-collections list with per-collection filter / rename / delete.
 *
 * Most importantly it preserves the `econsent` URL query param when navigating
 * to the template creator, so the downstream eConsent Signature item-type
 * gating (`isEConsentSignatureItemTypeAllowed`, which reads `econsent` from
 * `window.location.hash`) keeps working.
 */
class LibrarySidebar extends Reflux.Component<any, any> {
  // These members are injected at runtime by the reactMixins applied at the
  // bottom of this file (Reflux.ListenerMixin -> `listenTo`; mixins.droppable
  // -> `dropFiles`) and by the `withRouter` HOC (`props.router`). They are
  // declared here only so the strict TS compiler accepts the fork wiring.
  declare listenTo: (listenable: any, callback: (...args: any[]) => void) => void
  declare dropFiles: (files: File[], rejectedFiles: File[], opts: object, pms?: object) => void
  declare props: { router: { navigate: (path: string) => void; searchParams: URLSearchParams } }

  constructor(props: any) {
    super(props)
    this.state = {
      isLoading: true,
      libraryTotalCount: 0,
      // default is template
      desiredType: TEMPLATE_TYPE,
      sidebarCollections: [],
    }
    autoBind(this)
  }

  componentDidMount() {
    this.listenTo(subdomainLibraryStore, this.myLibraryStoreChanged)
    this.listenTo(managedCollectionsStore, this.ownedCollectionsStoreChanged)
    this.setState({
      isLoading: false,
      libraryTotalCount: subdomainLibraryStore.getCurrentUserRootAssets(),
      sidebarCollections: managedCollectionsStore.data.collections,
    })
  }

  goToBlockCreator() {
    let targetPath: string = ROUTES.NEW_LIBRARY_ITEM
    const currentCollectionUid = subdomainLibraryStore.getCollectionUid()
    if (currentCollectionUid) {
      const found = managedCollectionsStore.find(currentCollectionUid)
      if (found && found.asset_type === ASSET_TYPES.collection.id) {
        // when creating from within a collection page, make the new asset
        // a child of this collection
        targetPath = ROUTES.NEW_LIBRARY_CHILD.replace(':uid', found.uid)
      }
    }

    navigatePreservingEConsent(this.props.router, targetPath)
  }

  goToTemplateCreator() {
    let targetPath: string = ROUTES.NEW_LIBRARY_TEMPLATE_ITEM
    const currentCollectionUid = subdomainLibraryStore.getCollectionUid()
    if (currentCollectionUid) {
      const found = managedCollectionsStore.find(currentCollectionUid)
      if (found && found.asset_type === ASSET_TYPES.collection.id) {
        // when creating from within a collection page, make the new asset
        // a child of this collection
        targetPath = ROUTES.NEW_LIBRARY_TEMPLATE_ITEM_CHILD.replace(':uid', found.uid)
      }
    }
    // Preserve the econsent status in the URL so that isEConsentSignatureItemTypeAllowed()
    // returns the correct value when the row-selector picker is opened.
    navigatePreservingEConsent(this.props.router, targetPath)
  }

  onFileDrop(files: File[]) {
    if (files[0]) {
      this.dropFiles([files[0]], [], {}, { desired_type: TEMPLATE_TYPE.value })
    }
  }

  goToCollectionCreator(evt: React.SyntheticEvent) {
    evt.preventDefault()

    pageState.showModal({
      type: MODAL_TYPES.LIBRARY_COLLECTION_CREATE,
    })
  }

  myLibraryStoreChanged() {
    this.setState({
      isLoading: false,
      libraryTotalCount: subdomainLibraryStore.getCurrentUserRootAssets(),
    })
  }

  ownedCollectionsStoreChanged() {
    this.setState({
      isLoading: false,
      sidebarCollections: managedCollectionsStore.data.collections,
    })
  }

  showLibraryNewModal(evt: React.SyntheticEvent) {
    evt.preventDefault()
    pageState.showModal({
      type: MODAL_TYPES.LIBRARY_NEW_ITEM,
    })
  }

  isMyLibrarySelected() {
    return routerIsActive('library/my-library')
  }

  isPublicCollectionsSelected() {
    return routerIsActive('library/public-collections')
  }

  renameCollection(collection: any) {
    // OC fork used `assetUtils.modifyDetails`; upstream moved this behavior to
    // `manageAssetSettings` in assetQuickActions.
    manageAssetSettings(collection)
  }

  deleteCollection(collection: any) {
    // OC fork used `mixins.clickAssets.click.asset.delete`; upstream moved this
    // behavior to the standalone `deleteAsset` in assetQuickActions.
    deleteAsset(collection, assetUtils.getAssetDisplayName(collection).final, this.onDeleteComplete.bind(this))
  }

  onDeleteComplete() {
    // do nothing
  }

  clickFilterByCollection(evt: React.SyntheticEvent) {
    evt.preventDefault()
    const collectionUid = (evt.currentTarget as HTMLElement).getAttribute('data-collection-uid')
    if (collectionUid) {
      subdomainLibraryStore.setCollectionUid(collectionUid)
    }
  }

  clickWithoutCollectionFilter(evt: React.SyntheticEvent) {
    evt.preventDefault()
    subdomainLibraryStore.clearCollectionUid()
  }

  render() {
    let sidebarModifier = ''
    if (this.state.isLoading) {
      sidebarModifier = 'loading'
    }

    return (
      <React.Fragment>
        {/*
          OC fork: the NEW menu must be unavailable when logged out. The fork
          passed `disabled` to PopoverMenu, but the current upstream PopoverMenu
          has no `disabled` prop, so we gate by only rendering the interactive
          menu when logged in (preserving the original intent).
        */}
        <div
          className={'library-sidebar__new-menu' + (sessionStore.isLoggedIn ? '' : ' is-disabled')}
          aria-disabled={!sessionStore.isLoggedIn}
        >
          <PopoverMenu type='new-menu' triggerLabel={t('new')}>
            <bem.PopoverMenu__item onClick={this.goToBlockCreator}>
              <i className='k-icon-question' />
              {t('Question')}
            </bem.PopoverMenu__item>
            <bem.PopoverMenu__item onClick={this.goToTemplateCreator}>
              <i className='k-icon-template' />
              {t('Template')}
            </bem.PopoverMenu__item>
            <Dropzone
              onDrop={this.onFileDrop.bind(this)}
              multiple={false}
              className='dropzone'
              accept={validFileTypes()}
            >
              <bem.PopoverMenu__link>
                <i className='k-icon-upload' />
                {t('Upload')}
              </bem.PopoverMenu__link>
            </Dropzone>
            <bem.PopoverMenu__item onClick={this.goToCollectionCreator}>
              <i className='k-icon-folder' />
              {t('Collection')}
            </bem.PopoverMenu__item>
          </PopoverMenu>
        </div>

        <bem.FormSidebar m={sidebarModifier}>
          <bem.FormSidebar__label
            m={{ selected: this.isMyLibrarySelected() }}
            onClick={this.clickWithoutCollectionFilter}
          >
            <i className='k-icon k-icon-library' />
            <bem.FormSidebar__labelText>{t('Library')}</bem.FormSidebar__labelText>
            <bem.FormSidebar__labelCount>{this.state.libraryTotalCount}</bem.FormSidebar__labelCount>
          </bem.FormSidebar__label>

          {this.state.sidebarCollections && (
            <bem.FormSidebar__grouping>
              {this.state.sidebarCollections.map((collection: any) => (
                <bem.FormSidebar__item
                  key={collection.uid}
                  m={{
                    collection: true,
                    selected: subdomainLibraryStore.getCollectionUid() === collection.uid,
                  }}
                >
                  <bem.FormSidebar__itemlink
                    onClick={this.clickFilterByCollection}
                    data-collection-uid={collection.uid}
                    data-collection-name={collection.name}
                  >
                    <i className='k-icon-folder' />
                    {collection.name}
                  </bem.FormSidebar__itemlink>
                  {subdomainLibraryStore.getCollectionUid() === collection.uid && (
                    <PopoverMenu type='collectionSidebarPublic-menu' triggerLabel={<i className='k-icon-more' />}>
                      <bem.PopoverMenu__link
                        m={'rename'}
                        onClick={() => this.renameCollection(collection)}
                        data-collection-uid={collection.uid}
                        data-collection-name={collection.name}
                      >
                        <i className='k-icon-edit' />
                        {t('Rename')}
                      </bem.PopoverMenu__link>
                      <bem.PopoverMenu__link
                        m={'delete'}
                        onClick={() => this.deleteCollection(collection)}
                        data-collection-uid={collection.uid}
                      >
                        <i className='k-icon-trash' />
                        {t('Delete')}
                      </bem.PopoverMenu__link>
                    </PopoverMenu>
                  )}
                </bem.FormSidebar__item>
              ))}
            </bem.FormSidebar__grouping>
          )}
        </bem.FormSidebar>
      </React.Fragment>
    )
  }
}
;(LibrarySidebar as any).contextTypes = {
  router: PropTypes.object,
}

// `react-mixin`'s types expect a `Mixin<any, any>` shape; the Reflux/kpi mixins
// don't declare it, so cast to `any` (matches the untyped fork .es6 behavior).
reactMixin(LibrarySidebar.prototype, Reflux.ListenerMixin as any)
reactMixin(LibrarySidebar.prototype, mixins.contextRouter as any)
reactMixin(LibrarySidebar.prototype, mixins.droppable as any)

export default withRouter(LibrarySidebar)
