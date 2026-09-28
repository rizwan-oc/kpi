/**
 * OC fork — P1.1 Logic Builder "Generate" button bridge (Backbone <-> React).
 *
 * The xlform Form Designer settings drawer is hand-built jQuery/CoffeeScript.
 * This module lets that CoffeeScript imperatively mount the package's
 * `<GenerateButton>` into a given anchor element and, crucially, tear the React
 * root back down when the drawer is cleaned up (`_cleanupExpandedRender`), so
 * we never leak roots on drawer toggle.
 *
 * Clicking the button pushes a `generateRequest` onto the `stores.surveyState`
 * Reflux store; `EditableForm.tsx` reads that to open the shared
 * `<AiGeneratorDialog>`. See `logicBuilderTabs.ts` for the store key + mapping.
 */
import React from 'react'

import { GenerateButton } from '@openclinica/logic-builder'
import { type Root, createRoot } from 'react-dom/client'
import { stores } from '#/stores'
import { GENERATE_REQUEST_KEY, columnToTab } from './logicBuilderTabs'

import '@openclinica/logic-builder/style.css'

const MOUNT_CLASS = 'logic-builder-generate-mount'

interface TrackedRoot {
  mountEl: HTMLElement
  root: Root
}

// Module-level registry of every React root we create, so we can unmount them
// on drawer cleanup (the settings drawer has no unmount hook of its own).
//
// NOTE (PR#273 #8): jsapp/js/formbuild/renderInBackbone.js also mounts React
// into Backbone views (renderKobomatrix), but it does not track or unmount its
// roots (see its own open TODO). This bridge intentionally adds that lifecycle
// management; folding the two into one shared helper is worthwhile follow-up.
const trackedRoots: TrackedRoot[] = []

interface MountOptions {
  // Backbone Row model (xlform).
  row: any
  // xlform RowDetail column name, e.g. 'calculation' | 'relevant' | 'repeat_count'.
  attribute: string
}

/** Accept a raw DOM element or a jQuery-like wrapper and return the DOM node. */
function resolveEl(anchor: unknown): HTMLElement | null {
  if (!anchor) {
    return null
  }
  if (anchor instanceof HTMLElement) {
    return anchor
  }
  const jq = anchor as { get?: (i: number) => HTMLElement; 0?: HTMLElement; length?: number }
  if (typeof jq.get === 'function') {
    return jq.get(0) || null
  }
  if (jq[0] instanceof HTMLElement) {
    return jq[0]
  }
  return null
}

/**
 * Mount a `<GenerateButton>` as a child of `anchor` for the given row+attribute.
 * No-op for unmappable columns or a missing anchor. Returns the mount element.
 */
export function mountGenerateButton(anchor: unknown, options: MountOptions): HTMLElement | null {
  const anchorEl = resolveEl(anchor)
  if (!anchorEl) {
    // A silent no-op here means a Generate button quietly stops appearing if a
    // panel-header template class is ever renamed — leave a trace (PR#273).
    console.warn('Logic Builder: Generate button anchor not found; not mounting', options.attribute)
    return null
  }

  const tab = columnToTab(options.attribute)
  if (!tab) {
    console.warn('Logic Builder: no logic tab maps to attribute; not mounting Generate button', options.attribute)
    return null
  }

  const mountEl = document.createElement('span')
  mountEl.className = MOUNT_CLASS
  // Positioning (right end of every logic panel's heading row, P1.20 AC6) is
  // CSS: `.logic-panel__head > .logic-builder-generate-mount` in
  // _card_settings.scss.
  anchorEl.appendChild(mountEl)

  const root = createRoot(mountEl)
  root.render(
    <GenerateButton
      attribute={tab}
      onOpen={() => {
        // Capture this row's own settings drawer so the host can scope its
        // post-close focus lookup to it — `.closest` stops at the nearest
        // ancestor, i.e. THIS row's `.card__settings`, never a sibling or
        // parent group's (round-5 #2).
        const settingsRoot = anchorEl.closest<HTMLElement>('.card__settings')
        stores.surveyState.setState({
          [GENERATE_REQUEST_KEY]: { row: options.row, attribute: options.attribute, settingsRoot },
        })
      }}
    />,
  )

  trackedRoots.push({ mountEl, root })
  return mountEl
}

/**
 * Unmount every tracked root whose mount element lives inside `scope` (or all of
 * them when `scope` is omitted). Called from the settings-drawer cleanup so React
 * roots don't leak when the drawer is torn down.
 */
export function unmountAll(scope?: unknown): void {
  // Distinguish "no scope requested -> unmount everything" from "a scope was
  // passed but couldn't be resolved". The only caller (_cleanupExpandedRender)
  // always passes a scope, so a failed lookup (e.g. cleanup running after
  // `.card__settings` was detached) must NOT silently escalate to unmounting
  // every Generate-button root on the page — log it and skip this cleanup
  // (PR#273 #4).
  const scopeEl = scope === undefined ? undefined : resolveEl(scope)
  if (scope !== undefined && !scopeEl) {
    console.error('Logic Builder: unmountAll scope element could not be resolved; skipping cleanup', scope)
    return
  }
  for (let i = trackedRoots.length - 1; i >= 0; i -= 1) {
    const tracked = trackedRoots[i]
    const inScope = !scopeEl || scopeEl === tracked.mountEl || scopeEl.contains(tracked.mountEl)
    if (!inScope) {
      continue
    }
    try {
      tracked.root.unmount()
    } catch (e) {
      // Most likely already unmounted / detached — but don't assume that; a
      // real unmount failure should leave a trace rather than vanish (PR#273 #7).
      console.error('Logic Builder: failed to unmount a Generate-button root', e)
    }
    tracked.mountEl.remove()
    trackedRoots.splice(i, 1)
  }
}
