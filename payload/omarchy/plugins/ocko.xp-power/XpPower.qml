import QtQuick
import qs.Commons
import "../../xp/qml"

// XpPower: XP's Power Options Properties for ocko.xp-power. Geometry is the
// pinned binaries' own templates, converted from dialog units at Tahoma 8 /
// 96 dpi (1 DLU = 1.5 px across, 13/8 px down):
//   powercfg.cpl 100  Power Schemes, 252 x 218
//   stobject.dll 100  Power Meter (the tray's page), 252 x 218
// Power Meter's "Power status" box is filled at runtime by batmeter.dll in XP
// (no template); its rows here hold stock's battery readout.
// `host` is duck-typed (Panel.qml, or the harness's mock): batteryInfo,
// discharging, charging, chargeThresholdActive, batteryFull, batteryFlowIdle,
// batteryFraction, heroStatusText, rotatingPhrases, profiles, activeProfile,
// profileIndex, cursorActive, showPercentage, xpTab, setProfile(),
// togglePercentage(), close().
XpPropertySheet {
  id: sheet

  property var host
  property real statusOpacity: 1
  readonly property bool comboOpen: schemeCombo.open
  function closeCombo() { schemeCombo.open = false }

  function s(n) { return Style.space(n) }
  function du(x) { return Style.space(Math.round(x * 1.5)) }
  function dv(y) { return Style.space(Math.round(y * 13 / 8)) }
  // Stock's button label: first letter capitalised.
  function profileLabel(p) {
    var t = String(p || "")
    return t.charAt(0).toUpperCase() + t.slice(1)
  }
  function icon(id) { return XpScheme.graphics + "/powercfg/32/" + id + ".png" }

  readonly property int activeIndex: host.profiles.indexOf(host.activeProfile)
  readonly property string sourceLabel: host.discharging ? "Running on batteries" : "Plugged in"

  title: "Power Options Properties"
  titleIcon: XpScheme.graphics + "/powercfg/16/202.png"
  buttons: ["help", "close"]
  disabledButtons: ["help"]
  onCloseClicked: host.close()
  titles: ["Power Schemes", "Power Meter"]
  tab: host.xpTab
  onTabClicked: function(i) { schemeCombo.open = false; host.xpTab = i }
  pageWidth: du(252)
  pageHeight: dv(218)
  // Stock applies a profile the moment it is picked, so there is nothing
  // for Apply to do; OK and Cancel both close.
  buttonLabels: ["OK", "Cancel", "<u>A</u>pply"]
  disabledButtonIndices: [2]
  onButtonClicked: host.close()

  // -- Power Schemes (powercfg.cpl 100) --
  Item {
    parent: sheet.page
    anchors.fill: parent
    visible: sheet.tab === 0

    Image {
      x: sheet.du(7); y: sheet.dv(7)
      width: sheet.s(32); height: sheet.s(32)
      source: sheet.icon(202)
    }
    XpLabel {
      x: sheet.du(39); y: sheet.dv(7); width: sheet.du(206)
      wrapMode: Text.WordWrap
      text: "Select the power scheme with the most appropriate settings for this computer. The scheme you select takes effect at once."
    }

    XpGroupBox { x: sheet.du(7); y: sheet.dv(38); width: sheet.du(238); height: sheet.dv(52); caption: "Power schemes" }
    XpButton {
      x: sheet.du(134); y: sheet.dv(69); width: sheet.du(50); height: sheet.dv(14)
      text: "<u>S</u>ave As..."
      enabled: false
    }
    XpButton {
      x: sheet.du(188); y: sheet.dv(69); width: sheet.du(50); height: sheet.dv(14)
      text: "<u>D</u>elete"
      enabled: false
    }

    XpGroupBox {
      x: sheet.du(7); y: sheet.dv(97); width: sheet.du(238); height: sheet.dv(113)
      caption: sheet.activeIndex >= 0 ? "Settings for " + sheet.profileLabel(host.activeProfile) + " power scheme" : "Settings"
    }
    XpLabel { x: sheet.du(14); y: sheet.dv(111); text: "When computer is:" }
    Image {
      x: sheet.du(87); y: sheet.dv(106)
      width: sheet.s(32); height: sheet.s(32)
      source: sheet.icon(200)
    }
    XpLabel { x: sheet.du(113); y: sheet.dv(111); text: "Plugged in" }
    Image {
      x: sheet.du(161); y: sheet.dv(106)
      width: sheet.s(32); height: sheet.s(32)
      source: sheet.icon(201)
    }
    XpLabel {
      x: sheet.du(184); y: sheet.dv(108); width: sheet.du(40)
      wrapMode: Text.WordWrap
      text: "Running on batteries"
    }
    XpLabel { x: sheet.du(14); y: sheet.dv(131); text: "Power scheme:" }
    // Omarchy keeps a profile per power source and reports only the
    // current one, so only the current source's column has a value.
    XpLabel {
      x: sheet.du(host.discharging ? 166 : 87); y: sheet.dv(131)
      text: sheet.activeIndex >= 0 ? sheet.profileLabel(host.activeProfile) : "(none)"
    }
    XpEtched { x: sheet.du(14); y: sheet.dv(166); width: sheet.du(224) }
    XpLabel {
      x: sheet.du(14); y: sheet.dv(175); width: sheet.du(224)
      wrapMode: Text.WordWrap
      text: host.profiles.length > 0
        ? "Choosing a scheme above sets it for the current power source (" + sheet.sourceLabel.toLowerCase() + ")."
        : "No power profiles are available. power-profiles-daemon is not running."
    }

    // Declared last so its list opens over the groups below it.
    XpComboBox {
      id: schemeCombo
      x: sheet.du(14); y: sheet.dv(49); width: sheet.du(224)
      z: 10
      enabled: host.profiles.length > 0
      model: host.profiles.map(function(p) { return sheet.profileLabel(p) })
      currentIndex: host.cursorActive ? host.profileIndex : sheet.activeIndex
      focused: host.cursorActive
      onActivated: function(i) { host.setProfile(host.profiles[i]) }
    }
  }

  // -- Power Meter (stobject.dll 100) --
  Item {
    parent: sheet.page
    anchors.fill: parent
    visible: sheet.tab === 1

    // XP's "Always show icon on the taskbar." holds stock's right-click
    // toggle: the percentage beside the tray icon.
    XpCheckBox {
      x: sheet.du(6); y: sheet.dv(6)
      text: "Show <u>p</u>ercentage on the taskbar."
      checked: host.showPercentage
      onToggled: host.togglePercentage()
    }
    // One display device: nothing to break down per battery.
    XpCheckBox {
      x: sheet.du(135); y: sheet.dv(6)
      text: "Show details for each <u>b</u>attery."
      enabled: false
    }

    XpGroupBox { x: sheet.du(9); y: sheet.dv(20); width: sheet.du(234); height: sheet.dv(189); caption: "Power status" }

    XpLabel { x: sheet.du(17); y: sheet.dv(33); text: "Current power source:" }
    XpLabel { x: sheet.du(130); y: sheet.dv(33); text: host.discharging ? "Batteries" : "AC power" }
    XpLabel { x: sheet.du(17); y: sheet.dv(45); text: "Total battery power remaining:" }
    XpLabel { x: sheet.du(130); y: sheet.dv(45); text: host.batteryInfo.percentage || "—" }

    Image {
      x: sheet.du(17); y: sheet.dv(62)
      width: sheet.s(32); height: sheet.s(32)
      source: sheet.icon(host.charging ? 202 : 201)
    }
    XpProgress {
      x: sheet.du(45); y: sheet.dv(63); width: sheet.du(188); height: sheet.s(18)
      value: host.batteryFraction
    }
    // Stock's status line: "Fully charged", the rotating phrase while
    // current flows, or the mode label.
    XpLabel {
      x: sheet.du(45); y: sheet.dv(78); width: sheet.du(188)
      textFormat: Text.PlainText
      elide: Text.ElideRight
      opacity: sheet.statusOpacity
      text: host.heroStatusText + (host.rotatingPhrases ? "..." : "")
    }

    XpEtched { x: sheet.du(17); y: sheet.dv(94); width: sheet.du(218) }

    // Stock's stats, shown once data has ever loaded (stock's own guard).
    Item {
      anchors.fill: parent
      visible: host.batteryInfo.percentage !== undefined

      XpLabel { x: sheet.du(17); y: sheet.dv(103); text: "Battery size:" }
      XpLabel { x: sheet.du(130); y: sheet.dv(103); text: host.batteryInfo.size || "" }
      XpLabel { x: sheet.du(17); y: sheet.dv(115); text: "Charge cycles:" }
      XpLabel { x: sheet.du(130); y: sheet.dv(115); text: host.batteryInfo.cycles || "—" }
      XpLabel {
        x: sheet.du(17); y: sheet.dv(127)
        text: (host.chargeThresholdActive ? "Charge limit" : (host.discharging ? "Time left" : "Time to full")) + ":"
      }
      XpLabel {
        x: sheet.du(130); y: sheet.dv(127)
        text: host.chargeThresholdActive ? (host.batteryInfo.threshold || "-") : (host.batteryFlowIdle ? "-" : (host.batteryInfo.time || "—"))
      }
      XpLabel {
        x: sheet.du(17); y: sheet.dv(139)
        text: (host.chargeThresholdActive ? "Battery state" : (host.discharging ? "Discharging" : "Charging")) + ":"
      }
      XpLabel {
        x: sheet.du(130); y: sheet.dv(139)
        text: host.chargeThresholdActive ? "Holding" : (host.batteryFull ? "-" : (host.batteryInfo.rate || ""))
      }
    }
  }
}
