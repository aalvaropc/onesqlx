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
    const type = this.el.dataset.chartType
    const raw = this.el.dataset.chartData
    this._lastData = raw
    let data
    try { data = JSON.parse(raw) } catch { return }
    if (!data?.labels?.length) return
    const canvas = this.el.querySelector("canvas")
    if (!canvas) return
    this._chart = new Chart(canvas, {
      type,
      data,
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { display: data.datasets?.length > 1 } }
      }
    })
  }
}

export { ChartCard }
