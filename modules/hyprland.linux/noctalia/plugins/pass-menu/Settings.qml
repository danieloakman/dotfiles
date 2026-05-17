import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null

  Layout.fillWidth: true
  spacing: Style.marginM

  // Local state - initialized from saved settings
  property string editPasswordStoreDir:
    pluginApi?.pluginSettings?.passwordStoreDir ||
    pluginApi?.manifest?.metadata?.defaultSettings?.passwordStoreDir ||
    "~/.password-store"

  property string editSorting:
    pluginApi?.pluginSettings?.sorting ||
    pluginApi?.manifest?.metadata?.defaultSettings?.sorting ||
    "alphabetical"

  NLabel {
    label: "Password store directory"
    description: "The directory where the password store is located"
  }

  // Controls update local state, not settings directly
  NTextInput {
    text: root.editPasswordStoreDir
    onTextChanged: root.editPasswordStoreDir = text
  }

  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginM
    Layout.bottomMargin: Style.marginM
  }

  NComboBox {
    Layout.fillWidth: true
    label: "Sorting"
    description: "How to sort the entries"
    model: [
      { key: "alphabetical", name: "Alphabetical" },
      { key: "last-used", name: "Last used" },
    ]
    currentKey: root.editSorting
    onSelected: key => root.editSorting = key
  }

  // Save applies local state to settings
  function saveSettings() {
    pluginApi.pluginSettings.passwordStoreDir = root.editPasswordStoreDir
    pluginApi.pluginSettings.sorting = root.editSorting
    pluginApi.saveSettings()
  }
}
