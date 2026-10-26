import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

RowLayout {
    id: header

    property bool connected: false
    property bool applying: false

    implicitHeight: 48
    spacing: 12

    Rectangle {
        Layout.preferredWidth: 40
        Layout.preferredHeight: 40
        radius: 12
        color: Theme.surfaceContainerHigh

        RogLogo {
            anchors.centerIn: parent
            width: 28
            height: 28
        }

    }

    StyledText {
        Layout.fillWidth: true
        text: "G-Helper"
        font.pixelSize: 18
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    Rectangle {
        implicitWidth: connectionLabel.implicitWidth + 24
        implicitHeight: 28
        radius: 14
        color: header.connected ? Theme.primaryHover : Theme.surfaceContainerHigh

        StyledText {
            id: connectionLabel

            anchors.centerIn: parent
            text: header.applying ? "Applying…" : header.connected ? "Connected" : "Offline"
            font.pixelSize: 11
            font.weight: Font.Medium
            color: header.connected ? Theme.primary : Theme.surfaceVariantText
        }

    }

}
