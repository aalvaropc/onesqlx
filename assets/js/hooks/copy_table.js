const CopyTable = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      const cell = e.target.closest("td[data-copy]")
      if (cell) {
        navigator.clipboard.writeText(cell.dataset.copy)
        this._flash(cell, "Copied!")
        return
      }

      const rowBtn = e.target.closest("[data-copy-row]")
      if (rowBtn) {
        const row = rowBtn.closest("tr")
        if (row) {
          const cells = [...row.querySelectorAll("td[data-copy]")]
          const text = cells.map(td => td.dataset.copy).join("\t")
          navigator.clipboard.writeText(text)
          this._flash(rowBtn, "Row copied!")
        }
      }
    })
  },

  _flash(el, msg) {
    const tooltip = document.createElement("span")
    tooltip.textContent = msg
    tooltip.className = "absolute -top-6 left-1/2 -translate-x-1/2 text-xs bg-base-300 px-2 py-0.5 rounded shadow whitespace-nowrap z-10"
    el.classList.add("relative")
    el.appendChild(tooltip)
    setTimeout(() => tooltip.remove(), 1000)
  }
}

export { CopyTable }
