import {EditorState, Compartment} from "@codemirror/state"
import {EditorView, keymap} from "@codemirror/view"
import {basicSetup} from "codemirror"
import {sql, PostgreSQL} from "@codemirror/lang-sql"
import {autocompletion} from "@codemirror/autocomplete"
import {oneDark} from "@codemirror/theme-one-dark"

const SqlEditor = {
  mounted() {
    this.sqlCompartment = new Compartment()
    this.themeCompartment = new Compartment()
    this.debounceTimer = null

    const isDark = document.documentElement.getAttribute("data-theme") === "dark" ||
      (!document.documentElement.getAttribute("data-theme") &&
       window.matchMedia("(prefers-color-scheme: dark)").matches)

    const runKeymap = keymap.of([{
      key: "Ctrl-Enter",
      mac: "Cmd-Enter",
      run: () => {
        this.pushEvent("execute", {})
        return true
      }
    }])

    const updateListener = EditorView.updateListener.of((update) => {
      if (update.docChanged) {
        clearTimeout(this.debounceTimer)
        this.debounceTimer = setTimeout(() => {
          const doc = update.state.doc.toString()
          this.pushEvent("update_sql", {sql: doc})
        }, 300)
      }
    })

    this.editor = new EditorView({
      state: EditorState.create({
        doc: "",
        extensions: [
          basicSetup,
          this.sqlCompartment.of(sql({dialect: PostgreSQL})),
          autocompletion(),
          this.themeCompartment.of(isDark ? oneDark : []),
          runKeymap,
          updateListener,
          EditorView.theme({
            "&": {height: "100%"},
            ".cm-scroller": {overflow: "auto"},
          }),
        ]
      }),
      parent: this.el
    })

    this.handleEvent("set_catalog", ({schema}) => {
      this.editor.dispatch({
        effects: this.sqlCompartment.reconfigure(
          sql({dialect: PostgreSQL, schema: schema})
        )
      })
    })

    this.handleEvent("set_sql", ({sql: newSql}) => {
      this.editor.dispatch({
        changes: {
          from: 0,
          to: this.editor.state.doc.length,
          insert: newSql
        }
      })
    })

    // Observe theme changes
    this.themeObserver = new MutationObserver(() => {
      const theme = document.documentElement.getAttribute("data-theme")
      const dark = theme === "dark" ||
        (!theme && window.matchMedia("(prefers-color-scheme: dark)").matches)
      this.editor.dispatch({
        effects: this.themeCompartment.reconfigure(dark ? oneDark : [])
      })
    })
    this.themeObserver.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["data-theme"]
    })
  },

  destroyed() {
    clearTimeout(this.debounceTimer)
    if (this.themeObserver) this.themeObserver.disconnect()
    if (this.editor) this.editor.destroy()
  }
}

export {SqlEditor}
