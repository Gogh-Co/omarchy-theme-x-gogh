import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui
import "GoghThemeSearch.js" as GoghThemeSearch

Item {
  id: root

  property string pluginDir: Quickshell.env("HOME") + "/.config/omarchy/plugins/mgldvd.gogh-themes"
  property string configPath: Quickshell.env("HOME") + "/.config/gogh-themes/config.json"
  property var shell: null
  property var manifest: null

  property bool opened: false
  property string filterText: ""
  property string variantFilter: "all" // "all" | "light" | "dark"
  property bool favoritesOnly: false
  property var favorites: ({}) // themeName -> true, persisted to configPath
  property bool historyOnly: false
  property var history: [] // theme names, most recent first, persisted
  property bool settingsOpen: false
  // enabled: bool, intervalMinutes: int, source: "all"|"favorites",
  // order: "sequential"|"random", lastAppliedName: string -- persisted
  property var rotation: ({ enabled: false, intervalMinutes: 30, source: "all", order: "sequential", lastAppliedName: "" })
  property bool silent: false // suppress the "installed and applied" notification
  property double snoozeUntilMs: 0 // runtime-only, not persisted
  readonly property bool isSnoozed: root.snoozeUntilMs > 0
  property int selectedIndex: 0
  property bool cursorActive: false
  property bool loading: false
  property bool loaded: false
  property var allThemes: []
  property var filteredThemes: []
  property string installingName: ""
  // Omarchy's active theme dir name, e.g. "gogh-dracula" or "tokyo-night".
  property string activeThemeSlug: ""
  readonly property var activeTheme: GoghThemeSearch.findBySlug(root.allThemes, root.activeThemeSlug)
  readonly property string activeThemeName: root.activeTheme
    ? root.activeTheme.name
    : GoghThemeSearch.prettyThemeSlug(root.activeThemeSlug)

  // Shares the [menu] surface tokens so this picker always matches whatever
  // Omarchy theme (Gogh-installed or not) is currently active.
  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  property color selectedBackground: Color.menu.selectedBackground
  property color selectedText: Color.menu.selectedText
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily
  property int contentMargin: Style.spacing.panelPadding
  property int headerHeight: Math.max(Style.space(34), Style.font.title + Style.spacing.controlPaddingY * 2)
  property int filterBarHeight: Style.space(30)
  property int contentSpacing: Style.spacing.md
  // Wide enough to fit several columns on a normal monitor; still shrinks to
  // fit narrower screens via the panel.width clamp below.
  property int cardWidth: Math.min(Style.space(920), panel.width - Style.gapsOut * 2)
  property int cardHeight: Math.min(Style.space(600), panel.height - Style.gapsOut * 2)
  property int minCellWidth: Style.space(220)
  property int cellHeight: Style.space(88)
  // Derived from the grid's own rendered width (not an estimate of the card
  // minus padding) so columns * cellWidth always equals the real available
  // width exactly -- no leftover sliver on the right edge.
  readonly property int columns: Math.max(1, Math.floor(resultGrid.width / root.minCellWidth))
  readonly property real cellWidth: resultGrid.width > 0 ? resultGrid.width / root.columns : root.minCellWidth
  property int swatchSize: Style.space(10)
  property int swatchSpacing: Style.space(3)
  property int avatarSize: Style.space(28)
  // Fixed width for a cell's content block (avatar+name row, and the dot
  // grid) independent of the actual cell width, so name eliding stays
  // consistent across any column count.
  property int nameTextWidth: Style.space(140)
  readonly property int contentBlockWidth: root.avatarSize + Style.space(8) + root.nameTextWidth

  Component.onCompleted: root.ensureLoaded()

  function open(payloadJson) {
    root.opened = true
    root.filterText = ""
    root.settingsOpen = false
    root.selectedIndex = 0
    root.cursorActive = true
    root.ensureLoaded()
    root.rebuildDisplay()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "mgldvd.gogh-themes")
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  function ensureLoaded() {
    if (root.loaded || loadThemesProc.running) return
    root.loading = true
    loadThemesProc.command = [root.pluginDir + "/bin/gogh-list-json.sh"]
    loadThemesProc.running = true
  }

  function onThemesLoaded(raw) {
    root.allThemes = GoghThemeSearch.parseThemes(raw)
    root.loading = false
    root.loaded = true
    if (root.opened) root.rebuildDisplay()
  }

  function rebuildDisplay() {
    var base = GoghThemeSearch.filterThemes(root.allThemes, root.filterText, root.variantFilter, root.allThemes.length)

    if (root.historyOnly) {
      var byName = {}
      for (var i = 0; i < base.length; i++) byName[base[i].name] = base[i]
      var ordered = []
      for (var j = 0; j < root.history.length; j++) {
        if (byName[root.history[j]]) ordered.push(byName[root.history[j]])
      }
      root.filteredThemes = ordered
    } else if (root.favoritesOnly) {
      root.filteredThemes = base.filter(function(t) { return !!root.favorites[t.name] })
    } else {
      root.filteredThemes = base
    }

    if (root.filteredThemes.length === 0) selectedIndex = 0
    else if (selectedIndex >= root.filteredThemes.length) selectedIndex = root.filteredThemes.length - 1
    else if (selectedIndex < 0) selectedIndex = 0
    cursorActive = root.filteredThemes.length > 0

    Qt.callLater(function() {
      if (root.filteredThemes.length > 0) resultGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
    })
  }

  // Left / right: move one cell.
  function select(delta) {
    if (root.filteredThemes.length === 0) return
    if (!cursorActive) {
      cursorActive = true
      selectedIndex = delta < 0 ? root.filteredThemes.length - 1 : 0
    } else {
      selectedIndex = (selectedIndex + delta + root.filteredThemes.length) % root.filteredThemes.length
    }
    resultGrid.positionViewAtIndex(selectedIndex, GridView.Contain)
  }

  // Up / down: move one row (a full line of columns).
  function selectRow(delta) {
    if (root.filteredThemes.length === 0) return
    if (!cursorActive) {
      cursorActive = true
      selectedIndex = delta < 0 ? root.filteredThemes.length - 1 : 0
      resultGrid.positionViewAtIndex(selectedIndex, GridView.Contain)
      return
    }
    var newIndex = selectedIndex + delta * root.columns
    if (newIndex < 0) newIndex = 0
    if (newIndex >= root.filteredThemes.length) newIndex = root.filteredThemes.length - 1
    selectedIndex = newIndex
    resultGrid.positionViewAtIndex(selectedIndex, GridView.Contain)
  }

  function selectPage(delta) {
    if (root.filteredThemes.length === 0) return
    var visibleRows = Math.max(1, Math.floor(resultGrid.height / root.cellHeight))
    var newIndex = selectedIndex + delta * root.columns * visibleRows
    if (newIndex < 0) newIndex = 0
    if (newIndex >= root.filteredThemes.length) newIndex = root.filteredThemes.length - 1
    selectedIndex = newIndex
    cursorActive = true
    resultGrid.positionViewAtIndex(selectedIndex, GridView.Contain)
  }

  function setFilter(nextFilter) {
    root.filterText = nextFilter
    root.selectedIndex = 0
    root.cursorActive = true
    root.rebuildDisplay()
  }

  function setVariantFilter(nextVariant) {
    if (root.variantFilter === nextVariant) return
    root.variantFilter = nextVariant
    root.selectedIndex = 0
    root.cursorActive = true
    root.rebuildDisplay()
  }

  function cycleVariantFilter() {
    var order = ["all", "light", "dark"]
    var idx = order.indexOf(root.variantFilter)
    root.setVariantFilter(order[(idx + 1) % order.length])
  }

  function defaultRotation() {
    return { enabled: false, intervalMinutes: 30, source: "all", order: "sequential", lastAppliedName: "" }
  }

  function applyConfig(raw) {
    try {
      var cfg = JSON.parse(String(raw || "{}"))
      root.favorites = (cfg.favorites && typeof cfg.favorites === "object") ? cfg.favorites : {}
      root.history = Array.isArray(cfg.history) ? cfg.history : []
      root.silent = cfg.silent === true
      var r = (cfg.rotation && typeof cfg.rotation === "object") ? cfg.rotation : {}
      root.rotation = {
        enabled: r.enabled === true,
        intervalMinutes: (typeof r.intervalMinutes === "number" && r.intervalMinutes > 0) ? r.intervalMinutes : 30,
        source: r.source === "favorites" ? "favorites" : "all",
        order: r.order === "random" ? "random" : "sequential",
        lastAppliedName: typeof r.lastAppliedName === "string" ? r.lastAppliedName : ""
      }
    } catch (e) {
      root.favorites = {}
      root.history = []
      root.silent = false
      root.rotation = root.defaultRotation()
    }
    if (root.opened) root.rebuildDisplay()
  }

  function toggleSilent() {
    root.silent = !root.silent
    Quickshell.execDetached([root.pluginDir + "/bin/gogh-silent-set", root.silent ? "true" : "false"])
  }

  function isFavorite(name) {
    return !!(name && root.favorites[name])
  }

  function toggleFavorite(name) {
    if (!name) return
    var wasFavorite = root.isFavorite(name)
    var next = {}
    for (var key in root.favorites) next[key] = root.favorites[key]
    if (wasFavorite) delete next[name]
    else next[name] = true
    root.favorites = next
    Quickshell.execDetached([root.pluginDir + "/bin/gogh-favorite-set", name, wasFavorite ? "false" : "true"])
    if (root.favoritesOnly) root.rebuildDisplay()
  }

  function toggleFavoritesOnly() {
    root.favoritesOnly = !root.favoritesOnly
    if (root.favoritesOnly) root.historyOnly = false
    root.selectedIndex = 0
    root.cursorActive = true
    root.rebuildDisplay()
  }

  function toggleHistoryOnly() {
    root.historyOnly = !root.historyOnly
    if (root.historyOnly) root.favoritesOnly = false
    root.selectedIndex = 0
    root.cursorActive = true
    root.rebuildDisplay()
  }

  function clearFavorites() {
    root.favorites = {}
    Quickshell.execDetached([root.pluginDir + "/bin/gogh-favorite-clear"])
    if (root.favoritesOnly) root.rebuildDisplay()
  }

  function pushHistory(name) {
    if (!name) return
    var next = [name]
    for (var i = 0; i < root.history.length; i++) {
      if (root.history[i] !== name) next.push(root.history[i])
    }
    if (next.length > 8) next = next.slice(0, 8)
    root.history = next
    Quickshell.execDetached([root.pluginDir + "/bin/gogh-history-push", name])
    if (root.historyOnly) root.rebuildDisplay()
  }

  function snoozeRotation() {
    root.snoozeUntilMs = Date.now() + 60 * 60 * 1000
  }

  function clearSnooze() {
    root.snoozeUntilMs = 0
  }

  function setRotationField(field, value) {
    var next = {}
    for (var k in root.rotation) next[k] = root.rotation[k]
    next[field] = value
    root.rotation = next
    Quickshell.execDetached([root.pluginDir + "/bin/gogh-rotation-set", field, String(value)])
  }

  function promptRotationInterval() {
    if (intervalPromptProc.running) return
    intervalPromptProc.running = true
  }

  function promptExportConfig() {
    // Always exports to a fixed, predictable filename -- no prompt needed.
    Quickshell.execDetached([root.pluginDir + "/bin/gogh-config-export"])
  }

  function promptImportConfig() {
    if (importPromptProc.running) return
    importPromptProc.running = true
  }

  function rotationPool() {
    if (root.rotation.source === "favorites")
      return root.allThemes.filter(function(t) { return root.isFavorite(t.name) })
    return root.allThemes
  }

  function pickRotationTheme() {
    var pool = root.rotationPool()
    if (pool.length === 0) return null

    if (root.rotation.order === "random") {
      if (pool.length === 1) return pool[0]
      var pick
      do {
        pick = pool[Math.floor(Math.random() * pool.length)]
      } while (pick.name === root.rotation.lastAppliedName)
      return pick
    }

    var lastIdx = -1
    for (var i = 0; i < pool.length; i++) {
      if (pool[i].name === root.rotation.lastAppliedName) { lastIdx = i; break }
    }
    return pool[(lastIdx + 1) % pool.length]
  }

  function runRotationTick() {
    var theme = root.pickRotationTheme()
    if (!theme) return
    root.setRotationField("lastAppliedName", theme.name)
    root.pushHistory(theme.name)
    Quickshell.execDetached([root.pluginDir + "/bin/gogh-theme-install", theme.name])
  }

  function activateIndex(index) {
    if (index < 0 || index >= root.filteredThemes.length) return
    root.applySelected(root.filteredThemes[index])
  }

  function applySelected(themeData) {
    if (!themeData || !themeData.name) return
    root.installingName = themeData.name
    root.pushHistory(themeData.name)
    root.dismiss()
    Quickshell.execDetached([root.pluginDir + "/bin/gogh-theme-install", themeData.name])
  }

  FileView {
    id: configFile
    path: root.configPath
    watchChanges: true
    printErrors: false
    onLoaded: root.applyConfig(text())
    onLoadFailed: {
      root.favorites = {}
      root.history = []
      root.silent = false
      root.rotation = root.defaultRotation()
    }
    onFileChanged: reload()
  }

  FileView {
    id: activeThemeFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme.name"
    watchChanges: true
    printErrors: false
    onLoaded: root.activeThemeSlug = String(text() || "").trim()
    onLoadFailed: root.activeThemeSlug = ""
    onFileChanged: reload()
  }

  Process {
    id: loadThemesProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.onThemesLoaded(text)
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.loading = false
        root.loaded = true
      }
    }
  }

  // Runs regardless of whether the picker overlay is currently open --
  // the plugin's root Item is keepLoaded so this keeps ticking in the
  // background for as long as the shell is running.
  Timer {
    id: rotationTimer
    interval: Math.max(1, root.rotation.intervalMinutes) * 60 * 1000
    running: root.rotation.enabled && root.loaded && !root.isSnoozed
    repeat: true
    onTriggered: root.runRotationTick()
  }

  // Lightweight heartbeat, only alive while snoozed, that clears the
  // snooze once its deadline passes (snoozeUntilMs -> 0 re-arms rotationTimer).
  Timer {
    interval: 10000
    running: root.isSnoozed
    repeat: true
    onTriggered: {
      if (Date.now() >= root.snoozeUntilMs) root.snoozeUntilMs = 0
    }
  }

  Process {
    id: intervalPromptProc
    command: ["omarchy-menu-input", "Minutes between auto theme changes"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var n = parseInt(String(text || "").trim(), 10)
        if (!isNaN(n) && n > 0) root.setRotationField("intervalMinutes", n)
      }
    }
  }

  Process {
    id: importPromptProc
    command: ["omarchy-menu-input", "Import config from (e.g. ~/.config/gogh/config-gogh.yml)"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var path = String(text || "").trim()
        if (path) Quickshell.execDetached([root.pluginDir + "/bin/gogh-config-import", path])
      }
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "gogh-themes"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            if (root.settingsOpen) root.settingsOpen = false
            else if (root.filterText) root.setFilter("")
            else root.dismiss()
            event.accepted = true
          } else if (Util.editsFilter(event, root.filterText)) {
            root.setFilter(Util.editedFilter(event, root.filterText))
            event.accepted = true
          } else if (event.key === Qt.Key_Left) {
            root.select(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_Right) {
            root.select(1)
            event.accepted = true
          } else if (event.key === Qt.Key_Up) {
            root.selectRow(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_Down) {
            root.selectRow(1)
            event.accepted = true
          } else if (event.key === Qt.Key_PageUp) {
            root.selectPage(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_PageDown) {
            root.selectPage(1)
            event.accepted = true
          } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            root.cycleVariantFilter()
            event.accepted = true
          } else if (event.key === Qt.Key_D && (event.modifiers & Qt.ControlModifier)) {
            if (root.cursorActive && root.selectedIndex >= 0 && root.selectedIndex < root.filteredThemes.length)
              root.toggleFavorite(root.filteredThemes[root.selectedIndex].name)
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.cursorActive) root.activateIndex(root.selectedIndex)
            else if (root.filteredThemes.length > 0) root.cursorActive = true
            event.accepted = true
          } else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127) {
            root.setFilter(root.filterText + event.text)
            event.accepted = true
          }
        }

        Column {
          anchors.fill: parent
          anchors.topMargin: card.contentTopInset
          anchors.rightMargin: card.contentRightInset
          anchors.bottomMargin: card.contentBottomInset
          anchors.leftMargin: card.contentLeftInset
          spacing: root.contentSpacing

          Rectangle {
            width: parent.width
            height: root.headerHeight
            radius: root.cornerRadius
            color: "transparent"

            Text {
              textFormat: Text.PlainText
              anchors.left: parent.left
              anchors.right: activeLabel.left
              anchors.rightMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              text: root.filterText || "Search Gogh themes…"
              color: root.foreground
              opacity: root.filterText ? 1 : 0.58
              font.family: root.fontFamily
              font.pixelSize: Style.font.heading
              elide: Text.ElideRight
            }

            Text {
              id: activeLabel
              visible: root.activeThemeName !== ""
              textFormat: Text.PlainText
              anchors.right: countBadge.left
              anchors.rightMargin: visible ? Style.space(14) : 0
              anchors.verticalCenter: parent.verticalCenter
              width: visible ? Math.min(implicitWidth, parent.width * 0.4) : 0
              text: "● Active: " + root.activeThemeName
              color: root.foreground
              opacity: 0.7
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
            }

            Text {
              id: countBadge
              textFormat: Text.PlainText
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: root.loading ? "…"
                : (root.filteredThemes.length === root.allThemes.length
                  ? root.allThemes.length + " themes"
                  : root.filteredThemes.length + " of " + root.allThemes.length + " themes")
              color: root.foreground
              opacity: 0.45
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }

          Item {
            id: filterBar
            width: parent.width
            height: root.filterBarHeight

            Row {
              id: variantFilterRow
              anchors.left: parent.left
              height: root.filterBarHeight
              spacing: Style.space(6)
              // Hidden while the Rotation panel is open: this bar is not a
              // theme-browsing view anymore, so its filters don't apply --
              // hiding them makes the mode switch unmistakable at a glance.
              visible: !root.settingsOpen

              Repeater {
                model: [
                  { key: "all", label: "All" },
                  { key: "light", label: "Light" },
                  { key: "dark", label: "Dark" }
                ]

                delegate: Rectangle {
                  id: pill
                  required property var modelData

                  readonly property bool active: root.variantFilter === modelData.key

                  height: root.filterBarHeight
                  width: pillLabel.implicitWidth + Style.space(20)
                  radius: root.cornerRadius
                  color: active ? root.selectedBackground : "transparent"
                  border.width: 1
                  border.color: active ? "transparent" : Util.alpha(root.foreground, 0.25)

                  Text {
                    id: pillLabel
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: pill.modelData.label
                    color: pill.active ? root.selectedText : root.foreground
                    opacity: pill.active ? 1 : 0.75
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    font.weight: pill.active ? Font.DemiBold : Font.Normal
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.setVariantFilter(pill.modelData.key)
                  }
                }
              }
            }

            Rectangle {
              id: settingsToggle
              anchors.right: parent.right
              height: root.filterBarHeight
              width: root.filterBarHeight
              radius: root.cornerRadius
              color: root.settingsOpen ? root.selectedBackground : "transparent"
              border.width: 1
              border.color: root.settingsOpen ? "transparent" : Util.alpha(root.foreground, 0.25)

              Text {
                id: settingsLabel
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: "⚙"
                color: root.settingsOpen ? root.selectedText : root.foreground
                opacity: root.settingsOpen ? 1 : 0.75
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.weight: root.settingsOpen ? Font.DemiBold : Font.Normal
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.settingsOpen = !root.settingsOpen
              }
            }

            Rectangle {
              id: favToggle
              visible: !root.settingsOpen
              anchors.right: historyToggle.left
              anchors.rightMargin: Style.space(6)
              height: root.filterBarHeight
              width: favLabel.implicitWidth + Style.space(20)
              radius: root.cornerRadius
              color: root.favoritesOnly ? root.selectedBackground : "transparent"
              border.width: 1
              border.color: root.favoritesOnly ? "transparent" : Util.alpha(root.foreground, 0.25)

              Text {
                id: favLabel
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: "★ Favorites"
                color: root.favoritesOnly ? root.selectedText : root.foreground
                opacity: root.favoritesOnly ? 1 : 0.75
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.weight: root.favoritesOnly ? Font.DemiBold : Font.Normal
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleFavoritesOnly()
              }
            }

            Rectangle {
              id: historyToggle
              visible: !root.settingsOpen
              anchors.right: settingsToggle.left
              anchors.rightMargin: Style.space(6)
              height: root.filterBarHeight
              width: historyLabel.implicitWidth + Style.space(20)
              radius: root.cornerRadius
              color: root.historyOnly ? root.selectedBackground : "transparent"
              border.width: 1
              border.color: root.historyOnly ? "transparent" : Util.alpha(root.foreground, 0.25)

              Text {
                id: historyLabel
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: "Recent"
                color: root.historyOnly ? root.selectedText : root.foreground
                opacity: root.historyOnly ? 1 : 0.75
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.weight: root.historyOnly ? Font.DemiBold : Font.Normal
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleHistoryOnly()
              }
            }
          }

          Item {
            width: parent.width
            height: parent.height - root.headerHeight - root.filterBarHeight - root.contentSpacing * 2

            GridView {
              id: resultGrid
              anchors.fill: parent
              visible: !root.settingsOpen && !root.loading && root.filteredThemes.length > 0
              clip: true
              boundsBehavior: Flickable.StopAtBounds
              cellWidth: root.cellWidth
              cellHeight: root.cellHeight
              model: root.filteredThemes.length

              delegate: BorderSurface {
                id: cell
                required property int index

                readonly property var themeData: root.filteredThemes[index]
                readonly property bool hasCursor: root.cursorActive && index === root.selectedIndex
                readonly property bool isFavorite: themeData ? root.isFavorite(themeData.name) : false
                readonly property bool isActive: !!themeData && !!root.activeTheme && themeData.name === root.activeTheme.name
                property bool cellHovered: false

                width: root.cellWidth - Style.space(4)
                height: root.cellHeight - Style.space(4)
                radius: root.cornerRadius
                color: hasCursor ? root.selectedBackground : "transparent"
                borderSpec: Border.none()

                Column {
                  id: contentBlock
                  width: root.contentBlockWidth
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(8)
                  spacing: Style.space(8)

                  Row {
                    width: parent.width
                    spacing: Style.space(8)

                    Rectangle {
                      width: root.avatarSize
                      height: root.avatarSize
                      radius: Style.space(7)
                      anchors.verticalCenter: parent.verticalCenter
                      color: cell.themeData ? cell.themeData.background : "transparent"
                      border.width: 1
                      border.color: Util.alpha(cell.hasCursor ? root.selectedText : root.foreground, 0.18)

                      Text {
                        anchors.centerIn: parent
                        textFormat: Text.PlainText
                        text: "Aa"
                        color: cell.themeData ? cell.themeData.foreground : root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        font.weight: Font.DemiBold
                      }
                    }

                    Text {
                      width: parent.width - root.avatarSize - parent.spacing
                      anchors.verticalCenter: parent.verticalCenter
                      textFormat: Text.PlainText
                      text: cell.themeData ? cell.themeData.name : ""
                      color: cell.hasCursor ? root.selectedText : root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      font.weight: Font.Medium
                      elide: Text.ElideRight
                    }
                  }

                  Grid {
                    id: swatchGrid
                    columns: 8
                    rows: 2
                    spacing: root.swatchSpacing

                    Repeater {
                      model: cell.themeData ? cell.themeData.colors : []
                      delegate: Rectangle {
                        required property var modelData
                        width: root.swatchSize
                        height: root.swatchSize
                        radius: Style.space(3)
                        color: modelData
                        border.width: 1
                        border.color: Qt.rgba(0, 0, 0, 0.16)
                      }
                    }
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onContainsMouseChanged: {
                    cell.cellHovered = containsMouse
                    if (containsMouse) {
                      root.cursorActive = true
                      root.selectedIndex = cell.index
                    }
                  }
                  onClicked: {
                    root.cursorActive = true
                    root.selectedIndex = cell.index
                    root.activateIndex(cell.index)
                  }
                }

                Text {
                  visible: cell.isActive
                  anchors.bottom: parent.bottom
                  anchors.right: parent.right
                  anchors.margins: Style.space(6)
                  textFormat: Text.PlainText
                  text: "● Active"
                  color: cell.hasCursor ? root.selectedText : root.foreground
                  opacity: 0.75
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.weight: Font.DemiBold
                }

                // Favorite star: no background chip, just the glyph -- dim
                // outline on hover, a muted filled star once marked. Always
                // shown when marked, otherwise only revealed on hover.
                Item {
                  id: starBadge
                  visible: cell.cellHovered || cell.isFavorite
                  anchors.top: parent.top
                  anchors.right: parent.right
                  anchors.margins: Style.space(2)
                  width: Style.space(24)
                  height: Style.space(24)

                  Text {
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: cell.isFavorite ? "★" : "☆"
                    color: cell.isFavorite ? "#F5A623" : "#FFD54F"
                    font.pixelSize: Style.font.body
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleFavorite(cell.themeData ? cell.themeData.name : "")
                  }
                }
              }
            }

            Column {
              anchors.centerIn: parent
              spacing: Style.space(8)
              visible: !root.settingsOpen && root.loading

              Text {
                textFormat: Text.PlainText
                text: "Loading Gogh themes…"
                color: root.foreground
                opacity: 0.7
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                horizontalAlignment: Text.AlignHCenter
                width: Style.space(320)
              }
            }

            Column {
              anchors.centerIn: parent
              spacing: Style.space(8)
              visible: !root.settingsOpen && !root.loading && root.filteredThemes.length === 0

              Text {
                text: "\u{1F3A8}"
                opacity: 0.8
                font.pixelSize: Style.font.displayLarge
                horizontalAlignment: Text.AlignHCenter
                width: Style.space(320)
              }

              Text {
                textFormat: Text.PlainText
                text: root.filterText
                  ? "No results for “" + root.filterText + "”"
                  : (root.favoritesOnly ? "No favorites yet — hover a theme and click the star"
                    : (root.historyOnly ? "No themes applied yet" : "No themes loaded"))
                color: root.foreground
                opacity: 0.7
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                horizontalAlignment: Text.AlignHCenter
                width: Style.space(320)
              }
            }

            Item {
              id: rotationSettings
              anchors.fill: parent
              anchors.margins: Style.space(4)
              visible: root.settingsOpen

              // Fixed label column so every row's controls start lined up
              // at the same x, instead of trailing each label's own width.
              property int labelWidth: Style.space(100)

              Column {
                id: rotationRows
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: Style.space(18)

              Row {
                width: parent.width
                spacing: Style.space(12)

                Text {
                  width: rotationSettings.labelWidth
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: "Auto-rotate"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.weight: Font.Medium
                }

                Rectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  width: Style.space(54)
                  height: Style.space(28)
                  radius: root.cornerRadius
                  color: root.rotation.enabled ? root.selectedBackground : "transparent"
                  border.width: 1
                  border.color: root.rotation.enabled ? "transparent" : Util.alpha(root.foreground, 0.3)

                  Text {
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: root.rotation.enabled ? "ON" : "OFF"
                    color: root.rotation.enabled ? root.selectedText : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    font.weight: Font.DemiBold
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.setRotationField("enabled", !root.rotation.enabled)
                  }
                }

                Rectangle {
                  visible: root.rotation.enabled
                  anchors.verticalCenter: parent.verticalCenter
                  height: Style.space(28)
                  width: snoozeLabel.implicitWidth + Style.space(20)
                  radius: root.cornerRadius
                  color: root.isSnoozed ? root.selectedBackground : "transparent"
                  border.width: 1
                  border.color: root.isSnoozed ? "transparent" : Util.alpha(root.foreground, 0.25)

                  Text {
                    id: snoozeLabel
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: root.isSnoozed ? "Snoozed — resume" : "Snooze 1h"
                    color: root.isSnoozed ? root.selectedText : root.foreground
                    opacity: root.isSnoozed ? 1 : 0.75
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    font.weight: root.isSnoozed ? Font.DemiBold : Font.Normal
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.isSnoozed ? root.clearSnooze() : root.snoozeRotation()
                  }
                }
              }

              Row {
                width: parent.width
                spacing: Style.space(12)

                Text {
                  width: rotationSettings.labelWidth
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: "Silent"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.weight: Font.Medium
                }

                Rectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  width: Style.space(54)
                  height: Style.space(28)
                  radius: root.cornerRadius
                  color: root.silent ? root.selectedBackground : "transparent"
                  border.width: 1
                  border.color: root.silent ? "transparent" : Util.alpha(root.foreground, 0.3)

                  Text {
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: root.silent ? "ON" : "OFF"
                    color: root.silent ? root.selectedText : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    font.weight: Font.DemiBold
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleSilent()
                  }
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: "no notification on apply"
                  color: root.foreground
                  opacity: 0.55
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }
              }

              Row {
                width: parent.width
                spacing: Style.space(12)

                Text {
                  width: rotationSettings.labelWidth
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: "Interval"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.weight: Font.Medium
                }

                Rectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  height: Style.space(28)
                  width: editIntervalLabel.implicitWidth + Style.space(20)
                  radius: root.cornerRadius
                  color: "transparent"
                  border.width: 1
                  border.color: Util.alpha(root.foreground, 0.25)

                  Text {
                    id: editIntervalLabel
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: intervalPromptProc.running ? "…" : "Edit"
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.promptRotationInterval()
                  }
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: "every " + root.rotation.intervalMinutes + " min"
                  color: root.foreground
                  opacity: 0.55
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }
              }

              Row {
                width: parent.width
                spacing: Style.space(12)

                Text {
                  width: rotationSettings.labelWidth
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: "Source"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.weight: Font.Medium
                }

                Repeater {
                  model: [
                    { key: "all", label: "All themes" },
                    { key: "favorites", label: "Favorites only" }
                  ]

                  delegate: Rectangle {
                    id: srcPill
                    required property var modelData
                    readonly property bool active: root.rotation.source === modelData.key

                    anchors.verticalCenter: parent.verticalCenter
                    height: Style.space(28)
                    width: srcLabel.implicitWidth + Style.space(20)
                    radius: root.cornerRadius
                    color: active ? root.selectedBackground : "transparent"
                    border.width: 1
                    border.color: active ? "transparent" : Util.alpha(root.foreground, 0.25)

                    Text {
                      id: srcLabel
                      anchors.centerIn: parent
                      textFormat: Text.PlainText
                      text: srcPill.modelData.label
                      color: srcPill.active ? root.selectedText : root.foreground
                      opacity: srcPill.active ? 1 : 0.75
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.bodySmall
                      font.weight: srcPill.active ? Font.DemiBold : Font.Normal
                    }

                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.setRotationField("source", srcPill.modelData.key)
                    }
                  }
                }
              }

              Row {
                width: parent.width
                spacing: Style.space(12)

                Text {
                  width: rotationSettings.labelWidth
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: "Order"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.weight: Font.Medium
                }

                Repeater {
                  model: [
                    { key: "sequential", label: "Sequential" },
                    { key: "random", label: "Random" }
                  ]

                  delegate: Rectangle {
                    id: ordPill
                    required property var modelData
                    readonly property bool active: root.rotation.order === modelData.key

                    anchors.verticalCenter: parent.verticalCenter
                    height: Style.space(28)
                    width: ordLabel.implicitWidth + Style.space(20)
                    radius: root.cornerRadius
                    color: active ? root.selectedBackground : "transparent"
                    border.width: 1
                    border.color: active ? "transparent" : Util.alpha(root.foreground, 0.25)

                    Text {
                      id: ordLabel
                      anchors.centerIn: parent
                      textFormat: Text.PlainText
                      text: ordPill.modelData.label
                      color: ordPill.active ? root.selectedText : root.foreground
                      opacity: ordPill.active ? 1 : 0.75
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.bodySmall
                      font.weight: ordPill.active ? Font.DemiBold : Font.Normal
                    }

                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.setRotationField("order", ordPill.modelData.key)
                    }
                  }
                }
              }

              Row {
                width: parent.width
                spacing: Style.space(12)
                visible: Object.keys(root.favorites).length > 0

                Text {
                  width: rotationSettings.labelWidth
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: "Favorites"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.weight: Font.Medium
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: Object.keys(root.favorites).length + " marked"
                  color: root.foreground
                  opacity: 0.55
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }

                Rectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  height: Style.space(26)
                  width: clearFavLabel.implicitWidth + Style.space(18)
                  radius: root.cornerRadius
                  color: "transparent"
                  border.width: 1
                  border.color: Util.alpha(root.foreground, 0.25)

                  Text {
                    id: clearFavLabel
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: "Clear"
                    color: root.foreground
                    opacity: 0.75
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.clearFavorites()
                  }
                }
              }

              Row {
                width: parent.width
                spacing: Style.space(12)

                Text {
                  width: rotationSettings.labelWidth
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: "Config"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.weight: Font.Medium
                }

                Rectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  height: Style.space(26)
                  width: exportLabel.implicitWidth + Style.space(18)
                  radius: root.cornerRadius
                  color: "transparent"
                  border.width: 1
                  border.color: Util.alpha(root.foreground, 0.25)

                  Text {
                    id: exportLabel
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: "Export"
                    color: root.foreground
                    opacity: 0.75
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.promptExportConfig()
                  }
                }

                Rectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  height: Style.space(26)
                  width: importLabel.implicitWidth + Style.space(18)
                  radius: root.cornerRadius
                  color: "transparent"
                  border.width: 1
                  border.color: Util.alpha(root.foreground, 0.25)

                  Text {
                    id: importLabel
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: importPromptProc.running ? "…" : "Import"
                    color: root.foreground
                    opacity: 0.75
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.promptImportConfig()
                  }
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: "~/.config/gogh/config-gogh.yml"
                  color: root.foreground
                  opacity: 0.5
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }
              }
              } // rotationRows

              // Footer, pinned to the bottom of the settings panel: status
              // text on the left, the standout "Apply now" action on the
              // right.
              Item {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: Style.space(32)

                Text {
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: root.rotation.lastAppliedName
                    ? "Last applied: " + root.rotation.lastAppliedName
                    : "Last applied: none yet"
                  color: root.foreground
                  opacity: 0.5
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }

                Rectangle {
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  height: Style.space(30)
                  width: applyNowLabel.implicitWidth + Style.space(24)
                  radius: root.cornerRadius
                  // A translucent green tint (not a solid fill) so this
                  // action reads as an accent that blends with whatever
                  // theme is active, rather than an opaque block.
                  color: Util.alpha("#3C9A46", 0.18)
                  border.width: 1
                  border.color: Util.alpha("#3C9A46", 0.65)

                  Text {
                    id: applyNowLabel
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: "Apply now"
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    font.weight: Font.DemiBold
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      // Back to the grid (not a full dismiss) -- the theme
                      // change is still visible on screen since the picker
                      // itself doesn't cover the whole desktop.
                      root.runRotationTick()
                      root.settingsOpen = false
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
