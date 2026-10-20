import Chart from "chart.js/auto"

const ChartCard = {
  mounted() {
    this._onThemeChange = () => this._renderChart()
    window.addEventListener("onesqlx:theme-changed", this._onThemeChange)
    this._renderChart()
  },
  updated() {
    if (this.el.dataset.chartData !== this._lastData || this.el.dataset.chartType !== this._lastType) this._renderChart()
  },
  destroyed() {
    window.removeEventListener("onesqlx:theme-changed", this._onThemeChange)
    this._chart?.destroy()
  },
  _renderChart() {
    this._chart?.destroy()
    this._chart = null
    let type = this.el.dataset.chartType
    const raw = this.el.dataset.chartData
    this._lastData = raw
    this._lastType = type
    let data
    try { data = JSON.parse(raw) } catch { return }
    if (!data?.labels?.length) return
    const canvas = this.el.querySelector("canvas")
    if (!canvas) return

    const style = getComputedStyle(document.documentElement)
    const color = name => style.getPropertyValue(name).trim()
    const palette = [1, 2, 3, 4, 5, 6].map(index => color(`--chart-${index}`))
    const isArea = type === "area"
    if (isArea) type = "line"
    const isPie = type === "pie" || type === "doughnut"
    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    const filterField = this.el.dataset.filterField

    data.datasets = data.datasets.map((dataset, index) => ({
      ...dataset,
      backgroundColor: isPie ? data.labels.map((_, item) => palette[item % palette.length]) : isArea ? `${palette[index % palette.length]}26` : palette[index % palette.length],
      borderColor: isPie ? color("--surface") : palette[index % palette.length],
      borderWidth: isPie ? 3 : type === "line" ? 2 : 0,
      borderRadius: type === "bar" ? 4 : undefined,
      pointRadius: 2,
      pointHoverRadius: 5,
      fill: isArea,
      tension: .25
    }))

    this._chart = new Chart(canvas, {
      type,
      data,
      options: {
        responsive: true,
        maintainAspectRatio: false,
        color: color("--muted"),
        font: {family: '"Red Hat Text", sans-serif', size: 10},
        animation: reducedMotion ? false : {duration: 220},
        interaction: {intersect: false, mode: "nearest"},
        plugins: {
          legend: {display: isPie || data.datasets.length > 1, position: "bottom", labels: {color: color("--muted"), usePointStyle: true, pointStyle: "circle", boxWidth: 6, boxHeight: 6, padding: 15, font: {family: '"Red Hat Text", sans-serif', size: 10}}},
          tooltip: {backgroundColor: color("--surface-raised"), titleColor: color("--ink"), bodyColor: color("--muted"), borderColor: color("--line"), borderWidth: 1, padding: 12, cornerRadius: 8, displayColors: true}
        },
        scales: isPie ? {} : {
          x: {grid: {display: false}, border: {display: false}, ticks: {color: color("--muted"), maxRotation: 35, font: {size: 10}}},
          y: {beginAtZero: type === "bar", grid: {color: color("--chart-grid"), drawTicks: false}, border: {display: false}, ticks: {color: color("--muted"), padding: 8, font: {size: 10}}}
        },
        onClick: filterField ? (_event, elements) => {
          if (elements.length) this.pushEvent("chart_filter", {field: filterField, value: String(data.labels[elements[0].index])})
        } : undefined
      }
    })
  }
}

export {ChartCard}
