import QtQuick
import QtQuick.Layouts
import "components"
import qs.Common
import qs.Widgets

Item {
    id: panel

    required property var backend
    property var parentPopout: null
    property var closePopout: null
    readonly property bool open: parentPopout ? parentPopout.shouldBeVisible : visible
    readonly property var gpuOptions: (backend.caps.gpuModes || []).map((m) => {
        return ({
            "label": m.charAt(0).toUpperCase() + m.slice(1),
            "value": m
        });
    })
    readonly property var hzOptions: [{
        "label": "Auto",
        "value": "auto",
        "enabled": backend.autoReady
    }].concat((backend.display.availableHz || []).slice().sort((a, b) => {
        return a - b;
    }).map((h) => {
        return ({
            "label": h + " Hz",
            "value": h
        });
    }))
    readonly property var charge: backend.battery.chargeLimit

    function value(v, suffix) {
        return v === null || v === undefined ? "Unavailable" : v + suffix;
    }

    implicitHeight: content.implicitHeight + 16
    onOpenChanged: backend.panelOpen = open
    Component.onCompleted: backend.panelOpen = open
    Component.onDestruction: backend.panelOpen = false

    ColumnLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 8
        y: 8
        spacing: 16

        RogHeader {
            Layout.fillWidth: true
            connected: backend.connected
            applying: backend.applying
        }

        RogSection {
            Layout.fillWidth: true
            title: "Monitoring"
            icon: "monitoring"

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                RogMetric {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    label: "CPU Temperature"
                    icon: "thermometer"
                    reading: backend.status.cpuTemperatureC
                    unit: "°C"
                }

                RogMetric {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    label: "GPU Temperature"
                    icon: "thermometer"
                    reading: backend.status.gpuTemperatureC
                    unit: "°C"
                }

            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                RogMetric {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    label: "CPU Fan"
                    icon: "mode_fan"
                    reading: backend.status.cpuFanRpm
                    unit: "RPM"
                }

                RogMetric {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    label: "GPU Fan"
                    icon: "mode_fan"
                    reading: backend.status.gpuFanRpm
                    unit: "RPM"
                }

                RogMetric {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    label: "Mid Fan"
                    icon: "mode_fan"
                    reading: backend.status.midFanRpm
                    unit: "RPM"
                }

            }

        }

        RogSection {
            Layout.fillWidth: true
            title: "Performance mode"
            icon: "speed"

            RogSegments {
                Layout.fillWidth: true
                options: [{
                    "label": "Silent",
                    "value": "silent"
                }, {
                    "label": "Balanced",
                    "value": "balanced"
                }, {
                    "label": "Turbo",
                    "value": "turbo"
                }]
                selected: backend.status.performance ? backend.status.performance.mode : null
                enabled: backend.ready && backend.supports("performance.set")
                onChosen: (v) => {
                    return backend.change("performance.set", {
                        "mode": v
                    });
                }
            }

        }

        RogSection {
            Layout.fillWidth: true
            title: "GPU mode"
            icon: "developer_board"

            RogSegments {
                Layout.fillWidth: true
                options: panel.gpuOptions
                selected: backend.gpu.configuredMode || backend.gpu.mode
                enabled: backend.ready && !backend.gpu.switchInProgress && backend.supports("gpu.set")
                onChosen: (v) => {
                    return backend.change("gpu.set", {
                        "mode": v
                    });
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.preferredHeight: 16
                text: !panel.gpuOptions.length ? "GPU control unavailable" : backend.rebootRequired ? "Restart required · Current: " + backend.gpu.mode : backend.gpu.switchInProgress ? "GPU switch in progress…" : "Current: " + (backend.gpu.mode || "Unavailable")
                font.pixelSize: 11
                color: backend.rebootRequired ? Theme.primary : Theme.surfaceVariantText
            }

        }

        RogSection {
            Layout.fillWidth: true
            title: "Display"
            icon: "desktop_windows"
            valueText: panel.value(backend.display.currentHz, " Hz")

            RogSegments {
                Layout.fillWidth: true
                options: panel.hzOptions
                emptyText: "Refresh rate unavailable"
                selected: backend.refreshSelection
                enabled: backend.ready && backend.caps.displayRefresh === true
                onChosen: (v) => {
                    return backend.chooseRefresh(v);
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.preferredHeight: 16
                text: !backend.autoSupported ? "Auto unsupported" : !backend.autoKnown ? (backend.applying ? "Applying changes…" : "Reading Auto state…") : "AC: highest · Battery: prefer 60 Hz"
                elide: Text.ElideRight
                font.pixelSize: 11
                color: Theme.surfaceVariantText
            }

        }

        RogSection {
            Layout.fillWidth: true
            title: "Battery"
            icon: "battery_charging_full"

            RowLayout {
                Layout.fillWidth: true

                StyledText {
                    text: "Charge limit"
                    font.pixelSize: 12
                    color: Theme.surfaceVariantText
                }

                Item {
                    Layout.fillWidth: true
                }

                StyledText {
                    text: panel.value(panel.charge, "%")
                    font.pixelSize: 12
                    color: Theme.surfaceText
                }

            }

            RogSegments {
                Layout.fillWidth: true
                options: [{
                    "label": "60%",
                    "value": 60
                }, {
                    "label": "80%",
                    "value": 80
                }, {
                    "label": "100%",
                    "value": 100
                }]
                selected: panel.charge
                enabled: backend.ready && backend.caps.batteryChargeLimit === true
                onChosen: (v) => {
                    return backend.change("battery.set", {
                        "limit": v
                    });
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.preferredHeight: 16
                text: backend.caps.batteryChargeLimit !== true ? "Charge limit unsupported" : backend.battery.fullChargeOverride ? "Full charge override active" : "Saved limit: " + panel.value(backend.battery.savedChargeLimit, "%")
                font.pixelSize: 11
                color: Theme.surfaceVariantText
            }

        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            radius: 12
            color: backend.errorText ? Theme.withAlpha(Theme.error, 0.08) : Theme.surfaceContainerHigh

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                DankIcon {
                    name: backend.errorText ? "error" : backend.applying ? "sync" : "info"
                    size: 18
                    color: backend.errorText ? Theme.error : Theme.surfaceVariantText
                }

                StyledText {
                    Layout.fillWidth: true
                    text: backend.errorText || backend.notice || (backend.connected ? "Live monitoring · Updates every 3 seconds" : "Start G-Helper to connect")
                    font.pixelSize: 11
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    wrapMode: Text.WordWrap
                    color: backend.errorText ? Theme.error : Theme.surfaceVariantText
                }

            }

        }

    }

}
