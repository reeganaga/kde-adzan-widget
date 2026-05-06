import QtQuick 2.9
import QtQuick.Layouts 1.3
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents
import org.kde.plasma.plasmoid 2.0

Item {
    id: root

    // ── Config ─────────────────────────────────────────────────────────────────
    property string configAddress:       plasmoid.configuration.address
    property int    configUpdateHour:    plasmoid.configuration.updateHour
    property bool   configShowCountdown: plasmoid.configuration.showCountdown

    // ── State ──────────────────────────────────────────────────────────────────
    readonly property var prayerNames: ["Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha"]

    property var    timings:             ({})
    property string nextPrayerName:      ""
    property string nextPrayerTime:      "--:--"
    property string nextPrayerCountdown: ""
    property string dateGregorian:       ""
    property string dateHijri:           ""
    property bool   isLoading:           false
    property string statusMessage:       ""
    property string activeCmd:           ""

    // ── Plasmoid properties ────────────────────────────────────────────────────
    // Force compact (text) view in the panel; popup opens on click
    Plasmoid.preferredRepresentation: Plasmoid.compactRepresentation

    Plasmoid.toolTipMainText: root.configShowCountdown
                              ? root.nextPrayerCountdown
                              : (root.nextPrayerName || i18n("Adzan"))
    Plasmoid.toolTipSubText:  root.configShowCountdown
                              ? ""
                              : (root.nextPrayerTime || i18n("Fetching prayer times…"))

    // ── Compact representation (shown inside the panel) ────────────────────────
    Plasmoid.compactRepresentation: MouseArea {
        id: compactRoot
        anchors.fill: parent

        // Width hint so the panel gives us enough room for the text
        Layout.minimumWidth:  compactRow.implicitWidth + units.smallSpacing * 2
        Layout.preferredWidth: compactRow.implicitWidth + units.smallSpacing * 2

        onClicked: plasmoid.expanded = !plasmoid.expanded

        RowLayout {
            id: compactRow
            anchors.centerIn: parent
            spacing: units.smallSpacing

            PlasmaComponents.Label {
                text:      root.configShowCountdown
                           ? (root.nextPrayerCountdown || i18n("Adzan"))
                           : (root.nextPrayerName || i18n("Adzan"))
                font.bold: true
            }
            PlasmaComponents.Label {
                visible: !root.configShowCountdown
                text:    root.nextPrayerTime
            }
        }
    }

    // ── Full representation (popup shown when widget is clicked) ───────────────
    Plasmoid.fullRepresentation: Item {
        Layout.preferredWidth:  280 * units.devicePixelRatio
        Layout.preferredHeight: 380 * units.devicePixelRatio

        ColumnLayout {
            anchors {
                top:    parent.top
                left:   parent.left
                right:  parent.right
                margins: units.largeSpacing
            }
            spacing: units.smallSpacing

            // ── Gregorian date ─────────────────────────────────────────────────
            PlasmaComponents.Label {
                Layout.fillWidth:    true
                horizontalAlignment: Text.AlignHCenter
                font.bold:           true
                font.pixelSize:      Math.round(theme.defaultFont.pixelSize * 1.2)
                text:                root.dateGregorian || i18n("—")
            }

            // ── Hijri date ─────────────────────────────────────────────────────
            PlasmaComponents.Label {
                Layout.fillWidth:    true
                horizontalAlignment: Text.AlignHCenter
                text:                root.dateHijri || ""
                opacity:             0.7
            }

            Rectangle {
                Layout.fillWidth: true
                height:           1
                color:            theme.textColor
                opacity:          0.2
            }

            // ── Prayer rows ────────────────────────────────────────────────────
            Repeater {
                model: root.prayerNames

                delegate: Rectangle {
                    Layout.fillWidth: true
                    height:  prayerRow.implicitHeight + units.smallSpacing * 2
                    color:   modelData === root.nextPrayerName
                             ? theme.highlightColor
                             : "transparent"
                    radius: 3

                    RowLayout {
                        id: prayerRow
                        anchors {
                            left:           parent.left
                            right:          parent.right
                            verticalCenter: parent.verticalCenter
                            leftMargin:     units.smallSpacing
                            rightMargin:    units.smallSpacing
                        }

                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text:      modelData
                            font.bold: modelData === root.nextPrayerName
                            color:     modelData === root.nextPrayerName
                                       ? theme.highlightedTextColor
                                       : theme.textColor
                        }
                        PlasmaComponents.Label {
                            text:      root.timings[modelData]
                                       ? root.timings[modelData].split(" ")[0]
                                       : "--:--"
                            font.bold: modelData === root.nextPrayerName
                            color:     modelData === root.nextPrayerName
                                       ? theme.highlightedTextColor
                                       : theme.textColor
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height:           1
                color:            theme.textColor
                opacity:          0.2
            }

            // ── Status / error ─────────────────────────────────────────────────
            PlasmaComponents.Label {
                Layout.fillWidth:    true
                horizontalAlignment: Text.AlignHCenter
                text:    root.isLoading ? i18n("Loading…") : root.statusMessage
                visible: root.isLoading || root.statusMessage !== ""
                opacity: 0.6
                font.pixelSize: theme.smallestFont.pixelSize
            }

            // ── Refresh button ─────────────────────────────────────────────────
            PlasmaComponents.Button {
                Layout.alignment: Qt.AlignHCenter
                text:    i18n("Refresh")
                enabled: !root.isLoading
                onClicked: root.fetchPrayerTimes()
            }
        }
    }

    // ── Helpers ────────────────────────────────────────────────────────────────
    function pad2(n) {
        return (n < 10 ? "0" : "") + n
    }

    function timeToMinutes(timeStr) {
        if (!timeStr) return -1
        var parts = timeStr.split(" ")[0].split(":")
        if (parts.length < 2) return -1
        return parseInt(parts[0], 10) * 60 + parseInt(parts[1], 10)
    }

    function computeCountdown() {
        var mins = timeToMinutes(root.timings[root.nextPrayerName])
        if (mins < 0) return ""
        var now     = new Date()
        var nowMins = now.getHours() * 60 + now.getMinutes()
        var diff    = mins - nowMins
        if (diff <= 0) diff += 24 * 60   // next day's Fajr wrap-around
        var h = Math.floor(diff / 60)
        var m = diff % 60
        if (h > 0) {
            return h + "h " + m + "m to " + root.nextPrayerName
        } else {
            return m + "m to " + root.nextPrayerName
        }
    }

    function updateNextPrayer() {
        var now     = new Date()
        var nowMins = now.getHours() * 60 + now.getMinutes()
        var found   = false

        for (var i = 0; i < prayerNames.length; i++) {
            var name = prayerNames[i]
            var mins = timeToMinutes(root.timings[name])
            if (mins >= 0 && mins > nowMins) {
                root.nextPrayerName = name
                root.nextPrayerTime = root.timings[name].split(" ")[0]
                found = true
                break
            }
        }

        // All prayers passed for today → fall back to Fajr
        if (!found) {
            root.nextPrayerName = "Fajr"
            root.nextPrayerTime = root.timings["Fajr"]
                                  ? root.timings["Fajr"].split(" ")[0]
                                  : "--:--"
        }

        root.nextPrayerCountdown = computeCountdown()
    }

    function fetchPrayerTimes() {
        if (!root.configAddress) {
            root.statusMessage = i18n("No address configured")
            return
        }

        // Abort any in-flight request
        if (root.activeCmd !== "") {
            prayerDataSource.disconnectSource(root.activeCmd)
            root.activeCmd = ""
        }

        root.isLoading     = true
        root.statusMessage = ""

        var d       = new Date()
        var dateStr = pad2(d.getDate()) + "-" + pad2(d.getMonth() + 1) + "-" + d.getFullYear()
        var url     = "https://api.aladhan.com/v1/timingsByAddress/" + dateStr
                    + "?address="                + encodeURIComponent(root.configAddress)
                    + "&method=3"
                    + "&shafaq=general"
                    + "&school=0"
                    + "&midnightMode=0"
                    + "&latitudeAdjustmentMethod=1"
                    + "&calendarMethod=UAQ"
                    + "&iso8601=false"

        console.log("[Adzan] Fetching URL:", url)

        // Use curl via PlasmaCore.DataSource (executable engine) instead of
        // XMLHttpRequest: Qt's XHR inside the Plasma shell process routinely
        // fails HTTPS with status=0 due to its SSL backend not being properly
        // initialised, while curl uses the system SSL stack and works reliably.
        var cmd = "curl -s --max-time 15 '" + url + "'"
        root.activeCmd = cmd
        prayerDataSource.connectSource(cmd)
    }

    // ── Network data source ──────────────────────────────────────────────────────
    // Runs curl as an external process to fetch prayer-time JSON.
    // This sidesteps Qt's XHR HTTPS/SSL issues inside the Plasma shell process.
    PlasmaCore.DataSource {
        id: prayerDataSource
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            if (sourceName !== root.activeCmd) return
            disconnectSource(sourceName)
            root.activeCmd = ""
            root.isLoading = false

            var exitCode = data["exit code"]
            var stdout   = data["stdout"] || ""
            var stderr   = data["stderr"] || ""

            if (exitCode !== 0 || stdout === "") {
                console.log("[Adzan] curl failed (exit " + exitCode + "):", stderr)
                root.statusMessage = i18n("Network error: cannot reach server")
                return
            }

            console.log("[Adzan] Response received, length:", stdout.length)
            try {
                var resp = JSON.parse(stdout)
                console.log("[Adzan] Parsed response code:", resp.code)
                if (resp.code === 200) {
                    root.timings       = resp.data.timings
                    root.dateGregorian = resp.data.date.readable || ""
                    var h              = resp.data.date.hijri
                    root.dateHijri     = h.day + " " + h.month.en + " " + h.year + " AH"
                    root.statusMessage = ""
                    console.log("[Adzan] Timings loaded. Fajr:", root.timings["Fajr"],
                                "Asr:", root.timings["Asr"], "Isha:", root.timings["Isha"])
                    root.updateNextPrayer()
                } else {
                    console.log("[Adzan] API returned non-200 code:", resp.code, resp.status)
                    root.statusMessage = i18n("API error: %1", resp.status)
                }
            } catch (e) {
                console.log("[Adzan] JSON parse error:", e,
                            "\nRaw (first 200 chars):", stdout.substring(0, 200))
                root.statusMessage = i18n("Parse error")
            }
        }
    }

    // ── Timers ─────────────────────────────────────────────────────────────────

    // Updates "next prayer" every minute; triggers daily fetch at the configured hour
    Timer {
        interval: 60 * 1000
        repeat:   true
        running:  true
        onTriggered: {
            var now = new Date()
            if (now.getHours() === root.configUpdateHour && now.getMinutes() === 0) {
                root.fetchPrayerTimes()
            } else {
                root.updateNextPrayer()
            }
        }
    }

    // ── React to config changes ────────────────────────────────────────────────
    Connections {
        target: plasmoid.configuration
        function onAddressChanged()    { root.fetchPrayerTimes() }
        function onUpdateHourChanged() { /* no immediate action needed */ }
        function onShowCountdownChanged() { root.nextPrayerCountdown = root.computeCountdown() }
    }

    // ── Initial load ───────────────────────────────────────────────────────────
    Component.onCompleted: root.fetchPrayerTimes()
}
