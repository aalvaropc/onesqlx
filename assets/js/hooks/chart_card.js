import Chart from "chart.js/auto"

const ChartCard = {
  mounted() { this._renderChart() },
  updated() {
    const newData = this.el.dataset.chartData
    if (newData !== this._lastData) {
      this._chart?.destroy()
      this._chart = null
      this._renderChart()
    }
  },
  destroyed() { this._chart?.destroy() },
  _renderChart() {
    let type = this.el.dataset.chartType
    const raw = this.el.dataset.chartData
    this._lastData = raw
    let data
    try { data = JSON.parse(raw) } catch { return }
    if (!data?.labels?.length) return
    const canvas = this.el.querySelector("canvas")
    if (!canvas) return

    // Area is a line chart with fill
    const isArea = type === "area"
    if (isArea) {
      type = "line"
      data.datasets = data.datasets.map(ds => ({...ds, fill: true}))
    }

    // Pie/doughnut always show legend
    const isPieType = type === "pie" || type === "doughnut"
    const showLegend = isPieType || data.datasets?.length > 1

    const filterField = this.el.dataset.filterField
    const hook = this

    this._chart = new Chart(canvas, {
      type,
      data,
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { display: showLegend } },
        onClick: filterField ? (event, elements) => {
          if (elements.length > 0) {
            const index = elements[0].index
            const label = data.labels[index]
            hook.pushEvent("chart_filter", {field: filterField, value: String(label)})
          }
        } : undefined
      }
    })
  }
}

export { ChartCard }
