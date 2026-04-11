import Sortable from "sortablejs"

const SortableCards = {
  mounted() {
    this.sortable = null
    this._initSortable()
  },

  updated() {
    this._initSortable()
  },

  destroyed() {
    if (this.sortable) {
      this.sortable.destroy()
      this.sortable = null
    }
  },

  _initSortable() {
    const editing = this.el.dataset.editing === "true"

    if (editing && !this.sortable) {
      this.sortable = Sortable.create(this.el, {
        handle: ".drag-handle",
        animation: 150,
        ghostClass: "opacity-30",
        onEnd: () => {
          const ids = [...this.el.children]
            .filter(el => el.id && el.id.startsWith("card-"))
            .map(el => el.id.replace("card-", ""))

          this.pushEvent("reorder_cards", {ids: ids})
        }
      })
    } else if (!editing && this.sortable) {
      this.sortable.destroy()
      this.sortable = null
    }
  }
}

export {SortableCards}
