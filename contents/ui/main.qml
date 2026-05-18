import QtQuick 2.9
import QtQuick.Layouts 1.3
import QtQuick.Window 2.12
import QtGraphicalEffects 1.15
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents
import org.kde.plasma.plasmoid 2.0

Item {
    id: root

    // ── Config ─────────────────────────────────────────────────────────────────
    property string configAddress:       plasmoid.configuration.address
    property int    configUpdateHour:    plasmoid.configuration.updateHour
    property int    configMinutesBefore: plasmoid.configuration.minutesBefore
    property bool   configEnableOverlayNotification: plasmoid.configuration.enableOverlayNotification
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
    property string activeAudioCmd:      ""

    property bool   notificationVisible:          false
    property bool   notificationIsNow:            false
    property string notificationPrayerName:       ""
    property int    notificationPrayerMinutes:    -1
    property int    notificationMinutesRemaining: 0
    property var    notifiedEvents:               ({})
    property string lastNotificationDayKey:       ""
    property var    overlayScreens:               []

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

            // ── Actions ────────────────────────────────────────────────────────
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: units.smallSpacing

                PlasmaComponents.Button {
                    text:    i18n("Refresh")
                    enabled: !root.isLoading
                    onClicked: root.fetchPrayerTimes()
                }

                // PlasmaComponents.Button {
                //     text: i18n("Test notif")
                //     onClicked: root.triggerTestNotification()
                // }
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

    function dateKey(dateObj) {
        return dateObj.getFullYear() + "-" + pad2(dateObj.getMonth() + 1) + "-" + pad2(dateObj.getDate())
    }

    function minuteDifference(targetMinutes, nowMinutes) {
        var diff = targetMinutes - nowMinutes
        if (diff < 0) diff += 24 * 60
        return diff
    }

    function normalizedMinute(minutesValue) {
        var dayMinutes = 24 * 60
        return ((minutesValue % dayMinutes) + dayMinutes) % dayMinutes
    }

    function hasTriggered(dayKey, prayerName, phase) {
        return root.notifiedEvents[dayKey + "|" + prayerName + "|" + phase] === true
    }

    function markTriggered(dayKey, prayerName, phase) {
        root.notifiedEvents[dayKey + "|" + prayerName + "|" + phase] = true
    }

    function playAudioCommand(cmd) {
        if (!cmd || cmd === "") return
        if (root.activeAudioCmd !== "") {
            audioDataSource.disconnectSource(root.activeAudioCmd)
            root.activeAudioCmd = ""
        }
        root.activeAudioCmd = cmd
        audioDataSource.connectSource(cmd)
    }

    function playReminderBeep() {
        playAudioCommand("sh -c 'if command -v paplay >/dev/null; then paplay /usr/share/sounds/freedesktop/stereo/message.oga; elif command -v canberra-gtk-play >/dev/null; then canberra-gtk-play -i message; fi'")
    }

    function playAthanAudio() {
        playAudioCommand("sh -c 'if [ -f \"$HOME/.local/share/adzan/athan.mp3\" ]; then if command -v mpv >/dev/null; then mpv --no-video --really-quiet \"$HOME/.local/share/adzan/athan.mp3\"; elif command -v ffplay >/dev/null; then ffplay -nodisp -autoexit -loglevel quiet \"$HOME/.local/share/adzan/athan.mp3\"; elif command -v paplay >/dev/null; then paplay /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga; fi; elif command -v paplay >/dev/null; then paplay /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga; fi'")
    }

    function refreshOverlayScreens() {
        var screens = Qt.application.screens || []
        var unique = []
        var seen = ({})

        for (var i = 0; i < screens.length; i++) {
            var s = screens[i]
            if (!s || !s.geometry) continue
            var key = s.geometry.x + ":" + s.geometry.y + ":" + s.geometry.width + ":" + s.geometry.height
            if (seen[key] === true) continue
            seen[key] = true
            unique.push(s)
        }

        if (unique.length === 0 && screens.length > 0) {
            unique = screens
        }

        root.overlayScreens = unique
    }

    function showPreparation(prayerName, prayerMinutes) {
        var now = new Date()
        var nowMinutes = now.getHours() * 60 + now.getMinutes()

        if (root.configEnableOverlayNotification) {
            refreshOverlayScreens()
            root.notificationVisible = true
            root.notificationIsNow = false
            root.notificationPrayerName = prayerName
            root.notificationPrayerMinutes = prayerMinutes
            root.notificationMinutesRemaining = minuteDifference(prayerMinutes, nowMinutes)
        }
        playReminderBeep()
    }

    function showNow(prayerName, prayerMinutes) {
        if (root.configEnableOverlayNotification) {
            refreshOverlayScreens()
            root.notificationVisible = true
            root.notificationIsNow = true
            root.notificationPrayerName = prayerName
            root.notificationPrayerMinutes = prayerMinutes
            root.notificationMinutesRemaining = 0
        }
        playAthanAudio()
    }

    function dismissNotification() {
        root.notificationVisible = false
    }

    function triggerTestNotification() {
        var testName = root.nextPrayerName && root.nextPrayerName !== "" ? root.nextPrayerName : i18n("Prayer")
        var now = new Date()
        var nowMinutes = now.getHours() * 60 + now.getMinutes()

        if (root.configMinutesBefore > 0) {
            var simulatedPrayerMinutes = normalizedMinute(nowMinutes + root.configMinutesBefore)
            showPreparation(testName, simulatedPrayerMinutes)
        } else {
            showNow(testName, nowMinutes)
        }
    }

    function checkPrayerTriggers() {
        if (!root.timings || Object.keys(root.timings).length === 0) return

        var now = new Date()
        var dayKey = dateKey(now)
        var nowMinutes = now.getHours() * 60 + now.getMinutes()

        if (root.lastNotificationDayKey !== dayKey) {
            root.notifiedEvents = ({})
            root.lastNotificationDayKey = dayKey
        }

        if (root.notificationVisible && !root.notificationIsNow && root.notificationPrayerMinutes >= 0) {
            root.notificationMinutesRemaining = minuteDifference(root.notificationPrayerMinutes, nowMinutes)
        }

        for (var i = 0; i < root.prayerNames.length; i++) {
            var prayerName = root.prayerNames[i]
            var prayerMinutes = timeToMinutes(root.timings[prayerName])
            if (prayerMinutes < 0) continue

            if (root.configMinutesBefore > 0) {
                var prepMinutes = normalizedMinute(prayerMinutes - root.configMinutesBefore)
                if (nowMinutes === prepMinutes && !hasTriggered(dayKey, prayerName, "prep")) {
                    markTriggered(dayKey, prayerName, "prep")
                    showPreparation(prayerName, prayerMinutes)
                }
            }

            if (nowMinutes === prayerMinutes && !hasTriggered(dayKey, prayerName, "main")) {
                markTriggered(dayKey, prayerName, "main")
                showNow(prayerName, prayerMinutes)
            }
        }
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

    PlasmaCore.DataSource {
        id: audioDataSource
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            if (sourceName !== root.activeAudioCmd) return
            disconnectSource(sourceName)
            root.activeAudioCmd = ""

            if (data["exit code"] !== 0) {
                console.log("[Adzan] Audio command failed:", data["stderr"] || "")
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
            root.checkPrayerTriggers()
        }
    }

    // Checks every 10s to keep full-screen message and phase transitions in sync.
    Timer {
        interval: 10 * 1000
        repeat:   true
        running:  true
        onTriggered: root.checkPrayerTriggers()
    }

    // ── React to config changes ────────────────────────────────────────────────
    Connections {
        target: plasmoid.configuration
        function onAddressChanged()    { root.fetchPrayerTimes() }
        function onUpdateHourChanged() { /* no immediate action needed */ }
        function onMinutesBeforeChanged() {
            root.notifiedEvents = ({})
            root.checkPrayerTriggers()
        }
        function onEnableOverlayNotificationChanged() {
            if (!root.configEnableOverlayNotification) {
                root.dismissNotification()
            }
        }
        function onShowCountdownChanged() { root.nextPrayerCountdown = root.computeCountdown() }
    }

    Instantiator {
        id: overlayWindows
          model: root.notificationVisible && root.configEnableOverlayNotification
                    ? (root.overlayScreens.length > 0
                        ? root.overlayScreens.length
                        : ((Qt.application.screens && Qt.application.screens.length) ? Qt.application.screens.length : 1))
                    : 0

        delegate: Window {
                property var screenObj: root.overlayScreens.length > 0
                                                ? root.overlayScreens[index]
                                                : ((Qt.application.screens && Qt.application.screens.length > index)
                                                    ? Qt.application.screens[index]
                                                    : null)
                property var g: screenObj && screenObj.geometry
                                     ? screenObj.geometry
                                     : ({"x": 0, "y": 0, "width": 1920, "height": 1080})

            visible: root.notificationVisible
                flags: Qt.WindowStaysOnTopHint | Qt.FramelessWindowHint | Qt.Tool
            color: "transparent"
                x: g.x
                y: g.y
                width: g.width
                height: g.height

            Rectangle {
                id: backdropLayer
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#20334f" }
                    GradientStop { position: 0.55; color: "#294e5e" }
                    GradientStop { position: 1.0; color: "#132028" }
                }

                Rectangle {
                    x: parent.width * 0.05
                    y: parent.height * 0.12
                    width: parent.width * 0.45
                    height: parent.width * 0.45
                    radius: width / 2
                    color: "#70ffffff"
                    opacity: 0.25
                }

                Rectangle {
                    x: parent.width * 0.62
                    y: parent.height * 0.58
                    width: parent.width * 0.35
                    height: parent.width * 0.35
                    radius: width / 2
                    color: "#55cce8f5"
                    opacity: 0.3
                }
            }

            ShaderEffectSource {
                id: blurSource
                anchors.fill: parent
                sourceItem: backdropLayer
                hideSource: true
                live: true
            }

            FastBlur {
                anchors.fill: parent
                source: blurSource
                radius: 84
            }

            Rectangle {
                anchors.fill: parent
                color: "#7f0b1418"
            }

            Column {
                anchors.centerIn: parent
                spacing: 18

                PlasmaComponents.Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: root.notificationIsNow
                          ? i18n("Now")
                          : i18n("Preparation")
                    font.pixelSize: Math.max(36, Math.round(theme.defaultFont.pixelSize * 3.2))
                    font.bold: true
                    color: "#f3f8fb"
                }

                PlasmaComponents.Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: root.notificationIsNow
                          ? i18n("%1 has started", root.notificationPrayerName)
                          : i18n("%1 in %2 minutes", root.notificationPrayerName, root.notificationMinutesRemaining)
                    font.pixelSize: Math.max(30, Math.round(theme.defaultFont.pixelSize * 2.3))
                    font.bold: true
                    color: "#f3f8fb"
                }

                PlasmaComponents.Button {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: i18n("Dismiss")
                    onClicked: root.dismissNotification()
                }
            }
        }
    }

    // ── Initial load ───────────────────────────────────────────────────────────
    Component.onCompleted: {
        root.refreshOverlayScreens()
        root.fetchPrayerTimes()
    }
}
