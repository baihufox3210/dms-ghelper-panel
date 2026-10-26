import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

RowLayout {
    id: root

    property var options: [] // Stable option objects: { label, value }
    property string emptyText: "Unavailable"
    property var selected: null

    signal chosen(var value)

    implicitHeight: 40
    spacing: 4

    StyledText {
        Layout.fillWidth: true
        Layout.preferredHeight: 40
        visible: root.options.length === 0
        text: root.emptyText
        font.pixelSize: 12
        color: Theme.surfaceVariantText
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    Repeater {
        model: root.options

        delegate: Rectangle {
            id: segment

            required property var modelData
            readonly property bool active: root.selected === modelData.value

            enabled: modelData.enabled !== false
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.preferredHeight: 40
            radius: 12
            opacity: segment.enabled ? 1 : 0.38
            color: active ? Theme.primary : mouse.pressed ? Theme.primaryPressed : mouse.containsMouse ? Theme.primaryHover : Theme.surfaceContainerHigh
            activeFocusOnTab: segment.enabled
            Keys.onSpacePressed: {
                if (segment.enabled && !active)
                    root.chosen(modelData.value);

            }
            Keys.onReturnPressed: {
                if (segment.enabled && !active)
                    root.chosen(modelData.value);

            }
            border.width: activeFocus ? 2 : 0
            border.color: Theme.outline
            Accessible.role: Accessible.Button
            Accessible.name: modelData.label
            Accessible.checkable: true
            Accessible.checked: active
            Accessible.onPressAction: {
                if (segment.enabled && !active)
                    root.chosen(modelData.value);

            }

            StyledText {
                anchors.centerIn: parent
                text: modelData.label
                font.pixelSize: 13
                font.weight: active ? Font.DemiBold : Font.Medium
                color: active ? Theme.primaryText : Theme.surfaceText
            }

            MouseArea {
                id: mouse

                anchors.fill: parent
                enabled: segment.enabled
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (!active)
                        root.chosen(modelData.value);

                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: 120
                }

            }

        }

    }

}
