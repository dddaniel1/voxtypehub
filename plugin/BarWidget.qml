import QtQuick
import Quickshell.Io
import qs.Commons as Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "daniel.voxtypehub"
  property string profile: "general"
  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  Process {
    id: readProfile
    command: ["/home/daniel/.local/bin/voxtype-profile", "get"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        let value = text.trim()
        if (value) root.profile = value
      }
    }
  }
  Timer { interval: 2000; running: true; repeat: true; onTriggered: if (!readProfile.running) readProfile.running = true }
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened : false
  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item && !panelLoader.item.dirty && !(panelLoader.item.page === "provider" && panelLoader.item.providerDirty)) panelLoader.item.close() }
  function closeForPopoutSwitch() { if (panelLoader.item && !panelLoader.item.dirty && !(panelLoader.item.page === "provider" && panelLoader.item.providerDirty)) panelLoader.item.closeForPopoutSwitch() }
  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: { item.bar=root.bar; item.anchorItem=button; item.hostWidget=root; item.profileSelected.connect(function(value){root.profile=value}) }
  }
  onBarChanged: if (panelLoader.item) panelLoader.item.bar=root.bar
  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "🎙 " + (panelLoader.item && panelLoader.item.profiles.find(function(p) { return p.id===root.profile }) ? panelLoader.item.profileLabel(root.profile) : root.profile)
    tooltipText: strings.t("tooltip")
    onPressed: { if (!root.opened) root.open(); else if (panelLoader.item.dirty || (panelLoader.item.page === "provider" && panelLoader.item.providerDirty)) { panelLoader.item.noticePage=panelLoader.item.page; panelLoader.item.notice=strings.t("ui.87cedce0a038") } else root.close() }
  }
}
