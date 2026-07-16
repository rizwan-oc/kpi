import { Center, Group, Loader, Stack, Text, TextInput } from '@mantine/core'
import { useDebouncedValue } from '@mantine/hooks'
import React, { useState, useRef, useEffect } from 'react'
import ReactDOM from 'react-dom'
import type { Asset } from '#/api/models/asset'
import { useAssetsList } from '#/api/react-query/manage-projects-and-library-content'
import Icon from '#/components/common/icon'
import { COMMON_QUERIES } from '#/constants'
import AssetNavigatorCard from './AssetNavigatorCard'

// A stub types for sortable
declare global {
  interface JQuery {
    sortable(options?: any): JQuery
    sortable(
      method: 'destroy' | 'disable' | 'enable' | 'widget' | 'toArray' | 'serialize' | 'refresh' | 'cancel',
      ...args: any[]
    ): JQuery
  }
}

const SORTABLE_ITEM_CLASS_NAME = 'asset-navigator-sortable-item'

export default function AssetNavigator() {
  const [searchQuery, setSearchQuery] = useState('')
  const [debouncedSearch] = useDebouncedValue(searchQuery, 500)
  // OpenClinica fork: library aside panel defaults to expanded (was assetNavExpanded default).
  const [isExpanded] = useState(true)

  // OpenClinica fork: the Tags and Collection filters are intentionally hidden, so the upstream
  // tags/collections fetch + filter state were removed. The assets list below is filtered only by
  // the free-text search box (matching the fork's "search + expand only" library panel).

  // Fetch Main Assets List
  function getAssetsListQuery() {
    const queryParts: string[] = []

    // Include search phrase
    if (debouncedSearch) {
      queryParts.push(`(${debouncedSearch})`)
    }

    // OpenClinica fork: tag/collection filter branches removed along with their (now hidden) controls.

    // Ensure we are only getting library items that make sense here (questions, blocks, and templates)
    queryParts.push(COMMON_QUERIES.qbt)

    return queryParts.join(' AND ')
  }
  const {
    data: assetsResponse,
    isLoading,
    isError,
  } = useAssetsList({
    q: getAssetsListQuery(),
    limit: 200,
    ordering: '-date_modified',
  })

  // Step 4. Setup drag and drop of found assets
  const assetsListRef = useRef<HTMLDivElement>(null)
  useEffect(() => {
    const foundEl = ReactDOM.findDOMNode(assetsListRef.current)
    if (foundEl instanceof Element === false) {
      return
    }

    var $el = $(foundEl)
    if ($el.hasClass('ui-sortable')) {
      $el.sortable('destroy')
    }
    $el.sortable({
      helper: 'clone',
      cursor: 'move',
      distance: 5,
      items: `> .${SORTABLE_ITEM_CLASS_NAME}`,
      connectWith: ['.survey-editor__list', '.group__rows'],
      opacity: 0.9,
      scroll: false,
      deactivate: () => {
        $el.sortable('cancel')
      },
    })
  }, [assetsResponse])

  return (
    <Stack gap='sm' h='100%'>
      {/* Searchbox */}
      <TextInput
        placeholder='Search…'
        leftSection={<Icon name='search' />}
        value={searchQuery}
        onChange={(event) => setSearchQuery(event.currentTarget.value)}
      />

      {/*
        OpenClinica fork: the upstream Tags (MultiSelect) and Collection (Select) filters are
        intentionally omitted here — the library panel must not expose tag-based or
        collection-based filtering, only free-text search and the (always-on) expanded view.
      */}

      {/* Total count. OpenClinica fork: 'items found' terminology + no expand-details toggle (always expanded). */}
      <Group align='center'>
        <Text size='sm' fw={500}>
          {assetsResponse?.data.results?.length || 0} items found
        </Text>
      </Group>

      {/* Results */}
      {isLoading ? (
        <Center py='xl'>
          <Loader size='sm' />
        </Center>
      ) : isError ? (
        <Center py='xl'>
          <Text c='red' size='sm'>
            Error loading assets
          </Text>
        </Center>
      ) : assetsResponse?.data.results?.length === 0 ? (
        <Center py='xl'>
          <Text size='sm'>No items found</Text>
        </Center>
      ) : (
        <Stack gap='xs' ref={assetsListRef}>
          {assetsResponse?.data.results?.map((asset: Asset) => (
            <AssetNavigatorCard
              key={asset.uid}
              asset={asset}
              isExpanded={isExpanded}
              className={SORTABLE_ITEM_CLASS_NAME}
            />
          ))}
        </Stack>
      )}
    </Stack>
  )
}
