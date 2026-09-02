import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "mgldvd.gogh-themes"

  property string pluginDir: Quickshell.env("HOME") + "/.config/omarchy/plugins/mgldvd.gogh-themes"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    slotSize: Style.bar.statusSlot + Style.space(10)
    tooltipText: "Omarchy Theme × Gogh (middle-click: random)"
    iconComponent: Component {
      Image {
        anchors.fill: parent
        source: Util.fileUrl(root.pluginDir + "/icons/mgldvd.gogh-themes.png")
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: true
      }
    }
    onPressed: function(button) {
      if (!root.bar) return
      if (button === Qt.MiddleButton) root.bar.run(root.pluginDir + "/bin/gogh-theme-random")
      else root.bar.run("omarchy-shell shell toggle mgldvd.gogh-themes '{}'")
    }
  }
}
