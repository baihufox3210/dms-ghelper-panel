import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

ColumnLayout {
    property string title
    property string icon
    property string valueText: ""

    spacing: 8

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        DankIcon {
            name: icon
            size: 20
            color: Theme.surfaceVariantText
        }

        StyledText {
            Layout.fillWidth: true
            text: title
            font.pixelSize: 13
            font.weight: Font.Medium
            color: Theme.surfaceVariantText
        }

        StyledText {
            text: valueText
            visible: valueText.length > 0
            horizontalAlignment: Text.AlignRight
            font.pixelSize: 13
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

    }

}
