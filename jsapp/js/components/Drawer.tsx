import React, { lazy, Suspense } from 'react'
import bem from '#/bem'
import Button from '#/components/common/ButtonNew'
import Icon from '#/components/common/icon'
import LibrarySidebar from '#/components/library/librarySidebar'
import pageState from '#/pageState.store'
import RequireAuth from '#/router/requireAuth'
import { ROUTES } from '#/router/routerConstants'
import { MODAL_TYPES } from '../constants'
import { routerIsActive } from '../router/legacy'
import SidebarFormsList from '../sidebar/SidebarFormsList'
import sessionStore from '../stores/session'

const AccountSidebar = lazy(() => import('#/account/accountSidebar'))

/**
 * This components display the left side UI sidebar, namely these parts:
 * - the leftmost narrow sidebar:
 *   - "Projects" button
 *   - "Library" button
 *   - OpenClinica Form Designer help link (not on Library route)
 * - the wider contextual sidebar, showing "new" button and one of these based on current route:
 *   - list of toggleable Deployed/Draft/Archived projects - when viewing project(s) related routes
 *   - "My Library" and "Public Collections" - when viewing library related routes
 *   - links to different routes - when viewing account routes
 */
export default function Drawer() {
  const isAccount = routerIsActive(ROUTES.ACCOUNT_ROOT)
  const isLibrary = routerIsActive(ROUTES.LIBRARY)

  function openNewFormModal(evt: React.MouseEvent<HTMLButtonElement>) {
    evt.preventDefault()
    pageState.showModal({
      type: MODAL_TYPES.NEW_FORM,
    })
  }

  // no sidebar for not logged in users
  if (!sessionStore.isLoggedIn || 'email' in sessionStore.currentAccount === false) {
    return null
  }

  return (
    <bem.KDrawer>
      <bem.KDrawer__sidebar>
        {isLibrary && (
          <bem.FormSidebarWrapper>
            <LibrarySidebar />
          </bem.FormSidebarWrapper>
        )}

        {isAccount && (
          <Suspense fallback={null}>
            <RequireAuth>
              <AccountSidebar />
            </RequireAuth>
          </Suspense>
        )}

        {!isLibrary && !isAccount && (
          <bem.FormSidebarWrapper>
            {/* For CSS flex's sake */}
            <div>
              <Button
                size='lg'
                fullWidth
                variant='filled'
                disabled={!sessionStore.isLoggedIn}
                onClick={openNewFormModal}
              >
                {t('new').toUpperCase()}
              </Button>
            </div>

            <SidebarFormsList />
          </bem.FormSidebarWrapper>
        )}
      </bem.KDrawer__sidebar>

      <bem.KDrawer__secondaryIcons>
        {sessionStore.currentAccount && !isLibrary && (
          <a
            href='https://docs.openclinica.com/oc4/design-study/form-designer'
            className='k-drawer__link'
            target='_blank'
            data-tip={t('Learn more about Form Designer')}
          >
            <Icon name='help' />
          </a>
        )}
      </bem.KDrawer__secondaryIcons>
    </bem.KDrawer>
  )
}
