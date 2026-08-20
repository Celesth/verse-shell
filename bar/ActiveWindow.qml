import QtQuick
import "root:/config"
import "root:/services"

Text {
    id: root

    property string title: ""

    color: Theme.muted
    font.pixelSize: Theme.fontSize(12)
    font.family: Theme.fontFamily
    elide: Text.ElideRight
    maximumLineCount: 1
    text: title || ""
    opacity: title ? 0.7 : 0
    anchors.verticalCenter: parent.verticalCenter

    Behavior on opacity {
        NumberAnimation { duration: 150 }
    }
}
