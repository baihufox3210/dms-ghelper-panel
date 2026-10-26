import QtQuick
import qs.Common

Image {
    source: Qt.resolvedUrl(Theme.isLightMode ? "../assets/rog-black.svg" : "../assets/rog-white.svg")
    fillMode: Image.PreserveAspectFit
    sourceSize: Qt.size(128, 128)
    smooth: true
}
