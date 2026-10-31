import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "../../xp/qml"

// XpLockView: the Windows XP Welcome screen as omarchy.lock's view. Same
// interface as the stock LockView.qml (properties, signals,
// forcePasswordFocus, clearPassword), so Service.qml drives it unchanged.
//
// Geometry, colours, fonts and strings are logonui.exe's own: its UIFILE
// resource 1000 (the DirectUI markup) and STRING table, read out of
// assets/binaries/logonui.exe. 1 rp = Style.space(1); n pt = n x 4/3 rp.
//   top band 80 rp rgb(0,48,156), bitmap 125 as its bottom line (2 rp)
//   bottom band gradient rgb(57,52,173) -> rgb(0,48,156), bitmap 126 on top,
//     padding 25/20 rp; "Turn off computer" Tahoma 14 pt beside bitmap 107;
//     the instruction text right, 325 rp wide, 9 pt, 18 rp left padding
//   field rgb(90,126,220), bitmap 100 (glow) at its top left; a left and a
//     right panel, 384 rp each, centred
//   left: logo 123 top-right with 20 rp right/bottom padding; the help text
//     below, Arial 14 pt rgb(239,247,255), right-aligned, 40 rp right padding
//   right: bitmap 124 as a 1 rp divider, the account list 26 rp in
//   account item (80 rp): user pane with highlight 112 inside a 5 rp border
//     of field colour (left/top/bottom) and 2/2/14/2 rp padding; picture
//     frame 119 (58 rp, selected) with the 48 px picture centred, 7 rp right
//     margin; user name Tahoma 14 pt rgb(239,247,255). Password panel over
//     it, 71 rp in: "Type your password" Arial 8 pt white, then the 163 rp
//     field on bitmap 102 (borders 3/3/5/5, U+25CF in Arial), go (103/104,
//     26 rp, the keyboard-focused art when hot) and ? (105/106, 28 rp)
//   status "Logging on..." Tahoma 8 pt bold rgb(239,247,255)
//   wrong password: balloon "Did you forget your password?" + STRING 8
// The art is assets/graphics/logon/<id>.png (bin/xp-taskbar-art). If it is
// not there, the stock LockView is shown instead: never a lock without a
// password field, and never two.
Item {
  id: root

  // ---- the stock LockView interface (Service.qml binds these)
  property string backgroundPath: ""
  property int backgroundVersion: 0
  property bool fingerprintConfigured: false
  property bool authenticatingPassword: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool loadBackground: true
  property string passwordText: ""
  property bool syncingPasswordText: false

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()

  function forcePasswordFocus() {
    if (xpReady) passwordInput.forceActiveFocus()
    else if (stockLoader.item) stockLoader.item.forcePasswordFocus()
  }

  function clearPassword() {
    passwordTextEdited("")
  }

  function syncPasswordText() {
    if (!xpReady || passwordInput.text === passwordText) return
    syncingPasswordText = true
    passwordInput.text = passwordText
    syncingPasswordText = false
  }

  onPasswordTextChanged: syncPasswordText()
  onInputEnabledChanged: {
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }
  Component.onCompleted: {
    syncPasswordText()
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }

  // ---- XP
  readonly property string home: Quickshell.env("HOME")
  readonly property string art: "file://" + home + "/.config/omarchy/xp/assets/graphics/logon/"
  readonly property string userLogin: Quickshell.env("USER") || Quickshell.env("LOGNAME") || ""
  property string fullName: userLogin
  property string pictureUrl: art + "114.png"
  property bool hintOpen: false

  function rp(n) { return Style.space(n) }
  function pt(n) { return Style.space(n * 4 / 3) }
  function png(id) { return art + id + ".png" }

  readonly property color field: "#5A7EDC"
  readonly property color ink: "#EFF7FF"
  readonly property bool errorState: failureMessage.length > 0

  // Loaded synchronously: the view must decide at once, and every piece it
  // needs to draw a usable password row has to be there.
  Image { id: probeField; visible: false; asynchronous: false; source: root.png(102) }
  Image { id: probeGo; visible: false; asynchronous: false; source: root.png(103) }
  Image { id: probeLogo; visible: false; asynchronous: false; source: root.png(123) }
  readonly property bool xpReady: probeField.status === Image.Ready && probeGo.status === Image.Ready
    && probeLogo.status === Image.Ready

  // GECOS full name, as the XP Start menu shows it.
  FileView {
    path: "/etc/passwd"
    blockLoading: true
    printErrors: false
    onLoaded: {
      var lines = String(text()).split("\n")
      for (var i = 0; i < lines.length; i++) {
        var f = lines[i].split(":")
        if (f[0] !== root.userLogin) continue
        var gecos = String(f[4] || "").split(",")[0].trim()
        if (gecos) root.fullName = gecos
      }
    }
  }

  // The account picture the XP Start menu uses (omarchy/xp/start-menu.json).
  FileView {
    path: root.home + "/.config/omarchy/xp/start-menu.json"
    blockLoading: true
    printErrors: false
    onLoaded: {
      try {
        var p = String(JSON.parse(text()).picture || "chess")
        root.pictureUrl = "file://" + (p.charAt(0) === "/" ? p
          : root.home + "/.config/omarchy/xp/assets/graphics/account-pictures/" + p + ".bmp")
      } catch (e) {}
    }
  }

  // ---- fallback: the stock view, only when the XP art is missing
  Loader {
    id: stockLoader
    anchors.fill: parent
    active: !root.xpReady
    sourceComponent: LockView {
      backgroundPath: root.backgroundPath
      backgroundVersion: root.backgroundVersion
      fingerprintConfigured: root.fingerprintConfigured
      authenticatingPassword: root.authenticatingPassword
      failureMessage: root.failureMessage
      failedAttempts: root.failedAttempts
      inputEnabled: root.inputEnabled
      loadBackground: root.loadBackground
      passwordText: root.passwordText
      onSubmitPassword: function(password) { root.submitPassword(password) }
      onPasswordTextEdited: function(password) { root.passwordTextEdited(password) }
      onClearFailureRequested: root.clearFailureRequested()
      onWakeRequested: root.wakeRequested()
    }
  }

  // ---- the Welcome screen
  Rectangle {
    id: screen
    anchors.fill: parent
    visible: root.xpReady
    color: root.field

    readonly property real topH: root.rp(80)
    // divider + padding + the 26 rp power button + padding
    readonly property real bottomH: root.rp(2 + 20 + 26 + 20)
    readonly property real fieldTop: topH
    readonly property real fieldH: height - topH - bottomH
    // The two 384 rp panels, centred; 340 rp is the divider's own height.
    readonly property real blockW: root.rp(768)
    readonly property real blockH: root.rp(340)
    readonly property real blockX: Math.round((width - blockW) / 2)
    readonly property real blockY: Math.round(fieldTop + (fieldH - blockH) / 2)

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onClicked: { root.hintOpen = false; root.wakeRequested(); root.forcePasswordFocus() }
      onPositionChanged: root.wakeRequested()
    }

    // Glow, top left of the field.
    Image {
      x: 0; y: screen.fieldTop
      width: root.rp(219); height: root.rp(207)
      source: root.png(100)
      smooth: true
    }

    // Top band and its line.
    Rectangle {
      width: parent.width; height: screen.topH
      color: "#00309C"
      Image {
        anchors.bottom: parent.bottom
        width: parent.width; height: root.rp(2)
        source: root.png(125)
        fillMode: Image.Stretch
        smooth: true
      }
    }

    // Bottom band.
    Rectangle {
      id: bottomBand
      y: parent.height - screen.bottomH
      width: parent.width; height: screen.bottomH
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: "#3934AD" }
        GradientStop { position: 1; color: "#00309C" }
      }
      Image {
        width: parent.width; height: root.rp(2)
        source: root.png(126)
        fillMode: Image.Stretch
        smooth: true
      }

      // "Turn off computer": shown as XP showed it; no power actions from a
      // lock screen, so it does nothing.
      Item {
        id: power
        x: root.rp(25); y: root.rp(2 + 20)
        width: powerIcon.width + root.rp(2) + powerLabel.implicitWidth
        height: root.rp(26)
        Image {
          id: powerIcon
          width: root.rp(26); height: root.rp(26)
          source: root.png(powerMouse.containsMouse ? 121 : 107)
          smooth: true
        }
        Text {
          id: powerLabel
          x: powerIcon.width + root.rp(2)
          anchors.verticalCenter: parent.verticalCenter
          text: "Turn off computer"
          color: "white"
          font.family: "Tahoma"
          font.pixelSize: root.pt(14)
          font.underline: powerMouse.containsMouse
        }
        MouseArea { id: powerMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor }
      }

      Text {
        x: parent.width - root.rp(25) - width
        y: root.rp(2 + 20)
        width: root.rp(325)
        leftPadding: root.rp(18)
        text: "After you log on, you can add or change accounts.\nJust go to Control Panel and click User Accounts."
        wrapMode: Text.WordWrap
        color: "white"
        font.family: "Tahoma"
        font.pixelSize: root.pt(9)
      }
    }

    // Left panel: logo and the help text, right-aligned to the divider.
    Column {
      x: screen.blockX
      width: root.rp(384)
      anchors.verticalCenter: divider.verticalCenter
      spacing: 0

      Item {
        width: parent.width
        height: logo.height + root.rp(20)
        Image {
          id: logo
          anchors.right: parent.right
          anchors.rightMargin: root.rp(20)
          width: root.rp(137); height: root.rp(86)
          source: root.png(123)
          smooth: true
        }
      }
      Text {
        width: parent.width
        rightPadding: root.rp(40)
        horizontalAlignment: Text.AlignRight
        wrapMode: Text.WordWrap
        text: "This computer is locked.\nType your password to unlock."
        color: root.ink
        font.family: "Arial"
        font.pixelSize: root.pt(14)
      }
    }

    // Right panel: divider, then the account.
    Image {
      id: divider
      x: screen.blockX + root.rp(384)
      y: screen.blockY
      width: root.rp(1); height: screen.blockH
      source: root.png(124)
      fillMode: Image.Stretch
    }

    Item {
      id: account
      x: divider.x + root.rp(1 + 26)
      y: Math.round(divider.y + (divider.height - height) / 2)
      width: root.rp(384 - 1 - 26 - 5)
      height: root.rp(80)

      // User pane: highlight inside a field-coloured 5 rp border (l/t/b).
      Item {
        id: pane
        width: parent.width
        height: root.rp(5 + 2 + 58 + 2 + 5)
        Image {
          anchors.fill: parent
          anchors.leftMargin: root.rp(5)
          anchors.topMargin: root.rp(5)
          anchors.bottomMargin: root.rp(5)
          source: root.png(112)
          fillMode: Image.Stretch
          smooth: true
        }
        Image {
          id: frame
          x: root.rp(5 + 2); y: root.rp(5 + 2)
          width: root.rp(58); height: root.rp(58)
          source: root.png(119)
          smooth: true
          Image {
            anchors.centerIn: parent
            width: root.rp(48); height: root.rp(48)
            source: root.pictureUrl
            smooth: true
            onStatusChanged: if (status === Image.Error) source = root.png(114)
          }
        }
        Text {
          x: frame.x + frame.width + root.rp(7)
          y: root.rp(5 + 2)
          width: parent.width - x - root.rp(14)
          text: root.fullName
          elide: Text.ElideRight
          color: root.ink
          font.family: "Tahoma"
          font.pixelSize: root.pt(14)
        }
      }

      // Password panel, 71 rp in, at the bottom of the 80 rp item.
      Item {
        id: passwordPanel
        x: root.rp(71)
        width: parent.width - x
        height: parent.height
        visible: !root.authenticatingPassword

        Text {
          x: root.rp(3)
          anchors.bottom: row.top
          anchors.bottomMargin: root.rp(3)
          text: "Type your password"
          color: "white"
          font.family: "Arial"
          font.pixelSize: root.pt(8)
        }

        Row {
          id: row
          anchors.bottom: parent.bottom
          spacing: root.rp(5)

          Image {
            id: fieldImage
            width: root.rp(163); height: root.rp(26)
            anchors.verticalCenter: parent.verticalCenter
            source: root.png(102)
            fillMode: Image.Stretch
            smooth: true

            TextInput {
              id: passwordInput
              anchors.fill: parent
              anchors.leftMargin: root.rp(3 + 2)
              anchors.topMargin: root.rp(3)
              anchors.rightMargin: root.rp(5 + 2)
              anchors.bottomMargin: root.rp(5)
              verticalAlignment: TextInput.AlignVCenter
              clip: true
              activeFocusOnPress: true
              enabled: root.xpReady && root.inputEnabled && !root.authenticatingPassword
              readOnly: root.authenticatingPassword
              echoMode: TextInput.Password
              passwordCharacter: "●"
              passwordMaskDelay: 0
              color: "black"
              selectionColor: "#316AC5"
              selectedTextColor: "white"
              font.family: "Arial"
              // UIFILE says 16pt; at 4/3 px per pt that is 21 px, taller than
              // the field's 18 rp interior, so the dots are drawn at 16 rp.
              font.pixelSize: root.rp(16)
              cursorVisible: activeFocus && root.inputEnabled && !root.authenticatingPassword

              onTextChanged: {
                if (!root.syncingPasswordText) root.passwordTextEdited(text)
                if (text.length > 0) root.wakeRequested()
                if (text.length > 0 && root.failureMessage.length > 0) root.clearFailureRequested()
              }

              onAccepted: go.submit()

              Keys.onPressed: function(event) {
                root.wakeRequested()
                root.hintOpen = false
                if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
                  root.passwordTextEdited("")
                  event.accepted = true
                }
              }
            }
          }

          // Fingerprint hint, where XP put its keyboard-layout indicator.
          Text {
            visible: root.fingerprintConfigured
            anchors.verticalCenter: parent.verticalCenter
            text: "󰈷"
            color: "white"
            font.family: Style.font.family
            font.pixelSize: root.pt(14)
          }

          // Go: the same submit path as Enter (stock onAccepted).
          Image {
            id: go
            width: root.rp(26); height: root.rp(26)
            anchors.verticalCenter: parent.verticalCenter
            source: root.png(goMouse.containsMouse ? 104 : 103)
            smooth: true
            function submit() {
              var submitted = root.passwordText
              root.passwordTextEdited("")
              if (submitted.length > 0) root.submitPassword(submitted)
            }
            MouseArea {
              id: goMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              enabled: root.inputEnabled && !root.authenticatingPassword
              onClicked: { go.submit(); root.forcePasswordFocus() }
            }
          }

          Image {
            id: info
            width: root.rp(28); height: root.rp(28)
            anchors.verticalCenter: parent.verticalCenter
            source: root.png(infoMouse.containsMouse || root.hintOpen ? 106 : 105)
            smooth: true
            MouseArea {
              id: infoMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: { root.hintOpen = !root.hintOpen; root.forcePasswordFocus() }
            }
          }
        }
      }

      // Checking the password.
      Text {
        x: root.rp(71 + 3)
        y: root.rp(38)
        visible: root.authenticatingPassword
        text: "Logging on..."
        color: root.ink
        font.family: "Tahoma"
        font.pixelSize: root.pt(8)
        font.bold: true
      }
    }

    // Wrong password (STRINGs 10 and 8) or the password hint (13), below the
    // field with the tail pointing up at it.
    XpBalloon {
      id: balloon
      visible: root.xpReady && (root.errorState || root.hintOpen) && !root.authenticatingPassword
      x: account.x + passwordPanel.x + root.rp(10)
      y: account.y + account.height + root.rp(2)
      width: root.rp(330)
      tailDown: false
      tailX: root.rp(30)

      Column {
        width: balloon.width - 2 * balloon.padding
        spacing: root.rp(6)
        Text {
          text: root.errorState ? "Did you forget your password?" : "Password Hint:"
          font.family: "Tahoma"
          font.pixelSize: root.pt(8)
          font.bold: true
          color: XpScheme.infoText
        }
        Text {
          width: parent.width
          wrapMode: Text.WordWrap
          text: root.errorState
            ? "Please type your password again.\nBe sure to use the correct uppercase and lowercase letters."
            : "No password hint is set for this account."
          font.family: "Tahoma"
          font.pixelSize: root.pt(8)
          color: XpScheme.infoText
        }
      }
    }
  }
}
