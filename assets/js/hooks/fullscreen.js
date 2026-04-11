const Fullscreen = {
  mounted() {
    this.el.addEventListener("click", () => {
      if (document.fullscreenElement) {
        document.exitFullscreen()
      } else {
        document.documentElement.requestFullscreen()
      }
    })

    document.addEventListener("fullscreenchange", () => {
      const isFullscreen = !!document.fullscreenElement
      this.el.dataset.fullscreen = isFullscreen
      this.el.textContent = isFullscreen ? "Exit Fullscreen" : "Fullscreen"
    })
  }
}

export { Fullscreen }
