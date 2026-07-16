import React from 'react'

import assetUtils from '#/assetUtils'
import bem from '#/bem'
import AssetName from '#/components/common/assetName'
import { buildHashHrefWithEConsent } from '#/components/formBuilder/econsentSignature'
import { ASSET_TYPES } from '#/constants'
import type { AssetResponse } from '#/dataInterface'
import { formatTime } from '#/utils'
import AssetActionButtons from './assetActionButtons'
import type { AssetsTableContextName } from './assetsTableConstants'
import './assetTableRow.scss'

interface AssetsTableRowProps {
  asset: AssetResponse
  context: AssetsTableContextName
  showTag?: boolean
}

class AssetsTableRow extends React.Component<AssetsTableRowProps> {
  render() {
    let rowCount = null
    if (this.props.asset.asset_type !== ASSET_TYPES.collection.id && this.props.asset.summary?.row_count) {
      rowCount = this.props.asset.summary.row_count
    } else if (this.props.asset.asset_type === ASSET_TYPES.collection.id && this.props.asset.children) {
      rowCount = this.props.asset.children.count
    }

    let settingsVersion = ''
    if (this.props.asset.summary && this.props.asset.summary.settings_version) {
      settingsVersion = this.props.asset.summary.settings_version
    }

    return (
      <bem.AssetsTableRow m={['asset', `type-${this.props.asset.asset_type}`]}>
        {this.props.asset.asset_type === ASSET_TYPES.collection.id && (
          <bem.AssetsTableRow__link href={buildHashHrefWithEConsent(`#/library/asset/${this.props.asset.uid}`)} />
        )}
        {this.props.asset.asset_type !== ASSET_TYPES.collection.id && (
          <bem.AssetsTableRow__link href={buildHashHrefWithEConsent(`#/library/asset/${this.props.asset.uid}/edit`)} />
        )}

        <bem.AssetsTableRow__column m='name' dir='auto'>
          {rowCount !== null && <bem.AssetsTableRow__tag m='gray-circle row-count'>{rowCount}</bem.AssetsTableRow__tag>}

          <AssetName asset={this.props.asset} />

          {this.props.asset.settings &&
            this.props.asset.tag_string &&
            this.props.asset.tag_string.length > 0 &&
            this.props.showTag && (
              <bem.AssetsTableRow__tags>
                {this.props.asset.tag_string
                  .split(',')
                  .map((tag) => [' ', <bem.AssetsTableRow__tag key={tag}>{tag}</bem.AssetsTableRow__tag>])}
              </bem.AssetsTableRow__tags>
            )}
        </bem.AssetsTableRow__column>

        <bem.AssetsTableRow__column m='item-version'>{settingsVersion}</bem.AssetsTableRow__column>

        <bem.AssetsTableRow__column m='item-type' className='capitalize'>
          {ASSET_TYPES[this.props.asset.asset_type].label}
        </bem.AssetsTableRow__column>

        <bem.AssetsTableRow__column m='owner'>
          {assetUtils.getAssetOwnerDisplayName(this.props.asset.owner_label)}
        </bem.AssetsTableRow__column>

        <bem.AssetsTableRow__column m='date-modified'>
          {formatTime(this.props.asset.date_modified)}
        </bem.AssetsTableRow__column>

        <bem.AssetsTableRow__column
          m='actions'
          className={this.props.asset.asset_type === ASSET_TYPES.collection.id ? '' : 'with-actions-buttons'}
        >
          <AssetActionButtons asset={this.props.asset} />
        </bem.AssetsTableRow__column>
      </bem.AssetsTableRow>
    )
  }
}

export default AssetsTableRow
