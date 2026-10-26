import QtQuick
import Quickshell.Io

// Single serialized request queue; reads never replace the panel's component tree.
Item {
    id: root

    property bool panelOpen: false
    property bool connected: false
    property bool busy: false
    property bool applying: false
    property string pendingMethod: ""
    property string errorText: ""
    property string errorMethod: ""
    property string notice: ""
    property var status: ({
    })
    property var caps: ({
    })
    property var battery: ({
    })
    property var autoStatus: ({
    })
    property bool autoKnown: false
    property bool autoUnavailable: false
    readonly property bool autoSupported: caps.displayAuto === true && supports("display.auto.get") && supports("display.auto.set") && !autoUnavailable
    readonly property bool autoReady: ready && autoSupported && autoKnown
    readonly property var refreshSelection: autoSupported ? (autoKnown ? (autoStatus.enabled ? "auto" : display.currentHz) : null) : display.currentHz
    property bool refreshPending: false
    property var queue: []
    property string method: ""
    property bool received: false
    property int cycle: 0
    property int backoff: 0
    readonly property var gpu: status.gpu || ({
    })
    readonly property var display: status.display || ({
    })
    readonly property bool rebootRequired: gpu.rebootRequired === true
    readonly property bool ready: connected && !applying
    readonly property string executable: Qt.resolvedUrl("bin/rog-ipc-bridge").toString().replace(/^file:\/\//, "")

    function supports(name) {
        return (caps.methods || []).indexOf(name) >= 0;
    }

    function enqueue(name, params) {
        if (method === name && busy)
            return ;

        if (queue.some((t) => {
            return t.method === name;
        }))
            return ;

        queue.push({
            "method": name,
            "params": params || {
            }
        });
        drain();
    }

    function drain() {
        if (busy || !queue.length)
            return ;

        var task = queue.shift();
        method = task.method;
        received = false;
        busy = true;
        process.command = [executable, task.method, JSON.stringify(task.params)];
        process.running = true;
    }

    function refresh(full) {
        if (busy || queue.length || applying) {
            if (full)
                refreshPending = true;

            return ;
        }
        refreshPending = false;
        if (full || !connected || cycle % 10 === 0)
            enqueue("capabilities.get");

        enqueue("monitoring.get");
        if (autoSupported)
            enqueue("display.auto.get");

        if (full || cycle % 5 === 0)
            enqueue("battery.get");

        cycle++;
    }

    function change(name, params) {
        if (name === "display.auto.set" && (!autoReady || typeof params.enabled !== "boolean"))
            return ;

        if (!ready || !supports(name))
            return ;

        // Keep only the current read, then perform the user's action before other reads.
        queue = [{
            "method": name,
            "params": params
        }];
        applying = true;
        pendingMethod = name;
        errorText = "";
        notice = "Applying changes…";
        if (name === "display.auto.set" || name === "display.set")
            autoKnown = false;

        drain();
    }

    function chooseRefresh(value) {
        if (value === "auto")
            change("display.auto.set", {
            "enabled": true
        });
        else if (Number.isInteger(value) && (display.availableHz || []).indexOf(value) >= 0)
            change("display.set", {
            "hz": value
        });
    }

    function applyAutoStatus(result) {
        if (typeof result.enabled !== "boolean" || !(result.onAc === null || typeof result.onAc === "boolean") || !(result.currentHz === null || (Number.isInteger(result.currentHz) && result.currentHz > 0))) {
            autoKnown = false;
            throw new Error("Invalid Auto response");
        }
        autoStatus = result;
        autoKnown = true;
        status = Object.assign({
        }, status, {
            "display": Object.assign({
            }, display, {
                "currentHz": result.currentHz
            })
        });
    }

    // Always reconcile Auto after manual Hz writes, even failed writes: the server
    // may have saved Auto=false before a modeset failure. Brightness leaves Auto alone.
    function reconcile(name) {
        if (name === "display.set" || name === "display.auto.set") {
            autoKnown = false;
            if (autoSupported)
                enqueue("display.auto.get");

        }
        enqueue("monitoring.get");
        enqueue("battery.get");
        enqueue("capabilities.get");
    }

    function accept(raw) {
        received = true;
        var mutation = method.indexOf(".set") >= 0;
        try {
            var reply = JSON.parse(raw);
            if (!reply.ok) {
                errorMethod = method;
                var e = reply.error || {
                };
                if (method === "display.auto.get" || method === "display.auto.set") {
                    autoKnown = false;
                    if (e.code === "unknown_method" || e.code === "unsupported") {
                        autoUnavailable = true;
                        autoStatus = ({
                        });
                        if (!mutation)
                            return ;

                    }
                }
                if (e.code === "busy")
                    backoff = 2;

                if (method === "monitoring.get" && e.code !== "busy")
                    connected = false;

                // A successful background read must never erase a mutation error.
                errorText = e.code === "busy" ? "G-Helper is busy. Try again shortly." : (e.message || "Unable to reach G-Helper");
                if (mutation)
                    notice = "Check current status before trying again.";

                return ;
            }
            var r = reply.result || {
            };
            if (method === "capabilities.get") {
                caps = r;
                autoUnavailable = false;
                if (autoSupported) {
                    enqueue("display.auto.get");
                } else {
                    autoKnown = false;
                    autoStatus = ({
                    });
                    queue = queue.filter((t) => {
                        return t.method !== "display.auto.get";
                    });
                }
            } else if (method === "display.auto.get") {
                applyAutoStatus(r);
            } else if (method === "monitoring.get") {
                status = r;
                connected = true;
                if (errorMethod.indexOf(".set") < 0) {
                    errorText = "";
                    errorMethod = "";
                }
            } else if (method === "battery.get") {
                battery = r;
            } else if (mutation) {
                if (method === "display.auto.set") {
                    if (r.state !== "applied" && r.state !== "failed") {
                        autoKnown = false;
                        throw new Error("Invalid Auto mutation state");
                    }
                    applyAutoStatus(r);
                }
                if (method === "gpu.set")
                    status = Object.assign({
                }, status, {
                    "gpu": r
                });

                if (method === "battery.set")
                    battery = r;

                var state = r.state;
                if (["failed", "blocked", "busy"].indexOf(state) >= 0) {
                    errorMethod = method;
                    errorText = method === "display.auto.set" && state === "failed" ? "Auto preference saved; refresh rate could not be verified." : state === "blocked" ? "GPU switch blocked. Review it in G-Helper." : state === "busy" ? "G-Helper is busy. Try again shortly." : "Change could not be verified. Check current status.";
                }
                notice = r.rebootRequired || state === "reboot_required" ? "Restart required to finish the GPU change." : state === "pending" ? "Change saved; waiting for G-Helper." : errorText ? "" : "Settings updated";
            }
        } catch (e) {
            errorMethod = method;
            errorText = "Invalid response from G-Helper";
        }
    }

    onPanelOpenChanged: {
        if (panelOpen)
            refresh(true);

    }
    Component.onCompleted: refresh(true)

    Process {
        id: process

        onExited: (exitCode, exitStatus) => {
            var mutation = root.method.indexOf(".set") >= 0;
            if (!root.received) {
                root.errorMethod = root.method;
                root.errorText = "IPC bridge could not complete the request";
                root.connected = false;
            }
            root.busy = false;
            if (mutation) {
                root.applying = false;
                root.pendingMethod = "";
                root.reconcile(root.method);
            }
            root.drain();
            if (!root.busy && !root.queue.length && root.refreshPending)
                root.refresh(true);

        }

        stdout: StdioCollector {
            onStreamFinished: root.accept(this.text)
        }

    }

    Timer {
        interval: root.panelOpen ? 3000 : 30000
        running: true
        repeat: true
        onTriggered: {
            if (root.backoff > 0) {
                root.backoff--;
                return ;
            }
            root.refresh(false);
        }
    }

}
