import QtQuick
import Pinna

SettingRow {
    id: root
    property bool checked
    signal toggled(bool value)
    clickable: true
    onClicked: sw.flip()

    Toggle {
        id: sw
        checked: root.checked
        onToggled: v => root.toggled(v)
    }
}
