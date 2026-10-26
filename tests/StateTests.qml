import ".." as Rog
import QtQuick
import Quickshell

ShellRoot {
    property int checks: 0

    function check(condition, label) {
        if (!condition)
            throw new Error("FAIL: " + label);

        checks++;
    }

    function response(method, result) {
        ipc.method = method;
        ipc.accept(JSON.stringify({
            "ok": true,
            "result": result
        }));
    }

    Component.onCompleted: {
        check(!ipc.ready, "disconnected controls disabled");
        response("capabilities.get", {
            "methods": ["gpu.set", "performance.set"],
            "gpuModes": ["eco", "standard"]
        });
        check(!ipc.supports("battery.set"), "unsupported mutation gated");
        response("monitoring.get", {
            "cpuTemperatureC": null,
            "gpu": {
                "mode": "standard",
                "configuredMode": "standard",
                "rebootRequired": false
            }
        });
        check(ipc.connected && ipc.ready, "monitoring establishes connection");
        ipc.change("battery.set", {
            "limit": 80
        });
        check(!ipc.applying && !ipc.queue.length, "unsupported action never queued");
        ipc.change("gpu.set", {
            "mode": "eco"
        });
        check(ipc.applying && !ipc.ready && ipc.queue.length === 1, "loading disables controls");
        ipc.change("gpu.set", {
            "mode": "eco"
        });
        check(ipc.queue.length === 1, "duplicate click ignored");
        response("gpu.set", {
            "state": "reboot_required",
            "mode": "standard",
            "configuredMode": "ultimate",
            "rebootRequired": true
        });
        check(ipc.rebootRequired && ipc.notice.indexOf("Restart") >= 0, "reboot required visible");
        response("gpu.set", {
            "state": "pending",
            "mode": "standard",
            "configuredMode": "eco"
        });
        check(ipc.notice.indexOf("waiting") >= 0, "pending state visible");
        response("gpu.set", {
            "state": "blocked",
            "mode": "standard",
            "configuredMode": "eco",
            "rebootRequired": true
        });
        check(ipc.errorText.indexOf("blocked") >= 0 && ipc.rebootRequired, "blocked and reboot coexist");
        response("battery.get", {
            "chargeLimit": 60,
            "savedChargeLimit": 80,
            "fullChargeOverride": true
        });
        check(ipc.errorText.length > 0 && ipc.battery.chargeLimit === 60, "poll preserves error and observed limit");
        response("performance.set", {
            "state": "failed"
        });
        check(ipc.errorText.length > 0, "failed result is not success");
        ipc.method = "gpu.set";
        ipc.accept(JSON.stringify({
            "ok": false,
            "error": {
                "code": "busy",
                "message": "Busy"
            }
        }));
        check(ipc.backoff === 2 && ipc.errorText.indexOf("busy") >= 0, "busy backoff");
        ipc.method = "monitoring.get";
        ipc.accept(JSON.stringify({
            "ok": false,
            "error": {
                "code": "transport_error",
                "message": "Offline"
            }
        }));
        check(!ipc.connected, "connection loss disables controls");
        response("monitoring.get", {
            "gpu": {
                "mode": "standard"
            }
        });
        check(ipc.connected && !ipc.errorText, "reconnection clears stale read errors");
        ipc.accept("not JSON");
        check(ipc.errorText.indexOf("Invalid") >= 0, "invalid response handled");
        ipc.applying = false;
        ipc.queue = [];
        ipc.errorText = "";
        response("capabilities.get", {
            "displayAuto": true,
            "methods": ["display.auto.get", "display.auto.set", "display.set", "display.brightness.set"]
        });
        check(ipc.autoSupported && ipc.queue.some((t) => {
            return t.method === "display.auto.get";
        }), "new capability schedules Auto read");
        response("display.auto.get", {
            "enabled": true,
            "onAc": true,
            "currentHz": 240
        });
        check(ipc.autoReady && ipc.autoStatus.enabled && ipc.display.currentHz === 240, "Auto read synchronizes enabled and current Hz");
        ipc.change("display.auto.set", {
            "enabled": 1
        });
        check(!ipc.applying, "Auto only accepts boolean requests");
        ipc.change("display.auto.set", {
            "enabled": false
        });
        check(ipc.applying && !ipc.autoKnown && ipc.queue[0].params.enabled === false, "Auto toggle waits for readback");
        ipc.change("display.auto.set", {
            "enabled": true
        });
        check(ipc.queue.length === 1 && ipc.queue[0].params.enabled === false, "duplicate Auto mutation ignored");
        response("display.auto.set", {
            "enabled": false,
            "onAc": true,
            "currentHz": 240,
            "state": "applied"
        });
        check(!ipc.autoStatus.enabled && ipc.autoKnown, "Auto off uses server preference");
        ipc.applying = false;
        ipc.queue = [];
        ipc.errorText = "";
        response("display.auto.set", {
            "enabled": true,
            "onAc": false,
            "currentHz": 60,
            "state": "failed"
        });
        check(ipc.autoStatus.enabled && ipc.errorText.indexOf("could not be verified") >= 0, "failed apply retains saved enabled preference and error");
        response("monitoring.get", {
            "display": {
                "currentHz": 60
            }
        });
        check(ipc.errorText.length > 0, "monitoring cannot erase Auto mutation error");
        ipc.queue = [];
        ipc.reconcile("display.set");
        check(!ipc.autoKnown && ipc.queue[0].method === "display.auto.get", "manual Hz reconciles Auto first even after modeset failure");
        response("display.auto.get", {
            "enabled": false,
            "onAc": null,
            "currentHz": null
        });
        check(ipc.autoKnown && !ipc.autoStatus.enabled && ipc.display.currentHz === null, "manual disables Auto with nullable power and Hz");
        ipc.queue = [];
        ipc.reconcile("display.brightness.set");
        check(ipc.autoKnown && !ipc.queue.some((t) => {
            return t.method === "display.auto.get";
        }), "brightness does not invalidate Auto");
        ipc.applying = false;
        ipc.queue = [];
        ipc.method = "display.auto.get";
        ipc.accept(JSON.stringify({
            "ok": false,
            "error": {
                "code": "unknown_method",
                "message": "Unknown method"
            }
        }));
        check(!ipc.autoSupported && !ipc.autoKnown, "unknown Auto API disables control");
        ipc.change("display.auto.set", {
            "enabled": true
        });
        check(!ipc.applying && !ipc.queue.length, "unsupported Auto cannot fake success");
        response("capabilities.get", {
            "displayAuto": false,
            "methods": ["display.auto.get", "display.auto.set"]
        });
        check(!ipc.autoSupported, "registered methods alone do not imply backend support");
        response("capabilities.get", {
            "displayAuto": true,
            "methods": ["display.auto.get"]
        });
        check(!ipc.autoSupported, "both Auto methods required");
        response("capabilities.get", {
            "displayAuto": true,
            "methods": ["display.auto.get", "display.auto.set"]
        });
        response("display.auto.get", {
            "enabled": "true",
            "onAc": true,
            "currentHz": 240
        });
        check(!ipc.autoKnown && ipc.errorText.indexOf("Invalid") >= 0, "malformed Auto result never enables switch");
        ipc.queue = [];
        ipc.refresh(true);
        check(ipc.refreshPending, "opening during in-flight read retains full refresh request");
        ipc.queue = [];
        ipc.method = "monitoring.get";
        ipc.refresh(false);
        check(!ipc.queue.length, "polling never piles up while busy");
        ipc.applying = false;
        ipc.queue = [];
        response("capabilities.get", {
            "displayAuto": true,
            "methods": ["display.auto.get", "display.auto.set", "display.set"]
        });
        response("monitoring.get", {
            "display": {
                "currentHz": 240,
                "availableHz": [240, 60]
            }
        });
        response("display.auto.get", {
            "enabled": true,
            "onAc": true,
            "currentHz": 240
        });
        check(ipc.refreshSelection === "auto", "Auto is selected instead of observed Hz when enabled");
        ipc.chooseRefresh(240);
        check(ipc.queue[0].method === "display.set" && ipc.queue[0].params.hz === 240, "manual current Hz still disables active Auto");
        ipc.applying = false;
        ipc.queue = [];
        response("display.auto.get", {
            "enabled": false,
            "onAc": true,
            "currentHz": 240
        });
        check(ipc.refreshSelection === 240, "manual Hz selected after Auto off");
        ipc.chooseRefresh("auto");
        check(ipc.queue[0].method === "display.auto.set" && ipc.queue[0].params.enabled === true, "Auto segment sends native boolean enabled");
        check(ipc.refreshSelection === null, "selection waits for mutation readback");
        ipc.applying = false;
        ipc.queue = [];
        ipc.chooseRefresh(144);
        check(!ipc.queue.length, "unadvertised Hz never dispatched");
        response("display.auto.set", {
            "enabled": true,
            "onAc": true,
            "currentHz": 240
        });
        check(!ipc.autoKnown && ipc.errorText.indexOf("Invalid") >= 0, "missing Auto mutation outcome cannot report success");
        response("capabilities.get", {
            "methods": ["display.set"]
        });
        check(!ipc.autoReady && ipc.refreshSelection === 240, "legacy backend keeps manual selection and disables Auto");
        console.log("ROG_STATE_TESTS_PASS", checks);
    }

    // Holding busy prevents any real process/socket from being started.
    Rog.RogIpc {
        id: ipc

        busy: true
    }

    Timer {
        interval: 20
        running: true
        onTriggered: Qt.quit()
    }

}
