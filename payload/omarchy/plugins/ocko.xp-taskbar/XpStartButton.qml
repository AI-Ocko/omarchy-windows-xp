import QtQuick
import qs.Commons
import "../../xp/qml"

// [Start::Button] of the active scheme: 3-frame bitmap (normal, hot, pressed),
// SizingMargins 6,52,13,14; the flag is explorer.exe bitmap 143 and the label
// is Franklin Gothic Medium 14pt italic, white, with a 2,2 drop shadow in the
// scheme's textshadowcolor. 99 px wide at 96 dpi, the width of the green pill
// in reference/taskbar-luna-blue-1920x974.png.
Item {
  id: start

  required property string artDir
  required property string flagUrl
  required property color shadowColor
  property bool menuOpen: false
  signal activated()

  implicitWidth: Style.space(99)

  XpArt {
    anchors.fill: parent
    source: start.artDir + "/start-" + (start.menuOpen || mouse.pressed ? 2 : mouse.containsMouse ? 1 : 0) + ".png"
    margins: [6, 52, 13, 14]
  }

  Row {
    // ContentMargins left 10, nudged down 1px when pressed like XP.
    x: Style.space(8)
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: mouse.pressed || start.menuOpen ? 0 : -Style.space(1)
    spacing: Style.space(4)

    Image {
      anchors.verticalCenter: parent.verticalCenter
      source: start.flagUrl
      width: Style.space(25)
      height: Style.space(20)
      smooth: true
    }

    Item {
      anchors.verticalCenter: parent.verticalCenter
      implicitWidth: label.implicitWidth
      implicitHeight: label.implicitHeight

      // TextShadowType = continuous (a soft shadow) at offset 2,2: two
      // stacked copies at 1 and 2 px approximate it without a blur effect.
      Repeater {
        model: 2
        Text {
          required property int index
          x: Style.spaceReal(index + 1)
          y: Style.spaceReal(index + 1)
          text: label.text
          font: label.font
          color: start.shadowColor
          opacity: 0.6
        }
      }

      Text {
        id: label
        text: "start"
        color: "#FFFFFF"
        font.family: "Franklin Gothic Medium"
        font.italic: true
        font.pixelSize: Style.font.iconLarge
      }
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    onClicked: start.activated()
  }
}
