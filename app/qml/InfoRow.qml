import QtQuick
import Pinna

SettingRow {
    id: root
    property string text

    TextEdit {
        text: root.text
        font: Theme.body
        color: Theme.text2
        readOnly: true
        selectByMouse: true
        selectionColor: Theme.accent
        selectedTextColor: Theme.accentText
        horizontalAlignment: Text.AlignRight
    }
}
