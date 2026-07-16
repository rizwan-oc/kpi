import React from 'react'

import bem, { makeBem } from '#/bem'
import sessionStore from '#/stores/session'

bem.GitRev = makeBem(null, 'git-rev')
bem.GitRev__item = makeBem(bem.GitRev, 'item', 'div')

/**
 * Displays some git related information in the UI corner, useful for debugging
 * things.
 */
export default function GitRev() {
  if ('git_rev' in sessionStore.currentAccount && sessionStore.currentAccount.git_rev !== false) {
    const gitRev = sessionStore.currentAccount.git_rev
    return (
      <bem.GitRev>
        {!!gitRev.branch && <bem.GitRev__item>branch: {gitRev.branch}</bem.GitRev__item>}
        {!!gitRev.short && <bem.GitRev__item>commit: {gitRev.short}</bem.GitRev__item>}
        {!!gitRev.tag && <bem.GitRev__item>tag: {gitRev.tag}</bem.GitRev__item>}
      </bem.GitRev>
    )
  }

  return null
}
