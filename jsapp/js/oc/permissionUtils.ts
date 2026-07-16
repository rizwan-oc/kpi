import type { AssetResponse } from '#/dataInterface'
import sessionStore from '#/stores/session'

export function userWithSameSubdomainAsAssetOwner(asset: AssetResponse) {
  const currentUserSubdomain = sessionStore.currentAccount.subdomain
  const ownerUserSubdomain = asset.owner__subdomain
  return currentUserSubdomain === ownerUserSubdomain
}
