import { fireEvent, render } from '@testing-library/react'
import chai from 'chai'
import React from 'react'
import '#/bemComponents'
import type { AssetResponse } from '#/dataInterface'
import pageState from '#/pageState.store'
import { TranslationSettings } from './TranslationSettings'
import { TranslationTable } from './translationTable'

const BANNER_TEXT =
  'You have unsaved changes in the form draft. Save those changes for the best experience managing languages.'

function makeAsset(translations: Array<string | null>): AssetResponse {
  return {
    uid: 'aTestUid001',
    content: {
      survey: [{ type: 'text', name: 'q1', label: translations.map(() => 'Question 1') }],
      choices: [],
      translations,
      translated: ['label'],
      settings: {},
    },
  } as unknown as AssetResponse
}

function hasBanner(container: HTMLElement) {
  return (container.textContent || '').includes(BANNER_TEXT)
}

describe('OC-28841 Manage Languages unsaved draft banner', () => {
  afterEach(() => {
    jest.restoreAllMocks()
  })

  it('shows the banner on the languages list when the draft has unsaved changes', () => {
    const { container } = render(
      <TranslationSettings asset={makeAsset(['English (en)', 'French (fr)'])} hasUnsavedChanges={() => true} />,
    )
    chai.expect(hasBanner(container)).to.equal(true)
  })

  it('hides the banner on the languages list when the draft is saved', () => {
    const { container } = render(
      <TranslationSettings asset={makeAsset(['English (en)', 'French (fr)'])} hasUnsavedChanges={() => false} />,
    )
    chai.expect(hasBanner(container)).to.equal(false)
  })

  it('hides the banner when no unsaved-changes callback is given (opened outside the editor)', () => {
    const { container } = render(<TranslationSettings asset={makeAsset(['English (en)', 'French (fr)'])} />)
    chai.expect(hasBanner(container)).to.equal(false)
  })

  it('shows the banner on the select primary language page', () => {
    const { container } = render(<TranslationSettings asset={makeAsset([null])} hasUnsavedChanges={() => true} />)
    chai.expect(hasBanner(container)).to.equal(true)
  })

  it('keeps only the save-draft message when there are no languages yet', () => {
    const { container } = render(<TranslationSettings asset={makeAsset([])} hasUnsavedChanges={() => true} />)
    chai.expect(container.textContent).to.include('You must save this draft before you can manage languages.')
    chai.expect(hasBanner(container)).to.equal(false)
  })

  it('passes the unsaved-changes callback to the translations table', () => {
    const switchModal = jest.spyOn(pageState, 'switchModal').mockImplementation(() => undefined)
    const hasUnsavedChanges = () => true
    const { getAllByLabelText } = render(
      <TranslationSettings asset={makeAsset(['English (en)', 'French (fr)'])} hasUnsavedChanges={hasUnsavedChanges} />,
    )
    fireEvent.click(getAllByLabelText('Update translations')[0].querySelector('button')!)
    chai.expect(switchModal.mock.calls[0][0].hasUnsavedChanges).to.equal(hasUnsavedChanges)
  })

  it('shows the banner on the translations table when the draft has unsaved changes', () => {
    const { container } = render(
      <TranslationTable
        asset={makeAsset(['English (en)', 'French (fr)'])}
        langIndex={1}
        hasUnsavedChanges={() => true}
      />,
    )
    chai.expect(hasBanner(container)).to.equal(true)
  })

  it('hides the banner on the translations table when the draft is saved', () => {
    const { container } = render(
      <TranslationTable
        asset={makeAsset(['English (en)', 'French (fr)'])}
        langIndex={1}
        hasUnsavedChanges={() => false}
      />,
    )
    chai.expect(hasBanner(container)).to.equal(false)
  })

  it('passes the unsaved-changes callback back to Manage Languages from the translations table', () => {
    const switchModal = jest.spyOn(pageState, 'switchModal').mockImplementation(() => undefined)
    const hasUnsavedChanges = () => true
    const { getByRole } = render(
      <TranslationTable
        asset={makeAsset(['English (en)', 'French (fr)'])}
        langIndex={1}
        hasUnsavedChanges={hasUnsavedChanges}
      />,
    )
    fireEvent.click(getByRole('button', { name: 'Cancel' }))
    chai.expect(switchModal.mock.calls[0][0].hasUnsavedChanges).to.equal(hasUnsavedChanges)
  })
})
