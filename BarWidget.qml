import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// World-clock pill: a globe icon that expands to the client zones' current
// times on hover; left click opens the worldtimebuddy-style hour grid.
BarWidget {
  id: root
  moduleName: "io.github.sspaeti.timezones"

  // Sanitized because WidgetButton's internal Text uses AutoText, which
  // would rich-text-parse a crafted setting. See README's Configure section
  // for the default glyph, its fallback, and other icon choices.
  readonly property string configuredIcon: Model.plainText(setting("icon", ""))

  // Default glyph is fa-bars_staggered (U+EE19), a Font Awesome 6 glyph Nerd
  // Fonts only carry since v3.3. An older Nerd Font would draw a tofu box, so
  // probe fontconfig once — Qt falls back through the same tables — and use
  // md-web_clock (U+F124A, in every Nerd Font since 3.0) when nothing has it.
  property bool defaultGlyphAvailable: false
  readonly property string icon: configuredIcon !== "" ? configuredIcon
    : defaultGlyphAvailable ? "" : "󱉊"

  Process {
    id: glyphProbe
    command: ["fc-list", ":charset=ee19", "family"]
    running: true
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.defaultGlyphAvailable = String(text || "").trim() !== ""
    }
  }
  readonly property string wtbUrl: setting("worldtimebuddyUrl", "https://www.worldtimebuddy.com/pdt-to-switzerland-bern")

  // Set "hoverExpand": false on the widget entry to keep the pill a static
  // icon — the expansion shifts neighboring bar widgets, which not everyone
  // wants.
  readonly property bool hoverExpand: setting("hoverExpand", true) === true

  readonly property string compact: panelLoader.item ? panelLoader.item.compactLabel : ""
  // Local patch: zones with "expand": true are always shown in the bar; hover
  // (when hoverExpand is on) reveals every zone.
  readonly property string pinned: panelLoader.item ? panelLoader.item.pinnedLabel : ""
  readonly property bool hovered: hoverExpand && button.tooltipHovered && compact !== ""
  readonly property string shown: hovered ? compact : pinned
  readonly property bool expanded: !vertical && shown !== ""
  // Local patch: "showIcon": false hides the glyph while times are visible. The
  // icon stays when there are no times, so the pill remains clickable.
  readonly property bool showIcon: setting("showIcon", true) === true || !expanded

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function refresh() {
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  function openWorldtimebuddy() {
    if (root.bar) root.bar.run("omarchy-launch-browser " + Util.shellQuote(root.wtbUrl))
  }

  // A bar surface exists per monitor, so flip every instance — otherwise the
  // display mode would change on one screen and not the others.
  function cycleHourFormat() {
    broadcast("cycleHourFormatHere")
  }

  function cycleHourFormatHere() {
    if (panelLoader.item && panelLoader.item.cycleHourFormat) panelLoader.item.cycleHourFormat()
  }

  function screenshot() {
    if (panelLoader.item && panelLoader.item.copyScreenshot) panelLoader.item.copyScreenshot()
  }

  // Shape contract for shell.summon/hide/toggle routing (Bar.findPanelWidget
  // requires open/close/opened on the bar-widget root).
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  // Forwarded so this widget can stand in for the panel as the bar's popout
  // identity: Bar.requestPopout prefers closeForPopoutSwitch over close, and
  // KeyboardPanel reads popoutSwitchClosing back off its owner.
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "io.github.sspaeti.timezones"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
    function refresh(): void { root.refresh() }
    function toggleHourFormat(): void { root.cycleHourFormat() }
    function screenshot(): void { root.screenshot() }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // Keep WidgetButton as the interaction surface, but draw the icon and
    // expanding label separately so centering a longer string cannot move the
    // icon. The button grows only to the right of the icon's fixed position.
    text: " "
    fixedWidth: labelRow.implicitWidth + scaledHorizontalMargin * 2
    foreground: "transparent"
    tooltipText: ""

    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.RightButton) root.openWorldtimebuddy()
      else if (b === Qt.MiddleButton) root.refresh()
      else root.togglePanel()
    }
  }

  Row {
    id: labelRow
    anchors.left: button.left
    anchors.leftMargin: button.scaledHorizontalMargin
    anchors.verticalCenter: button.verticalCenter
    spacing: root.expanded && root.showIcon ? Style.space(8) : 0

    Text {
      visible: root.showIcon
      text: root.icon
      textFormat: Text.PlainText
      color: button.active && button.useActiveColor ? button.activeColor : (root.bar ? root.bar.barForeground : Color.foreground)
      font.family: button.fontFamily
      font.pixelSize: button.fontSize
      renderType: Text.NativeRendering
    }

    Text {
      visible: root.expanded
      text: root.shown
      textFormat: Text.PlainText
      color: button.active && button.useActiveColor ? button.activeColor : (root.bar ? root.bar.barForeground : Color.foreground)
      font.family: button.fontFamily
      font.pixelSize: button.fontSize
      renderType: Text.NativeRendering
    }
  }
}
