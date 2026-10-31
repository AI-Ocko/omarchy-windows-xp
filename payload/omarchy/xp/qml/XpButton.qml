import QtQuick
import qs.Commons

// XpButton: [Button.Pushbutton] of the active scheme: 5 frames (normal, hot,
// pressed, disabled, defaulted), SizingMargins 8,8,9,9, Tahoma 8 black.
// 75x23 at 96 dpi like every XP dialog button, with XP's dotted focus
// rectangle when `focused`. Used by the taskbar's Run / Turn Off dialogs and
// every Task 8 dialog. (Was ocko.xp-taskbar/XpPushButton.qml.)
Item {
  id: btn

  property string artDir: XpScheme.artDir
  property string text: ""
  property bool isDefault: false
  property bool focused: false
  signal clicked()

  implicitWidth: Style.space(75)
  implicitHeight: Style.space(23)

  XpArt {
    anchors.fill: parent
    source: btn.artDir + "/btn-" + (!btn.enabled ? 3 : mouse.pressed ? 2 : mouse.containsMouse ? 1 : (btn.isDefault || btn.focused) ? 4 : 0) + ".png"
    margins: [8, 8, 9, 9]
  }

  Text {
    anchors.centerIn: parent
    anchors.horizontalCenterOffset: mouse.pressed ? Style.space(1) : 0
    anchors.verticalCenterOffset: mouse.pressed ? Style.space(1) : 0
    text: btn.text
    textFormat: Text.StyledText
    color: btn.enabled ? "#000000" : "#A1A192"
    font.family: "Tahoma"
    font.pixelSize: Style.font.bodySmall
  }

  // Dotted focus rectangle, as XP draws inside the focused button.
  Rectangle {
    visible: btn.focused
    anchors.fill: parent
    anchors.margins: Style.space(4)
    color: "transparent"
    border.width: 1
    border.color: "#000000"
    opacity: 0.45
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    onClicked: btn.clicked()
  }
}
