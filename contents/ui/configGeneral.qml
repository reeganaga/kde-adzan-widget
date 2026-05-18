import QtQuick 2.0
import QtQuick.Controls 2.5
import QtQuick.Layouts 1.12
import org.kde.kirigami 2.4 as Kirigami

Item {
    id: page

    property alias cfg_address:       addressField.text
    property alias cfg_updateHour:    updateHourSpinBox.value
    property alias cfg_minutesBefore: minutesBeforeSpinBox.value
    property alias cfg_enableOverlayNotification: enableOverlayNotificationCheck.checked
    property alias cfg_showCountdown: showCountdownCheck.checked

    Kirigami.FormLayout {
        anchors.left:  parent.left
        anchors.right: parent.right

        TextField {
            id:               addressField
            Kirigami.FormData.label: i18n("Location:")
            placeholderText:  i18n("e.g. Yogyakarta, Indonesia")
        }

        SpinBox {
            id:  updateHourSpinBox
            Kirigami.FormData.label: i18n("Daily update hour:")
            from: 0
            to:   23
        }

        SpinBox {
            id:  minutesBeforeSpinBox
            Kirigami.FormData.label: i18n("Notification offset:")
            from: 0
            to:   30
            stepSize: 1
            editable: true
            textFromValue: function(value) {
                return i18n("%1 minutes before", value)
            }
        }

        CheckBox {
            id: enableOverlayNotificationCheck
            Kirigami.FormData.label: i18n("Fullscreen alert:")
            text: i18n("Enable overlay notification")
        }

        CheckBox {
            id:  showCountdownCheck
            Kirigami.FormData.label: i18n("Next prayer display:")
            text: i18n("Show countdown (e.g. \"2h 15m to Asr\")")
        }
    }
}
