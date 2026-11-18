import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_intervalSec: intervalSpin.value
    property alias cfg_historyMin: historySpin.value

    Kirigami.FormLayout {
        QQC2.SpinBox {
            id: intervalSpin
            Kirigami.FormData.label: "Aktualisierung (s):"
            from: 1
            to: 10
        }
        QQC2.SpinBox {
            id: historySpin
            Kirigami.FormData.label: "Verlauf (Min.):"
            from: 1
            to: 10
        }
    }
}
