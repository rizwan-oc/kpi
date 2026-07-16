import type { AssetContentSettings, AssetResponse } from '#/dataInterface'
import type { Asset } from './api/models/asset'

export function parseTags(asset: Asset | AssetResponse) {
  return {
    tags: asset.tag_string?.split(',').filter((tg) => tg.length !== 0) || [],
  }
}

function parseSettings(asset: AssetResponse) {
  const settings = asset.content && asset.content.settings
  if (settings) {
    let foundSettings: AssetContentSettings = {}
    if (Array.isArray(settings) && settings.length) {
      foundSettings = settings[0]
    } else {
      foundSettings = settings as AssetContentSettings
    }
    return {
      unparsed__settings: foundSettings,
      settings__title: foundSettings.title,
      settings__style: foundSettings.style !== undefined ? foundSettings.style : '',
      settings__form_id:
        foundSettings.form_id !== undefined
          ? foundSettings.form_id
          : foundSettings.id_string !== undefined
            ? foundSettings.id_string
            : '',
      settings__version: foundSettings.version !== undefined ? foundSettings.version : '',
    }
  } else {
    return {}
  }
}

export function parsed(asset: AssetResponse): AssetResponse {
  return Object.assign(asset, parseSettings(asset), parseTags(asset)) as AssetResponse
}
