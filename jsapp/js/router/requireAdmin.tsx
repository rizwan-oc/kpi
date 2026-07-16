import sessionStore from 'js/stores/session'
import React, { type ReactElement, type ReactNode, Suspense, useState } from 'react'
import type { RouteObject } from 'react-router-dom'
import AccessDenied from './accessDenied'

interface Props {
  children: RouteObject[] | undefined | ReactElement
}

/** https://gist.github.com/mjackson/d54b40a094277b7afdd6b81f51a0393f */
export default function RequireAdmin({ children }: Props) {
  const [session] = useState(() => sessionStore)
  return session.currentAccount.user_type.toLowerCase() == 'user' ? (
    <AccessDenied />
  ) : (
    <Suspense fallback={null}>{children as ReactNode}</Suspense>
  )
}
