import QtQuick
import "components"
import qs.Modules.Plugins

PluginComponent {
    id: root

    popoutWidth: 432
    verticalBarPill: horizontalBarPill

    RogIpc {
        id: ipc
    }

    horizontalBarPill: Component {
        Item {
            implicitWidth: root.widgetThickness
            implicitHeight: root.widgetThickness

            RogLogo {
                anchors.centerIn: parent
                width: Math.min(24, root.widgetThickness - 8)
                height: width
            }

        }

    }

    popoutContent: Component {
        RogPanel {
            backend: ipc
        }

    }

}
