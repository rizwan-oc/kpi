// OC: Entirely OC-added store (no upstream equivalent). Persists the library asset-type filter (All / Block / Question / Template / Collection) in sessionStorage.
import Reflux from 'reflux'

import { getLibraryFilterCacheName } from '#/oc/utils'

const DEFAULT_FILTER = { value: 'all', label: t('Show All') }

interface LibraryTypeFilterStoreData {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  filterType: any
}

class LibraryTypeFilterStore extends Reflux.Store {
  data: LibraryTypeFilterStoreData = {
    filterType: DEFAULT_FILTER,
  }

  init() {
    this.resetFilter()
  }

  getFilterType() {
    return this.data.filterType
  }

  setFilterType(newVal: string) {
    if (this.data.filterType !== newVal) {
      this.data.filterType = newVal
      sessionStorage.setItem(getLibraryFilterCacheName(), JSON.stringify(this.data.filterType))
      this.trigger(this.data)
    }
  }

  resetFilter() {
    const filterType = sessionStorage.getItem(getLibraryFilterCacheName())
    if (filterType) {
      this.data.filterType = JSON.parse(filterType)
    } else {
      this.data.filterType = DEFAULT_FILTER
    }
    this.trigger(this.data)
  }
}

const libraryTypeFilterStore = new LibraryTypeFilterStore()
libraryTypeFilterStore.init()

export default libraryTypeFilterStore
