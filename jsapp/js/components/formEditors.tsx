import React from 'react'
import { ASSET_TYPES, type AssetTypeName } from '#/constants'
import { type WithRouterProps, withRouter } from '#/router/legacy'
import { ROUTES } from '#/router/routerConstants'
import EditableForm from '../editorMixins/EditableForm'

/**
 * These are the components that are used for Form Builder routes.
 */

export class FormPage extends React.Component<WithRouterProps & { params: { uid?: string } }> {
  render() {
    return (
      <EditableForm
        router={this.props.router}
        isNewAsset={false}
        assetUid={this.props.params.uid}
        backRoute={ROUTES.FORMS}
      />
    )
  }
}

class LibraryAssetEditorComponent extends React.Component<WithRouterProps & { params: { uid?: string } }> {
  render() {
    let isNewAsset = true
    if (this.props.router.path === ROUTES.EDIT_LIBRARY_ITEM) {
      isNewAsset = false
    }

    let parentAssetUid: string | undefined
    if (this.props.router.path === ROUTES.NEW_LIBRARY_CHILD) {
      parentAssetUid = this.props.params.uid
    }

    // OC fork: the dedicated "Create Template" routes mark the new asset's
    // type as `template` so EditableForm sends `asset_type: template` on
    // create (otherwise it falls through to `block`).
    let desiredAssetType: AssetTypeName | undefined
    if (
      this.props.router.path === ROUTES.NEW_LIBRARY_TEMPLATE_ITEM ||
      this.props.router.path === ROUTES.NEW_LIBRARY_TEMPLATE_ITEM_CHILD
    ) {
      desiredAssetType = ASSET_TYPES.template.id
    }
    if (this.props.router.path === ROUTES.NEW_LIBRARY_TEMPLATE_ITEM_CHILD) {
      parentAssetUid = this.props.params.uid
    }

    // OC fork UX override: creating a child asset (incl. the template-child
    // route) returns to the top-level library rather than the parent
    // collection. Upstream reverted this to LIBRARY_ITEM.
    let backRoute: string | null = ROUTES.LIBRARY
    if (
      this.props.router.path === ROUTES.NEW_LIBRARY_CHILD ||
      this.props.router.path === ROUTES.NEW_LIBRARY_TEMPLATE_ITEM_CHILD
    ) {
      backRoute = ROUTES.LIBRARY
    }
    if (this.props.router.searchParams.get('back')) {
      backRoute = this.props.router.searchParams.get('back')
    }

    return (
      <EditableForm
        router={this.props.router}
        isNewAsset={isNewAsset}
        assetUid={this.props.params.uid}
        backRoute={backRoute}
        parentAssetUid={parentAssetUid}
        desiredAssetType={desiredAssetType}
      />
    )
  }
}

export const LibraryAssetEditor = withRouter(LibraryAssetEditorComponent)
