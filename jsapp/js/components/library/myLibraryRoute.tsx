import React from 'react'

import type { DragEvent } from 'react'

import DocumentTitle from 'react-document-title'
import Dropzone from 'react-dropzone'
import type { FileWithPreview } from 'react-dropzone'
import Select from 'react-select'
import bem, { makeBem } from '#/bem'
import AssetsTable from '#/components/assetsTable/assetsTable'
import { AssetsTableContextName } from '#/components/assetsTable/assetsTableConstants'
import { ROOT_BREADCRUMBS } from '#/components/library/libraryConstants'
import { AssetTypeName, MODAL_TYPES } from '#/constants'
import mixins from '#/mixins'
import subdomainLibraryStore from '#/oc/subdomainLibraryStore'
import type { SubdomainLibraryStoreData } from '#/oc/subdomainLibraryStore'
import pageState from '#/pageState.store'
import type { OrderDirection } from '#/projects/projectViews/constants'
import { validFileTypes } from '#/utils'
import libraryTypeFilterStore from './libraryTypeFilterStore'
import subdomainCollectionsStore from './subdomainCollectionsStore'
import './assetBreadcrumbs.scss'
import './myLibrary.scss'

bem.LibraryActions = makeBem(null, 'library-actions')
bem.LibraryActionsButtons = makeBem(null, 'library-actions-buttons')
bem.LibraryActionsButtons__button = makeBem(bem.LibraryActionsButtons, 'button', 'a')
bem.LibraryTypeFilter = makeBem(null, 'library-type-filter')

const LIBRARY_MANAGEMENT_SUPPORT_URL = 'https://docs.openclinica.com/oc4/help-index/form-designer/library-management/'

// OpenClinica: fork state added on top of SubdomainLibraryStoreData.
type MyLibraryRouteState = SubdomainLibraryStoreData & {
  showAllTags: boolean
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  typeFilterVal: any
}

export default class MyLibraryRoute extends React.Component<{}, MyLibraryRouteState> {
  private unlisteners: Function[] = []

  state = this.getFreshState()

  getFreshState(): MyLibraryRouteState {
    return {
      isFetchingData: subdomainLibraryStore.data.isFetchingData,
      assets: subdomainLibraryStore.data.assets,
      metadata: subdomainLibraryStore.data.metadata,
      totalUserAssets: subdomainLibraryStore.data.totalUserAssets,
      totalSearchAssets: subdomainLibraryStore.data.totalSearchAssets,
      orderColumnId: subdomainLibraryStore.data.orderColumnId,
      orderValue: subdomainLibraryStore.data.orderValue,
      filterColumnId: subdomainLibraryStore.data.filterColumnId,
      filterValue: subdomainLibraryStore.data.filterValue,
      currentPage: subdomainLibraryStore.data.currentPage,
      totalPages: subdomainLibraryStore.data.totalPages,
      collectionUid: subdomainLibraryStore.data.collectionUid,
      totalUserRootAssets: subdomainLibraryStore.data.totalUserRootAssets,
      showAllTags: false,
      typeFilterVal: libraryTypeFilterStore.getFilterType(),
    }
  }

  componentDidMount() {
    this.unlisteners.push(subdomainLibraryStore.listen(this.myLibraryStoreChanged.bind(this), this))
    this.unlisteners.push(subdomainCollectionsStore.listen(this.myLibraryStoreChanged.bind(this), this))
  }

  componentWillUnmount() {
    this.unlisteners.forEach((clb) => {
      clb()
    })
  }

  myLibraryStoreChanged() {
    this.setState(this.getFreshState())
  }

  onAssetsTableOrderChange(columnId: string, value: OrderDirection) {
    subdomainLibraryStore.setOrder(columnId, value)
  }

  onAssetsTableFilterChange(columnId: string | null, value: string | null) {
    subdomainLibraryStore.setFilter(columnId, value)
  }

  onAssetsTableSwitchPage(pageNumber: number) {
    subdomainLibraryStore.setCurrentPage(pageNumber)
  }

  clickShowAllTagsToggle() {
    this.setState((prevState) => ({ showAllTags: !prevState.showAllTags }))
  }

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  onTypeFilterChange(evt: any) {
    if (evt.value !== this.state.typeFilterVal) {
      this.setState({ typeFilterVal: evt })
      libraryTypeFilterStore.setFilterType(evt)
    }
  }

  /**
   * If only one file was passed, then open a modal for selecting the type.
   * Otherwise just start uploading all files.
   */
  onFileDrop(acceptedFiles: FileWithPreview[], rejectedFiles: FileWithPreview[], evt: DragEvent<HTMLDivElement>) {
    if (acceptedFiles.length === 1) {
      pageState.switchModal({
        type: MODAL_TYPES.LIBRARY_UPLOAD,
        file: acceptedFiles[0],
      })
    } else {
      // TODO comes from mixin
      mixins.droppable.dropFiles(acceptedFiles, rejectedFiles, evt)
    }
  }

  render() {
    let contextualEmptyMessage: React.ReactNode = t('Your search returned no results.')

    if (subdomainLibraryStore.data.totalUserAssets === 0) {
      contextualEmptyMessage = (
        <div>
          {t(
            "Let's get started by creating your first library question, block, template or collection. Click the New button to create it.",
          )}
          <div className='pro-tip'>
            {t(
              'Advanced users: You can also drag and drop XLSForms here and they will be uploaded and converted to library items.',
            )}
          </div>
        </div>
      )
    }

    const TYPE_FILTER_OPTIONS = [
      { value: 'all', label: t('Show All') },
      { value: AssetTypeName.question, label: t('Question') },
      { value: AssetTypeName.block, label: t('Block') },
      { value: AssetTypeName.template, label: t('Template') },
    ]

    return (
      <DocumentTitle title={`${t('Library')} | OpenClinica`}>
        <Dropzone
          onDrop={this.onFileDrop.bind(this)}
          disableClick
          multiple
          className='dropzone'
          activeClassName='dropzone--active'
          accept={validFileTypes()}
        >
          <bem.LibraryActions>
            <bem.LibraryActionsButtons
              m={{
                'display-all-tags': this.state.showAllTags,
              }}
            >
              <bem.LibraryActionsButtons__button
                m='library-help-link'
                href={LIBRARY_MANAGEMENT_SUPPORT_URL}
                target='_blank'
                data-tip={t('Learn more about Library Management')}
              >
                <i className='k-icon k-icon-help' />
              </bem.LibraryActionsButtons__button>
              <bem.LibraryActionsButtons__button
                m='all-tags-toggle'
                onClick={this.clickShowAllTagsToggle.bind(this)}
                data-tip={this.state.showAllTags ? t('Hide all labels') : t('Show all labels')}
              >
                <i className='k--icon k-icon-tag' />
              </bem.LibraryActionsButtons__button>
            </bem.LibraryActionsButtons>
            <bem.LibraryTypeFilter>
              {t('Filter by type:')}
              &nbsp;
              <Select
                className='kobo-select'
                classNamePrefix='kobo-select'
                value={this.state.typeFilterVal}
                isClearable={false}
                isSearchable={false}
                options={TYPE_FILTER_OPTIONS}
                onChange={this.onTypeFilterChange.bind(this)}
              />
            </bem.LibraryTypeFilter>
          </bem.LibraryActions>

          <bem.Breadcrumbs m='gray-wrapper'>
            <bem.Breadcrumbs__crumb href={ROOT_BREADCRUMBS.MY_LIBRARY.href}>
              {ROOT_BREADCRUMBS.MY_LIBRARY.label}
            </bem.Breadcrumbs__crumb>
            {subdomainLibraryStore.getCollectionUid() && (
              <React.Fragment>
                <i className='k-icon k-icon-angle-right' />
                <bem.Breadcrumbs__crumb>
                  {subdomainLibraryStore.getCollectionData()?.name || t('Collection')}
                </bem.Breadcrumbs__crumb>
              </React.Fragment>
            )}
          </bem.Breadcrumbs>

          <AssetsTable
            context={AssetsTableContextName.MY_LIBRARY}
            isLoading={this.state.isFetchingData}
            assets={this.state.assets}
            totalAssets={this.state.totalSearchAssets}
            metadata={this.state.metadata}
            orderColumnId={this.state.orderColumnId}
            orderValue={this.state.orderValue || null}
            onOrderChange={this.onAssetsTableOrderChange.bind(this)}
            filterColumnId={this.state.filterColumnId}
            filterValue={this.state.filterValue}
            onFilterChange={this.onAssetsTableFilterChange.bind(this)}
            currentPage={this.state.currentPage}
            totalPages={typeof this.state.totalPages === 'number' ? this.state.totalPages : undefined}
            onSwitchPage={this.onAssetsTableSwitchPage.bind(this)}
            emptyMessage={contextualEmptyMessage}
            showAllTags={this.state.showAllTags}
          />

          <div className='dropzone-active-overlay'>
            <i className='k-icon k-icon-upload' />
            {t('Drop files to upload')}
          </div>
        </Dropzone>
      </DocumentTitle>
    )
  }
}
