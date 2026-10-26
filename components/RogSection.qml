import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

ColumnLayout {
    property string title
    property string icon

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
            text: title
            font.pixelSize: 13
            font.weight: Font.Medium
            color: Theme.surfaceVariantText
        }

    }

}
