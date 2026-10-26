import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

Rectangle {
    property string label
    property var reading: null
    property string unit
    property string icon

    implicitHeight: 72
    radius: 12
    color: Theme.surfaceContainerHigh

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 4

        RowLayout {
            spacing: 4

            DankIcon {
                name: icon
                size: 16
                color: Theme.surfaceVariantText
            }

            StyledText {
                text: label
                font.pixelSize: 11
                color: Theme.surfaceVariantText
            }

        }

        RowLayout {
            spacing: 4

            StyledText {
                text: reading === null || reading === undefined ? "—" : String(reading)
                Layout.alignment: Qt.AlignBaseline
                font.pixelSize: 20
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            StyledText {
                text: unit
                font.pixelSize: 11
                color: Theme.surfaceVariantText
                Layout.alignment: Qt.AlignBaseline
            }

        }

    }

}
