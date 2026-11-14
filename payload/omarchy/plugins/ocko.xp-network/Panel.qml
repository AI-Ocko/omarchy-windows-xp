// ocko.xp-network: omarchy.network for the XP notification area (Windows XP
// theme only; see omarchy/xp/bin/xp-mode). Lines 9-1109 are the logic of
// /usr/share/omarchy/shell/plugins/panels/network/Panel.qml (omarchy.network 4.5.0,
// sha256 8beba301a1d87db144543ad888226099c3dd1c2999f2a52106964b5851959adb,
// lines 1-1100), with each change marked "XP:". The card below that is rebuilt
// as netshell's Status, Details and Properties and SP2's wireless window.
// Re-diff the logic against a newer Omarchy: diff <(sed -n 9,1109p Panel.qml) <(sed -n 1,1100p <stock>)

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.Ui
import qs.Commons
import qs.Commons as Commons
import "Model.js" as Model
import "../../xp/qml"  // XP

Panel {
  id: root
  moduleName: "omarchy.network"
  ipcTarget: "omarchy.network"
  // manageIpc: false so this panel can own the single IpcHandler the target
  // permits — needed for the toggleNetwork method below.
  manageIpc: false

  // Centralized close so callers can't forget to drop the passphrase prompt.
  function close() {
    root.controller.hide()
    cancelPasswordPrompt()
  }

  function cancelPasswordPrompt() {
    passwordSsid = ""
    passwordText = ""
    identityText = ""
  }

  // Live connection details from `ip` / /sys / iw.
  property var info: ({})  // { iface, type, ip, prefix, gateway, speed, duplex, ssid, signal, freq, bitrate, rx_bytes, tx_bytes, router_ping_ms, internet_ping_ms }

  // Throughput tracking. Rates are computed as deltas between successive
  // `omarchy-network-status --verbose` samples (~1.5s apart via detailsPoll).
  // We hold "prev" alongside a timestamp so the first sample after open or
  // after an interface switch doesn't manufacture a spike.
  property real prevRxBytes: 0
  property real prevTxBytes: 0
  property real prevSampleTime: 0
  property string prevIface: ""
  property real downloadRate: 0  // bytes/sec
  property real uploadRate: 0    // bytes/sec
  property string pingIface: ""
  property var routerPingSamples: []
  property var internetPingSamples: []
  property real routerPingLatency: -1
  property real internetPingLatency: -1
  property int internetPingPacketLoss: 0
  readonly property int pingHistoryWindow: 24
  readonly property int pingAverageWindow: 5
  readonly property bool hasInternetPing: Model.internetPingReadable(internetPingSamples, connectivity)
  // Every stat row stays mounted whether or not there is data behind it, so a
  // sample arriving late never reflows the grid. This says whether the numbers
  // are real yet or the row should read "--".
  readonly property bool hasTransferStats: info.rx_bytes !== undefined
  property int connectionPhraseIndex: 0
  readonly property var connectionPhrases: [
    Commons.I18n.t("network.phrase1"),
    Commons.I18n.t("network.phrase2"),
    Commons.I18n.t("network.phrase3"),
    Commons.I18n.t("network.phrase4"),
    Commons.I18n.t("network.phrase5"),
    Commons.I18n.t("network.phrase6"),
    Commons.I18n.t("network.phrase7")
  ]
  readonly property string connectionPhrase: connectionPhrases[connectionPhraseIndex % connectionPhrases.length]
  readonly property bool networkManagerAvailable: Networking.backend === NetworkBackendType.NetworkManager
  readonly property var networkDevices: Networking.devices ? Networking.devices.values : []
  readonly property var wifiDevice: findDevice(DeviceType.Wifi)
  readonly property var wifiNetworkObjects: wifiDevice && wifiDevice.networks ? wifiDevice.networks.values : []
  readonly property var connectedWifiNetwork: findConnectedWifiNetwork()
  property var wifiNetworks: []
  property bool scanning: false
  property bool wifiStationAvailable: false
  property string dnsProvider: ""
  property string pendingDnsProvider: ""
  // Wi-Fi band state from `omarchy-network-band`. `bandCurrent` is the band
  // the radio is actually on; `bandSelected` is the pinned choice ("auto" when
  // nothing is pinned), and the two differ whenever Auto is in effect.
  property string bandCurrent: ""
  property string bandSelected: "auto"
  property var bandAvailable: []
  property string pendingBand: ""

  // Per-row in-flight state. `actionSsid` flips on for the row whose action
  // is currently running so it can render "Connecting…" / "Disconnecting…" /
  // "Forgetting…". `passwordSsid` is the row currently expanded into
  // password-entry mode; we keep it open across refresh cycles so a slow scan
  // doesn't collapse the input the user is typing into. Rows must gate
  // comparisons on the matching `*Kind`/`*Reason` being non-empty so a
  // hidden-SSID row (ssid == "") doesn't collide with the "" defaults.
  property string actionSsid: ""
  property string actionKind: ""  // "connect" | "disconnect" | "forget"
  property string failureSsid: ""
  property string failureReason: ""
  property string passwordSsid: ""
  property string passwordText: ""
  property string identityText: ""

  // ConnectionFailReason values as a plain object, so Model.js helpers stay
  // pure JS and Node-testable.
  readonly property var connectionFailReasons: ({
    NoSecrets: ConnectionFailReason.NoSecrets,
    WifiAuthTimeout: ConnectionFailReason.WifiAuthTimeout,
    WifiNetworkLost: ConnectionFailReason.WifiNetworkLost,
    WifiClientDisconnected: ConnectionFailReason.WifiClientDisconnected,
    WifiClientFailed: ConnectionFailReason.WifiClientFailed
  })

  // True while any wifi action is mid-flight. Rows
  // disable themselves on this so clicks on the other rows don't silently
  // no-op against runNetworkAction's serialized guard.
  readonly property bool busy: actionKind !== ""

  // Index into `wifiNetworks` for keyboard navigation. -1 = no selection.
  property int selectedIndex: -1
  property bool wifiActionFocused: false
  property bool cursorActive: false

  // Keyboard focus zone for the panel. j/k crosses row boundaries:
  // header actions ⇄ portal ⇄ band ⇄ DNS row ⇄ Wi-Fi networks. h/l move
  // within header actions, band pills, or DNS providers.
  property string focusSection: "dns"  // "header" | "portal" | "band" | "dns" | "wifi"
  property int headerIndex: 0
  readonly property bool canDisconnect: !!connectedWifiNetwork
  readonly property bool headerHasDisconnect: false
  readonly property bool canShareWifi: info.type === "wifi" && canShareNetwork(connectedWifiNetwork)
  // The hero switch is the Wi-Fi radio, so it only exists when there is a
  // radio to switch. On a wired box it would otherwise sit there reading
  // "off" beside a perfectly live Ethernet connection.
  readonly property bool canToggleWifi: networkManagerAvailable && wifiStationAvailable
  readonly property int qrHeaderIndex: canShareWifi ? 0 : -1
  readonly property int speedHeaderIndex: canRunSpeedTest ? (canShareWifi ? 1 : 0) : -1
  readonly property int toggleHeaderIndex: canToggleWifi ? (canShareWifi ? 1 : 0) + (canRunSpeedTest ? 1 : 0) : -1
  readonly property int headerActionCount: (canShareWifi ? 1 : 0) + (canRunSpeedTest ? 1 : 0) + (canToggleWifi ? 1 : 0)
  readonly property bool qrHeaderHasCursor: cursorActive && focusSection === "header" && headerIndex === qrHeaderIndex
  readonly property bool speedHeaderHasCursor: cursorActive && focusSection === "header" && headerIndex === speedHeaderIndex
  readonly property bool toggleHeaderHasCursor: cursorActive && focusSection === "header" && headerIndex === toggleHeaderIndex
  readonly property string toggleHint: Networking.wifiEnabled ? Commons.I18n.t("network.turnWifiOff") : Commons.I18n.t("network.turnWifiOn")
  readonly property var dnsProviders: ["DHCP", "Cloudflare", "Google", "Custom"]
  property int dnsIndex: 0
  // ["2.4", "5", ...], or empty when there is nothing to choose between.
  // Wi-Fi only: on Ethernet the band of a secondary radio is not what the
  // panel is describing.
  // `bandBusy` keeps the section mounted across the reconnect a band change
  // causes: `kind` stops being "wifi" for a second or two in the middle of it,
  // and without this the whole segment would vanish and rebuild itself.
  // Worth showing when there is a real choice, or when a pin is in force even
  // though only one band answers right now -- otherwise the Automatic switch
  // vanishes and the pin becomes unclearable from the panel.
  readonly property bool canSelectBand: (kind === "wifi" || bandBusy)
    && (bandAvailable.length > 1 || bandPinned)
  // While a change is in flight, show the state that was asked for rather than
  // the one still in force, so the row answers the click immediately instead of
  // after the reconnect. actionProc puts it back if the change failed.
  readonly property string bandEffective: pendingBand !== "" ? pendingBand : bandSelected
  readonly property bool bandPinned: bandEffective !== "auto"
  // Under Automatic there is nothing to pick, so the pills collapse away and
  // the header states the live band instead.
  readonly property bool bandPillsVisible: canSelectBand && bandPinned
  readonly property string bandSectionTitle: Model.bandSectionTitle(bandEffective, bandCurrent, Commons.I18n.t, Commons.I18n.formatNumber)
  readonly property bool bandBusy: pendingBand !== ""
  // The DNS pills show a choice the moment it's made, and fall back if it fails.
  readonly property string dnsEffective: pendingDnsProvider !== "" ? pendingDnsProvider : dnsProvider
  // The speed test needs an interface to test, so its hero action only
  // appears once there is one.
  readonly property bool canRunSpeedTest: !!info.iface
  property int bandIndex: 0
  // The band section has up to two cursor rows: the Automatic switch on the
  // header line, then the pills. Same shape as wifiActionFocused.
  property bool bandAutoFocused: true

  onHeaderActionCountChanged: clampHeaderIndex()

  // Availability shifts as scans land, so the option list can shrink out from
  // under the cursor. Clamp the index and evacuate the section before it
  // disappears, or the panel is left highlighting nothing.
  onBandAvailableChanged: {
    if (bandIndex > bandAvailable.length - 1) bandIndex = Math.max(0, bandAvailable.length - 1)
  }

  onCanSelectBandChanged: {
    if (!canSelectBand && focusSection === "band") {
      focusSection = "dns"
      bandAutoFocused = true
    }
  }

  // Collapsing the pills out from under the cursor would leave it pointing at
  // nothing, so send it up to the switch that is still on screen.
  onBandPillsVisibleChanged: {
    if (!bandPillsVisible) bandAutoFocused = true
  }

  function clampHeaderIndex() {
    var max = Math.max(0, headerActionCount - 1)
    if (headerIndex > max) headerIndex = max
    if (headerIndex < 0) headerIndex = 0
  }

  function selectHeaderByDelta(delta) {
    headerIndex = Math.max(0, Math.min(headerActionCount - 1, headerIndex + delta))
  }

  function toggleNetwork() {
    if (!networkManagerAvailable) return
    Networking.wifiEnabled = !Networking.wifiEnabled
    Qt.callLater(function() { root.refresh(true) })
  }

  ShellIpc {
    target: "omarchy.network"

    function open() { root.open() }
    function close() { root.close() }
    function show() { root.open() }
    function hide() { root.close() }
    function toggle() { root.toggle() }
    function toggleNetwork() { root.toggleNetwork() }
    // Compat routes for configs that summon the centered cards through the
    // network target; both cards are their own plugins now.
    function showQr() { root.summonWifiQr(true) }
    function speedTest() { root.summonSpeedTest() }
    function openCaptivePortal() { root.openCaptivePortal() }
    function checkConnectivity() { root.checkConnectivity() }
  }

  function activateHeader() {
    if (headerIndex === qrHeaderIndex) summonWifiQr()
    else if (headerIndex === speedHeaderIndex) summonSpeedTest()
    else if (headerIndex === toggleHeaderIndex) toggleNetwork()
  }

  function setHeaderCursor(index) {
    cursorActive = true
    focusSection = "header"
    headerIndex = index
  }

  function selectDnsByDelta(delta) {
    dnsIndex = Math.max(0, Math.min(dnsProviders.length - 1, dnsIndex + delta))
  }

  function activateDns() {
    if (dnsIndex < 0 || dnsIndex >= dnsProviders.length) return
    setDns(dnsProviders[dnsIndex])
  }

  function selectBandByDelta(delta) {
    bandIndex = Math.max(0, Math.min(bandAvailable.length - 1, bandIndex + delta))
  }

  function activateBand() {
    if (bandAutoFocused) {
      toggleBandAuto()
      return
    }
    if (bandIndex < 0 || bandIndex >= bandAvailable.length) return
    setBand(bandAvailable[bandIndex])
  }

  // Switching Automatic off has to commit to something, so it pins whatever
  // band the radio already landed on -- the reading the pills are showing.
  function toggleBandAuto() {
    if (bandSelected !== "auto") {
      setBand("auto")
      return
    }
    if (bandCurrent === "") return
    setBand(bandCurrent)
  }

  // Park the cursor on the pinned band, so opening the panel highlights the
  // pill the user would expect. Under Automatic there are no pills, so the
  // cursor belongs on the switch.
  function syncBandIndex() {
    var idx = bandAvailable.indexOf(bandSelected)
    bandIndex = idx >= 0 ? idx : 0
    bandAutoFocused = !bandPillsVisible
  }

  function bandLabel(band) {
    return Model.bandLabel(band, Commons.I18n.t, Commons.I18n.formatNumber)
  }

  function bandTooltip(band) {
    return Model.bandTooltip(band, Commons.I18n.t, Commons.I18n.formatNumber)
  }

  // Single cursor model: exactly one highlighted spot across the whole
  // panel, located via `focusSection` + (`headerIndex` | `dnsIndex` |
  // `selectedIndex`). Mouse hover and keyboard nav both mutate this state
  // at the root; items never read containsMouse for visuals. See
  // CursorSurface for the shared chrome shared by rows and pills.
  readonly property color hoverFill: bar ? Style.hoverFillFor(bar.foreground, Commons.Color.accent) : "transparent"
  readonly property color selectedFill: bar ? Style.selectedFillFor(bar.foreground, Commons.Color.accent) : "transparent"

  // scannerEnabled lives on the shared WifiDevice, which has no reference
  // counting, and a bar widget is instantiated once per monitor. Tracking the
  // device this instance turned scanning on for keeps the release correct when
  // the panel closes, the device is replaced, or the widget is destroyed —
  // without a closed instance ever claiming the scanner.
  property var scannerDevice: null

  function setScannerEnabled(enabled) {
    var nextDevice = opened ? wifiDevice : null

    if (scannerDevice && scannerDevice !== nextDevice)
      scannerDevice.scannerEnabled = false

    scannerDevice = nextDevice

    if (scannerDevice)
      scannerDevice.scannerEnabled = enabled
  }

  Component.onDestruction: {
    if (scannerDevice) scannerDevice.scannerEnabled = false
  }

  // KeyboardPanel primes layer-shell focus whenever the panel opens. That's
  // what makes the SUPER+CTRL+W keybind land here with navigation ready.
  onOpenedChanged: {
    if (opened) {
      refresh(true)
      selectedIndex = wifiNetworks.length > 0 ? 0 : -1
      wifiActionFocused = false
      focusSection = hasCaptivePortal ? "portal" : (wifiNetworks.length > 0 ? "wifi" : "dns")
      var idx = dnsProviders.indexOf(dnsProvider)
      dnsIndex = idx >= 0 ? idx : 0
      syncBandIndex()
      cursorActive = hasCaptivePortal
    } else {
      // Drop a restart armed by this open: without it a close/reopen inside
      // the 100ms window reuses the running timer and re-enables the scanner
      // almost immediately, undoing the deferral #6605 restored.
      scanRestart.stop()
      // Reset throughput tracking so the next open doesn't compute a fake
      // rate from a sample taken minutes ago.
      prevSampleTime = 0
      downloadRate = 0
      uploadRate = 0
      pingIface = ""
      routerPingSamples = []
      internetPingSamples = []
      routerPingLatency = -1
      internetPingLatency = -1
      internetPingPacketLoss = 0
      setScannerEnabled(false)
    }
  }

  // When the passphrase prompt closes (Esc / Cancel / success) restore
  // focus to the keyCatcher so j/k/Enter resume working without a click.
  // The KeyboardPanel's focusTarget covers initial popup-open; this handles
  // the inline-editor case where focus was handed off to a child.
  onPasswordSsidChanged: {
    if (passwordSsid === "" && opened) {
      passwordText = ""
      Qt.callLater(function() { if (panel.loadedContent) panel.loadedContent.forceActiveFocus() })
    }
  }

  // Keep selectedIndex valid as scans refresh the network list.
  // If the list empties (station gone, e.g. wifi off), bounce the cursor
  // back to the DNS row so the panel doesn't end up with no cursor at all.
  onWifiNetworksChanged: {
    if (wifiNetworks.length === 0) {
      selectedIndex = -1
      wifiActionFocused = false
      if (focusSection === "wifi") focusSection = "dns"
    } else if (passwordSsid !== "") {
      var passwordIndex = wifiIndexForSsid(passwordSsid)
      if (passwordIndex >= 0) {
        selectedIndex = passwordIndex
        focusSection = "wifi"
      }
    } else if (selectedIndex >= wifiNetworks.length) {
      selectedIndex = wifiNetworks.length - 1
    } else if (selectedIndex < 0 && opened) {
      selectedIndex = 0
    }

    if (selectedIndex < 0 || selectedIndex >= wifiNetworks.length || !canForgetNetwork(wifiNetworks[selectedIndex])) {
      wifiActionFocused = false
    }
  }

  onWifiDeviceChanged: {
    setScannerEnabled(true)
    syncWifiNetworks()
    resetActiveApSignal()
  }

  onWifiNetworkObjectsChanged: syncWifiNetworks()

  function selectByDelta(delta) {
    if (wifiNetworks.length === 0) { selectedIndex = -1; return }
    if (selectedIndex < 0) selectedIndex = delta > 0 ? 0 : wifiNetworks.length - 1
    else selectedIndex = Math.max(0, Math.min(wifiNetworks.length - 1, selectedIndex + delta))
    wifiActionFocused = false
  }

  function canForgetNetwork(net) {
    return Model.canForgetNetwork(net)
  }

  function canShareNetwork(net) {
    if (!net || !net.connected) return false
    return net.security !== WifiSecurityType.Wpa2Eap && net.security !== WifiSecurityType.WpaEap
  }

  function selectWifiActionByDelta(delta) {
    if (selectedIndex < 0 || selectedIndex >= wifiNetworks.length) return
    if (!canForgetNetwork(wifiNetworks[selectedIndex])) {
      wifiActionFocused = false
      return
    }
    if (delta > 0) wifiActionFocused = true
    else if (delta < 0) wifiActionFocused = false
  }

  // Enter/Space on the highlighted row. Mirrors row-click semantics:
  // connected → disconnect, credentials-required/unknown → prompt,
  // passwordless/known → connect.
  function activateSelected() {
    if (busy || selectedIndex < 0 || selectedIndex >= wifiNetworks.length) return
    var net = wifiNetworks[selectedIndex]
    if (!net) return
    if (wifiActionFocused && canForgetNetwork(net)) { forget(net); return }
    // Only act on a row that still resolves. disconnect() falls back to
    // connectedWifiNetwork when handed null, so a row left stale by scan churn
    // would otherwise tear down whatever is connected now instead.
    if (net.connected) { disconnectRow(net.ssid); return }
    if (requiresCredentials(net.security) && !net.known) { openPasswordPrompt(net.ssid); return }
    connectDirectly(net.ssid)
  }

  // Bar pill state, derived from the native NetworkManager service so the
  // icon reflects connection changes without polling. Wired is preferred
  // when both are up, matching the default-route device.
  readonly property var wiredDevice: findDevice(DeviceType.Wired)
  readonly property string kind: {
    if (wiredDevice && wiredDevice.connected) return "ethernet"
    if (connectedWifiNetwork) return "wifi"
    // NetworkManager can leave the active profile out of the device's
    // AvailableConnections, and Quickshell only builds known networks from
    // that list. An OWE transition-mode network does this between scans: the
    // in-use access point carries the hidden "_owetm_" SSID, so the profile
    // for the open SSID looks out of range even while it is connected. Trust
    // the device's own state then instead of flickering to disconnected.
    if (wifiDevice && wifiDevice.connected) return "wifi"
    return "disconnected"
  }
  readonly property int signalStrength: kind === "wifi"
    ? Model.connectedSignalStrength(connectedWifiNetwork ? connectedWifiNetwork.signalStrength : 0, activeApSignal)
    : -1
  // Filled by activeApSignalPoll from nmcli while the connected network has no
  // strength of its own to report.
  property int activeApSignal: -1
  readonly property bool needsActiveApSignal: kind === "wifi"
    && !(connectedWifiNetwork && connectedWifiNetwork.signalStrength > 0)
  // Bumped whenever the cached reading stops describing the current link, so
  // an nmcli read still in flight from before cannot write a stale strength.
  property int activeApSignalGeneration: 0
  property int activeApSignalRequest: -1
  onKindChanged: if (kind !== "wifi") resetActiveApSignal()

  // Switching Wi-Fi networks always passes through a non-"wifi" kind (both the
  // device and the old network drop out of the connected state while the new
  // profile activates), so this also covers a change of network.
  function resetActiveApSignal() {
    activeApSignal = -1
    activeApSignalGeneration++
  }

  function pollActiveApSignal() {
    if (activeApSignalProc.running) return
    activeApSignalRequest = activeApSignalGeneration
    activeApSignalProc.running = true
  }

  function finishActiveApSignal(raw) {
    if (activeApSignalRequest !== activeApSignalGeneration) {
      // The link changed mid-read and the restarted poll skipped while this
      // one was running; read again now instead of a full interval later.
      if (needsActiveApSignal) activeApSignalPoll.restart()
      return
    }
    activeApSignal = Model.parseActiveApSignal(raw)
  }

  function copyToClipboard(value) {
    if (!value || !root.bar) return
    Quickshell.execDetached(["bash", "-c", "printf %s " + Util.shellQuote(value) + " | wl-copy"])
  }

  // NetworkManager performs the HTTP probe (including unexpected page bodies,
  // not just redirects). Consume its native notifications rather than running
  // a second curl loop or mistaking an ordinary timeout for a captive portal.
  readonly property bool connectivityChecksEnabled: networkManagerAvailable
    && Networking.canCheckConnectivity && Networking.connectivityCheckEnabled
  readonly property string connectivity: Model.connectivityState(kind, Networking.connectivity, {
    Portal: NetworkConnectivity.Portal, Limited: NetworkConnectivity.Limited,
    Full: NetworkConnectivity.Full, None: NetworkConnectivity.None
  }, connectivityChecksEnabled)
  readonly property bool hasCaptivePortal: connectivity === "portal"
  readonly property bool restricted: hasCaptivePortal || connectivity === "limited"
  readonly property string icon: Model.connectionIcon(kind, signalStrength, connectivity)
  // Keyed on the device rather than the SSID: on an OWE transition-mode
  // network the listed network comes and goes with every scan while the link
  // stays up, and a real network switch already passes through "disconnected".
  readonly property string connectionKey: kind === "wifi" && wifiDevice
    ? kind + ":" + wifiDevice.name
    : (kind === "ethernet" && wiredDevice ? kind + ":" + wiredDevice.name : "")

  onConnectionKeyChanged: Qt.callLater(checkConnectivity)
  onConnectivityChecksEnabledChanged: Qt.callLater(checkConnectivity)
  onHasCaptivePortalChanged: {
    if (hasCaptivePortal && opened && passwordSsid === "") {
      focusSection = "portal"
      cursorActive = true
    } else if (!hasCaptivePortal && focusSection === "portal") {
      focusSection = headerActionCount > 0 ? "header" : "dns"
      headerIndex = 0
    }
  }
  onRestrictedChanged: {
    connectionPhraseSwap.stop()
    if (panel.loadedContent) panel.loadedContent.heroMeta.opacity = 1.0
  }

  function checkConnectivity() {
    if (connectivityChecksEnabled && kind !== "disconnected") Networking.checkConnectivity()
  }

  function openCaptivePortal() {
    if (!hasCaptivePortal) return
    // Explicit user action only. argv (not a shell string), and a fixed HTTP
    // URL: let the browser handle the redirect without trusting portal input.
    // The command pauses a Tailscale exit node and re-checks quickly until the
    // sign-in completes.
    Quickshell.execDetached(["omarchy-network-captive-portal", Model.captivePortalUrl])
    close()
  }

  // Keep checking while login is needed, even with the panel closed in favour
  // of the browser. Normal connected operation relies on NM's own schedule.
  Timer {
    id: connectivityPoll
    interval: 10000
    repeat: true
    running: root.restricted && root.connectivityChecksEnabled
    onTriggered: root.checkConnectivity()
  }

  // The share card is its own panel plugin (omarchy.wifiqr) so a replacement
  // design can take it over; summon() routes to whichever implementation is
  // enabled. The panel's own button pins the interface it is showing. The
  // IPC route forces self-detection instead: details polling stops while the
  // panel is closed, so its cached interface can be stale.
  function summonWifiQr(forceDetect) {
    controller.hide()
    cancelPasswordPrompt()
    var payload = {}
    if (!forceDetect && info.type === "wifi" && info.iface) {
      payload.iface = info.iface
      if (info.ssid) payload.ssid = info.ssid
    }
    bar.shell.summon("omarchy.wifiqr", JSON.stringify(payload))
  }

  function refresh(scanWifi) {
    checkConnectivity()
    if (scanWifi === undefined) scanWifi = false
    if (!detailsProc.running) detailsProc.running = true
    if (!dnsProc.running) {
      dnsProc.command = ["bash", "-c", root.dnsCommand("")]
      dnsProc.running = true
    }
    if (!bandProc.running) {
      bandProc.command = ["omarchy-network-band"]
      bandProc.running = true
    }
    // A closed panel has no nearby-network list to fill, and bare refresh()
    // reaches here from action completion, timeouts and construction.
    if (opened && wifiDevice) {
      if (scanWifi) {
        scanning = true
        setScannerEnabled(false)
        scanRestart.start()
      } else {
        setScannerEnabled(true)
      }
    }
    syncWifiNetworks()
  }

  function formatHeaderSpeed(mbps) {
    return Model.formatHeaderSpeed(mbps, Commons.I18n.formatNumber)
  }

  function formatHeaderFreq(mhz) {
    return Model.formatHeaderFreq(mhz, Commons.I18n.formatNumber)
  }

  function headerDetail() {
    return Model.headerDetail(info, Commons.I18n.formatNumber)
  }

  function updateDetails(raw) {
    var next = Model.parseKeyValue(raw)

    // A band change tears the link down and brings it back, and the status
    // command reports nothing at all while there is no route. Publishing that
    // would blank every stat and unmount the whole section mid-toggle, so the
    // last good sample stands until the reconnect settles. A real disconnect is
    // still reported, because nothing is in flight then.
    if (bandBusy && !next.iface) return

    info = next
    updateThroughput(next)
    updatePingLatency(next)
  }

  function updateThroughput(next) {
    var state = Model.throughputState({
      prevIface: prevIface,
      prevRxBytes: prevRxBytes,
      prevTxBytes: prevTxBytes,
      prevSampleTime: prevSampleTime,
      downloadRate: downloadRate,
      uploadRate: uploadRate
    }, next, Date.now() / 1000)

    prevIface = state.prevIface
    prevRxBytes = state.prevRxBytes
    prevTxBytes = state.prevTxBytes
    prevSampleTime = state.prevSampleTime
    downloadRate = state.downloadRate
    uploadRate = state.uploadRate
  }

  function updatePingLatency(next) {
    var state = Model.pingLatencyState({
      pingIface: pingIface,
      routerPingSamples: routerPingSamples,
      internetPingSamples: internetPingSamples
    }, next, pingHistoryWindow, pingAverageWindow)

    pingIface = state.pingIface
    routerPingSamples = state.routerPingSamples
    internetPingSamples = state.internetPingSamples
    routerPingLatency = state.routerPingLatency
    internetPingLatency = state.internetPingLatency
    internetPingPacketLoss = state.internetPingPacketLoss
  }

  function formatBytes(bytes) {
    return Model.formatBytes(bytes, Commons.I18n.formatNumber)
  }

  function formatRate(bytesPerSec) {
    return Model.formatRate(bytesPerSec, Commons.I18n.formatNumber)
  }

  function formatPingLatency(ms) {
    return Model.formatPingLatency(ms, hasInternetPing, Commons.I18n.t, Commons.I18n.formatNumber)
  }

  function formatPacketLoss(percent) {
    return Model.formatPacketLoss(percent, hasInternetPing, Commons.I18n.formatNumber)
  }

  // Prefer a connected device: a machine can expose several NICs of the
  // same type (e.g. an idle onboard port alongside the active adapter),
  // and the first-enumerated one may be carrierless.
  function findDevice(type) {
    var devices = networkDevices || []
    var fallback = null
    for (var i = 0; i < devices.length; i++) {
      var device = devices[i]
      if (!device || device.type !== type) continue
      if (device.connected) return device
      if (!fallback) fallback = device
    }
    return fallback
  }

  function findConnectedWifiNetwork() {
    var networks = wifiNetworkObjects || []
    for (var i = 0; i < networks.length; i++) {
      if (networks[i] && networks[i].connected) return networks[i]
    }
    return null
  }

  function syncWifiNetworks() {
    var nets = []
    var networks = wifiNetworkObjects || []

    for (var i = 0; i < networks.length; i++) {
      var network = networks[i]
      if (!network) continue
      checkActionCompletion(network)
      var row = Model.wifiRow(network)
      if (row) nets.push(row)
    }
    wifiNetworks = Model.sortWifiRows(nets)
    wifiStationAvailable = !!wifiDevice
    scanning = false
  }

  function wifiSectionTitle(index) {
    return Model.wifiSectionTitle(wifiNetworks, index, Commons.I18n.t)
  }

  function wifiIconFor(strength) {
    return Model.wifiIconFor(strength)
  }

  function updateDns(raw) {
    var value = String(raw || "").trim()
    dnsProvider = value || "DHCP"
  }

  function updateBand(raw) {
    var status = Model.parseBandStatus(raw)

    // Mid-reconnect there is no connected station, so the command reports
    // nothing. Publishing that would empty the option list and unmount the
    // section on every toggle -- same guard as updateDetails.
    if (bandBusy && status.available.length === 0) return

    bandCurrent = status.band
    bandSelected = status.selected
    bandAvailable = status.available
  }

  // Pinning a band reassociates, but the panel deliberately stays open: the
  // reconnect is the thing you want to watch, and the details rows above
  // report it as it happens.
  function setBand(band) {
    if (!band || actionProc.running) return

    root.pendingBand = band
    actionProc.command = ["omarchy-network-band", band]
    actionProc.running = true
  }

  // The speed test is its own panel plugin (omarchy.speedtest) so a
  // replacement design can take it over; summon() routes to whichever
  // implementation is enabled. The payload names the connection when this
  // panel knows it; the plugin looks it up itself otherwise.
  function summonSpeedTest() {
    controller.hide()
    cancelPasswordPrompt()
    var connection = ""
    if (info.type === "wifi") connection = info.ssid || "Wi-Fi"
    else if (info.type === "ethernet") connection = Commons.I18n.t("network.ethernet")
    bar.shell.summon("omarchy.speedtest", connection ? JSON.stringify({ connection: connection }) : "{}")
  }

  function dnsCommand(provider) {
    var command = "omarchy-dns"
    if (provider) command += " " + Util.shellQuote(provider)
    return command
  }

  function setDns(provider) {
    if (!root.bar || !provider || actionProc.running) return

    if (provider === "Custom") {
      var launcher = "omarchy-launch-floating-terminal-with-presentation"
      root.bar.run(launcher + " " + Util.shellQuote(root.dnsCommand(provider)))
      root.close()
      return
    }

    // The panel stays open, so the choice can be seen taking hold and another
    // tried without reopening it.
    root.pendingDnsProvider = provider
    actionProc.command = ["bash", "-c", root.dnsCommand(provider)]
    actionProc.running = true
  }

  function requiresCredentials(security) {
    return Model.requiresCredentials(security, WifiSecurityType.Open, WifiSecurityType.Owe)
  }

  function openPasswordPrompt(ssid) {
    if (passwordSsid !== ssid) {
      passwordText = ""
      identityText = ""
    }
    passwordSsid = ssid
  }

  function networkForSsid(ssid) {
    var networks = wifiNetworkObjects || []
    for (var i = 0; i < networks.length; i++) {
      if (networks[i] && networks[i].name === ssid) return networks[i]
    }
    return null
  }

  function wifiIndexForSsid(ssid) {
    for (var i = 0; i < wifiNetworks.length; i++) {
      if (wifiNetworks[i] && wifiNetworks[i].ssid === ssid) return i
    }
    return -1
  }

  function runNetworkAction(kind, network, callback) {
    if (actionKind !== "" || !network) return
    var ssid = network.name || ""
    actionSsid = ssid
    actionKind = kind
    failureSsid = ""
    failureReason = ""
    callback(network)
    // Safety net: if onExited never fires (process death, signal handler
    // throws, etc.), clear the busy state so the row doesn't get stuck on
    // "Connecting…" / "Disconnecting…" forever.
    actionTimeout.restart()
  }

  function clearNetworkAction() {
    actionTimeout.stop()
    if (actionKind === "connect") passwordSsid = ""
    failureSsid = ""
    failureReason = ""
    actionSsid = ""
    actionKind = ""
    refresh()
  }

  function failNetworkAction(network, reason) {
    if (!network || actionKind === "" || actionSsid !== (network.name || "")) return
    actionTimeout.stop()
    failureSsid = actionSsid
    failureReason = networkFailureReason(reason, requiresCredentials(network.security))
    actionSsid = ""
    actionKind = ""
    refresh()
  }

  function networkFailureReason(reason, needsCredentials) {
    return Model.networkFailureReason(reason, needsCredentials, connectionFailReasons, Commons.I18n.t)
  }

  function shouldRepromptPassphrase(reason, needsCredentials) {
    return Model.shouldRepromptPassphrase(reason, needsCredentials, connectionFailReasons)
  }

  function checkActionCompletion(network) {
    if (!network || actionKind === "" || actionSsid !== (network.name || "")) return
    if (actionKind === "connect" && network.connected) clearNetworkAction()
    else if (actionKind === "disconnect" && !network.connected && !network.stateChanging) clearNetworkAction()
    else if (actionKind === "forget" && !network.known && !network.stateChanging) clearNetworkAction()
  }

  function connectDirectly(ssid) {
    runNetworkAction("connect", networkForSsid(ssid), function(network) { network.connect() })
  }

  function connectWithPassphrase(ssid, passphrase) {
    runNetworkAction("connect", networkForSsid(ssid), function(network) { network.connectWithPsk(passphrase) })
  }

  function connectEnterprise(ssid, identity, passphrase) {
    runNetworkAction("connect", networkForSsid(ssid), function(network) {
      enterpriseConnect.secret = passphrase
      enterpriseConnect.command = ["bash", "-c", Model.enterpriseConnectScript, "nmcli-eap", ssid, identity]
      enterpriseConnect.running = true
    })
  }

  // Creates and activates the 802.1X profile (see Model.enterpriseConnectScript).
  // The password goes over stdin, never argv.
  Process {
    id: enterpriseConnect
    property string secret: ""
    stdinEnabled: true
    onStarted: {
      write(secret + "\n")
      secret = ""
    }
  }

  function disconnect(network) {
    runNetworkAction("disconnect", network || connectedWifiNetwork, function(net) { net.disconnect() })
  }

  // Disconnect from a row's SSID. Rows are primitive snapshots that can outlive
  // their WifiNetwork, and disconnect()'s null fallback targets whatever is
  // connected now, so a stale row must do nothing rather than hit an unrelated
  // network. Callers that mean "drop the current connection" call disconnect().
  function disconnectRow(ssid) {
    var network = networkForSsid(ssid)
    if (network) disconnect(network)
  }

  function forget(net) {
    runNetworkAction("forget", net ? networkForSsid(net.ssid) : null, function(network) { network.forget() })
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Component.onCompleted: refresh()

  // Pulls everything we want about the active route's interface in one shot.
  Process {
    id: detailsProc
    command: ["omarchy-network-status", "--verbose"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updateDetails(text)
    }
  }

  // Reads the in-use access point's strength without triggering a scan, for
  // the connected network that has none of its own (see signalStrength).
  Process {
    id: activeApSignalProc
    command: ["nmcli", "-t", "-f", "IN-USE,SIGNAL", "device", "wifi", "list", "ifname", root.wifiDevice ? root.wifiDevice.name : "", "--rescan", "no"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.finishActiveApSignal(text)
    }
  }

  Timer {
    id: activeApSignalPoll
    interval: 5000
    repeat: true
    triggeredOnStart: true
    running: root.needsActiveApSignal
    onTriggered: root.pollActiveApSignal()
  }

  Timer {
    id: scanRestart
    interval: 100
    repeat: false
    onTriggered: {
      if (root.opened && root.wifiDevice) {
        root.setScannerEnabled(true)
        scanDone.start()
      }
    }
  }

  Timer {
    id: scanDone
    interval: 1500
    repeat: false
    onTriggered: root.syncWifiNetworks()
  }

  Process {
    id: dnsProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updateDns(text)
    }
  }

  Process {
    id: bandProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updateBand(text)
    }
  }

  // Slower than detailsPoll on purpose: this shells out to nmcli several times,
  // and band availability only moves when a scan turns up a new BSSID.
  Timer {
    id: bandPoll
    interval: 4000
    repeat: true
    running: root.opened
    onTriggered: {
      if (bandProc.running) return
      bandProc.command = ["omarchy-network-band"]
      bandProc.running = true
    }
  }

  // Action runner for DNS provider changes. Wi-Fi actions use the
  // Quickshell.Networking NetworkManager backend directly.
  Process {
    id: actionProc
    stdout: StdioCollector { id: actionStdout; waitForEnd: true }
    stderr: StdioCollector { id: actionStderr; waitForEnd: true }
    onExited: function(exitCode) {
      if (root.pendingDnsProvider !== "") {
        if (exitCode === 0) root.dnsProvider = root.pendingDnsProvider
        root.pendingDnsProvider = ""
      }
      if (root.pendingBand !== "") {
        // A refused or reverted pin leaves bandSelected alone, so the pills
        // keep showing what is actually in force rather than what was asked.
        if (exitCode === 0) root.bandSelected = root.pendingBand
        root.pendingBand = ""
        // The panel stayed open through the reconnect, so pull fresh state now
        // instead of leaving stale readings until the next poll tick.
        root.refresh()
      }
    }
  }

  // Poll details while the panel is open so the IP/route header catches up
  // as soon as NetworkManager finishes activating a connection.
  Timer {
    id: detailsPoll
    interval: 1500
    repeat: true
    running: root.opened
    onTriggered: if (!detailsProc.running) detailsProc.running = true
  }

  Timer {
    id: connectionPhraseTimer
    interval: 2800
    running: root.opened && !root.restricted && (root.info.type === "ethernet" || (root.info.type === "wifi" && root.canDisconnect))
    repeat: true
    onTriggered: connectionPhraseSwap.restart()
  }

  SequentialAnimation {
    id: connectionPhraseSwap
    PropertyAnimation {
      target: panel.loadedContent ? panel.loadedContent.heroMeta : null; property: "opacity"
      to: 0.0; duration: Style.duration(150); easing.type: Easing.OutCubic
    }
    ScriptAction {
      script: root.connectionPhraseIndex = (root.connectionPhraseIndex + 1) % root.connectionPhrases.length
    }
    PropertyAnimation {
      target: panel.loadedContent ? panel.loadedContent.heroMeta : null; property: "opacity"
      to: 1.0; duration: Style.duration(200); easing.type: Easing.OutCubic
    }
  }

  Connections {
    target: root
    function onInfoChanged() {
      if (!(root.info.type === "ethernet" || (root.info.type === "wifi" && root.canDisconnect))) {
        connectionPhraseSwap.stop()
        if (panel.loadedContent) panel.loadedContent.heroMeta.opacity = 1.0
      }
    }
  }

  Timer {
    id: actionTimeout
    // Must outlast NetworkManager's 25s supplicant timeout: a wrong saved
    // PSK fails with WifiAuthTimeout at ~25s, and that failure has to land
    // while the action is still tracked to show "Wrong password" and reopen
    // the passphrase prompt.
    interval: 30000
    repeat: false
    onTriggered: {
      if (!root.actionKind) return
      var reason
      if (root.actionKind === "connect") reason = Commons.I18n.t("network.timedOutConnecting")
      else if (root.actionKind === "disconnect") reason = Commons.I18n.t("network.timedOutDisconnecting")
      else reason = Commons.I18n.t("network.timedOutForgetting")
      root.failureSsid = root.actionSsid
      root.failureReason = reason
      root.actionSsid = ""
      root.actionKind = ""
      root.refresh()
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.icon
    active: root.restricted
    tooltipText: root.hasCaptivePortal ? Commons.I18n.t("network.signInToNetwork")
      : (root.restricted ? Commons.I18n.t("network.limitedAccess") : "")

    onPressed: function(b) {
      if (root.opened) root.close()
      // open() is enough: onOpenedChanged runs refresh(true), which defers the
      // PHY scan past the first frame. The bare refresh() that used to follow
      // took the no-scan branch and set scannerEnabled synchronously, undoing
      // that deferral and stalling the open on NetworkManager's AP flood.
      else root.open()
    }
  }

  // =========================================================================
  // XP UI (ocko.xp-network). Everything above is stock (see the header) apart
  // from the lines marked "XP:". Everything below replaces stock's card.
  //
  // Geometry is netshell.dll's own dialog templates (XP SP2), converted from
  // dialog units at Tahoma 8 / 96 dpi (1 DLU = 1.5 px across, 13/8 px down):
  //   1801  Status > General (with Signal Strength), 210 x 154
  //   1806  Status > Support
  //   1807  Network Connection Details, 227 x 198
  //   16004 Properties > General, 227 x 207
  // The Advanced tab has no XP original: it holds stock's DNS provider,
  // band and speed-test controls in XP dialog form.
  // =========================================================================

  property int sheetTab: 0
  property bool detailsOpen: false
  property bool propsOpen: false
  property bool wirelessOpen: false
  // Repair: stock's refresh, with the rotating phrase in the Status row for
  // as long as XP's repair took to say anything.
  property bool repairing: false
  // Duration: since this shell first saw the link up. Networking is live
  // whether or not the panel is open, so a drop while closed still resets it.
  property real linkUpSince: 0
  property real nowMs: Date.now()

  readonly property bool xpWifiOn: networkManagerAvailable && Networking.wifiEnabled
  readonly property bool phraseMode: repairing || busy

  function s(n) { return Style.space(n) }
  function du(x) { return Style.space(Math.round(x * 1.5)) }
  function dv(y) { return Style.space(Math.round(y * 13 / 8)) }

  function xpBareCard(item) {
    var card = item && item.parent ? item.parent.parent : null
    if (card && "radius" in card) {
      card.color = "transparent"
      card.radius = 0
    }
  }

  function trackLink() {
    if (kind === "disconnected") linkUpSince = 0
    else if (linkUpSince === 0) linkUpSince = Date.now()
  }
  // XP: 4.5.0 stock owns root onKindChanged (resetActiveApSignal); a second
  // handler on root would not load, so trackLink runs from the Connections below.
  QtObject { Component.onCompleted: root.trackLink() }

  // Stock owns onOpenedChanged, onKindChanged and onPasswordSsidChanged; a
  // second handler on root would not load.
  Connections {
    target: root
    function onOpenedChanged() { if (!root.opened) root.xpCloseOverlays() }
    function onKindChanged() { root.trackLink() }
    // XP: 4.5.0 stock hands focus back through panel.loadedContent, which is
    // null for our eager card, so give it back to keyCatcher ourselves.
    function onPasswordSsidChanged() {
      if (root.passwordSsid === "" && root.opened) Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    }
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.opened
    triggeredOnStart: true
    onTriggered: root.nowMs = Date.now()
  }

  Timer {
    id: repairTimer
    interval: 3000
    onTriggered: root.repairing = false
  }

  function xpRepair() {
    repairing = true
    refresh(true)
    repairTimer.restart()
  }

  function xpCloseOverlays() {
    detailsOpen = false
    propsOpen = false
    wirelessOpen = false
  }

  function xpOpenAdvanced() {
    wirelessOpen = false
    sheetTab = 2
  }

  function xpDuration() {
    if (linkUpSince <= 0 || kind === "disconnected") return "00:00:00"
    var t = Math.max(0, Math.floor((nowMs - linkUpSince) / 1000))
    var d = Math.floor(t / 86400)
    t -= d * 86400
    function two(n) { return n < 10 ? "0" + n : String(n) }
    var hms = two(Math.floor(t / 3600)) + ":" + two(Math.floor(t / 60) % 60) + ":" + two(t % 60)
    return d > 0 ? d + (d === 1 ? " day " : " days ") + hms : hms
  }

  // XP: "100.0 Mbps", "1.0 Gbps".
  function xpSpeed() {
    var mbps = parseFloat(info.speed || info.bitrate || "0")
    if (!(mbps > 0)) return kind === "disconnected" ? "0 bps" : "--"
    return mbps >= 1000 ? (mbps / 1000).toFixed(1) + " Gbps" : mbps.toFixed(1) + " Mbps"
  }

  function xpCommas(n) {
    return String(Math.round(n || 0)).replace(/\B(?=(\d{3})+(?!\d))/g, ",")
  }

  function xpMask(prefix) {
    var p = parseInt(prefix, 10)
    if (isNaN(p) || p < 0 || p > 32) return ""
    var parts = []
    for (var i = 0; i < 4; i++) {
      var bits = Math.max(0, Math.min(8, p - i * 8))
      parts.push(256 - Math.pow(2, 8 - bits))
    }
    return parts.join(".")
  }

  function xpIsEnterprise(sec) {
    return sec === WifiSecurityType.Wpa2Eap || sec === WifiSecurityType.WpaEap || sec === WifiSecurityType.Wpa3SuiteB192
  }

  function xpSecurityLabel(sec) {
    if (sec === WifiSecurityType.Open) return "Unsecured wireless network"
    var k = ""
    if (sec === WifiSecurityType.Owe) k = "OWE"
    else if (sec === WifiSecurityType.WpaPsk) k = "WPA"
    else if (sec === WifiSecurityType.Wpa2Psk) k = "WPA2"
    else if (sec === WifiSecurityType.Sae) k = "WPA3"
    else if (sec === WifiSecurityType.WpaEap) k = "WPA, 802.1X"
    else if (sec === WifiSecurityType.Wpa2Eap) k = "WPA2, 802.1X"
    else if (sec === WifiSecurityType.Wpa3SuiteB192) k = "WPA3, 802.1X"
    else if (sec === WifiSecurityType.StaticWep || sec === WifiSecurityType.DynamicWep) k = "WEP"
    else if (sec === WifiSecurityType.Leap) k = "LEAP"
    return "Security-enabled wireless network" + (k ? " (" + k + ")" : "")
  }

  // The Activity icon: netshell 122 both lit, 124 sending, 125 receiving,
  // 126 idle, as XP flashed it with traffic.
  readonly property string xpActivityIcon: {
    var tx = uploadRate > 512, rx = downloadRate > 512
    var id = tx && rx ? 122 : tx ? 124 : rx ? 125 : 126
    return XpScheme.graphics + "/netshell/32/" + id + ".png"
  }

  readonly property var xpDetailsRows: {
    var r = []
    function add(k, v) { if (v !== undefined && v !== null && v !== "") r.push([k, String(v)]) }
    add("Interface", info.iface)
    add("Connection type", info.type === "wifi" ? "Wireless" : info.type === "ethernet" ? "Ethernet" : "")
    if (info.type === "wifi") {
      add("SSID", info.ssid)
      add("Signal strength", signalStrength >= 0 ? signalStrength + " %" : "")
      add("Frequency", info.freq ? formatHeaderFreq(parseFloat(info.freq)) : "")
      add("Band", bandCurrent)
    }
    add("Link speed", xpSpeed() + (info.duplex ? ", " + info.duplex + " duplex" : ""))
    add("IP Address", info.ip)
    add("Subnet Mask", xpMask(info.prefix))
    add("Default Gateway", info.gateway)
    add("DNS Server", dnsProvider)
    add("Ping", formatPingLatency(internetPingLatency))
    add("Packet Loss", formatPacketLoss(internetPingPacketLoss))
    add("Receiving", hasTransferStats ? formatRate(downloadRate) : "--")
    add("Sending", hasTransferStats ? formatRate(uploadRate) : "--")
    add("Downloaded", hasTransferStats ? formatBytes(parseFloat(info.rx_bytes || "0")) : "--")
    add("Uploaded", hasTransferStats ? formatBytes(parseFloat(info.tx_bytes || "0")) : "--")
    return r
  }

  // ---- inline components (declared before use) ----------------------------

  // A value XP showed as plain text; here a click copies it (stock's
  // click-to-copy), with the tip saying so.
  component CopyValue: XpLabel {
    id: cv
    textFormat: Text.PlainText
    MouseArea {
      id: cvMouse
      anchors.fill: parent
      hoverEnabled: true
      enabled: cv.text !== "" && cv.text !== "--"
      cursorShape: Qt.PointingHandCursor
      onClicked: root.copyToClipboard(cv.text)
    }
    XpToolTip {
      visible: cvMouse.containsMouse
      y: cv.height + root.s(4)
      z: 20
      text: "Click to copy"
    }
  }

  // Five rising bars for Signal Strength, lit in 20 % steps.
  component SignalBars: Row {
    id: sbars
    property int strength: 0
    spacing: 1
    Repeater {
      model: 5
      Rectangle {
        required property int index
        anchors.bottom: parent.bottom
        width: root.s(3)
        height: root.s(4 + index * 3)
        color: sbars.strength > index * 20 ? "#2CC12C" : "#FFFFFF"
        border.width: 1
        border.color: sbars.strength > index * 20 ? "#1C8A1C" : "#ACA899"
      }
    }
  }

  // ---- the panel ------------------------------------------------------------
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    padding: 0
    borderSpec: Border.none()
    contentWidth: statusWin.width
    contentHeight: statusWin.height

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      // The network-key fields take every key while focused.
      blocked: wireless.typing
      Component.onCompleted: root.xpBareCard(keyCatcher)

      onMoveRequested: function(dx, dy) {
        if (root.wirelessOpen) {
          if (dy !== 0) root.selectByDelta(dy)
          return
        }
        if (root.detailsOpen || root.propsOpen) return
        if (dx !== 0) root.sheetTab = (root.sheetTab + dx + 3) % 3
      }
      onActivateRequested: if (root.wirelessOpen) root.activateSelected()
      onDeleteRequested: {
        if (!root.wirelessOpen || root.busy) return
        var net = root.wifiNetworks[root.selectedIndex]
        if (net && root.canForgetNetwork(net)) root.forget(net)
      }
      onCloseRequested: {
        if (root.passwordSsid !== "") root.cancelPasswordPrompt()
        else if (root.detailsOpen) root.detailsOpen = false
        else if (root.propsOpen) root.propsOpen = false
        else if (root.wirelessOpen) root.wirelessOpen = false
        else root.close()
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "r" || t === "R") root.xpRepair()
        else if (t === "w" || t === "W") root.toggleNetwork()
      }

      // ---- Local Area Connection Status (templates 1801, 1806) -----------
      XpPropertySheet {
        id: statusWin
        title: root.info.type === "wifi" ? "Wireless Network Connection Status" : "Local Area Connection Status"
        titleIcon: XpScheme.graphics + "/netshell/16/" + (root.kind === "disconnected" ? "195" : "193") + ".png"
        buttons: ["close"]
        active: !root.detailsOpen && !root.propsOpen && !root.wirelessOpen
        onCloseClicked: root.close()
        titles: ["General", "Support", "Advanced"]
        tab: root.sheetTab
        onTabClicked: function(i) { root.sheetTab = i }
        pageWidth: root.du(210)
        pageHeight: root.dv(154)
        buttonLabels: ["<u>C</u>lose"]
        onButtonClicked: root.close()

        // -- General (1801) --
        Item {
          parent: statusWin.page
          anchors.fill: parent
          visible: root.sheetTab === 0

          XpGroupBox { x: root.du(7); y: root.dv(7); width: root.du(196); height: root.dv(65); caption: "Connection" }
          XpLabel { x: root.du(17); y: root.dv(19); text: "Status:" }
          XpLabel {
            x: root.du(73); y: root.dv(19)
            visible: !root.phraseMode
            text: root.kind === "disconnected" ? "Disconnected" : "Connected"
          }
          // Stock's rotating phrase (its swap animation drives this id).
          XpLabel {
            id: heroMeta
            x: root.du(73); y: root.dv(19)
            visible: root.phraseMode
            textFormat: Text.PlainText
            text: root.connectionPhrase + "..."
          }
          XpLabel { x: root.du(17); y: root.dv(31); text: "Duration:" }
          XpLabel {
            x: root.du(73); y: root.dv(31)
            text: root.xpDuration()
            MouseArea { id: durMouse; anchors.fill: parent; hoverEnabled: true }
            XpToolTip {
              visible: durMouse.containsMouse
              y: parent.height + root.s(4)
              z: 20
              text: "Time since this shell first saw the link up. It restarts at 00:00:00 when the shell restarts."
            }
          }
          XpLabel { x: root.du(17); y: root.dv(43); text: "Speed:" }
          XpLabel { x: root.du(73); y: root.dv(43); text: root.xpSpeed() }
          XpLabel { visible: root.info.type === "wifi"; x: root.du(17); y: root.dv(55); text: "Signal Strength:" }
          SignalBars {
            visible: root.info.type === "wifi"
            x: root.du(73)
            y: root.dv(55) + root.dv(8) - height
            strength: Math.max(0, root.signalStrength)
          }

          XpGroupBox { x: root.du(7); y: root.dv(78); width: root.du(196); height: root.dv(51); caption: "Activity" }
          XpLabel { x: root.du(54); y: root.dv(90); width: root.du(41); horizontalAlignment: Text.AlignRight; text: "Sent" }
          Rectangle { x: root.du(99); y: root.dv(94); width: root.du(13); height: 1; color: "#000000" }
          Image {
            x: root.du(116) + (root.du(20) - width) / 2
            y: root.dv(85) + (root.dv(20) - height) / 2
            width: root.s(32)
            height: root.s(32)
            source: root.xpActivityIcon
          }
          Rectangle { x: root.du(139); y: root.dv(94); width: root.du(13); height: 1; color: "#000000" }
          XpLabel { x: root.du(157); y: root.dv(90); text: "Received" }
          XpLabel { x: root.du(17); y: root.dv(108); text: "Bytes:" }
          XpLabel {
            x: root.du(52); y: root.dv(108); width: root.du(63)
            horizontalAlignment: Text.AlignRight
            text: root.hasTransferStats ? root.xpCommas(parseFloat(root.info.tx_bytes || "0")) : "--"
          }
          Rectangle { x: root.du(126); y: root.dv(106); width: 1; height: root.dv(12); color: "#ACA899" }
          XpLabel {
            x: root.du(132); y: root.dv(108); width: root.du(61)
            text: root.hasTransferStats ? root.xpCommas(parseFloat(root.info.rx_bytes || "0")) : "--"
          }

          XpButton {
            x: root.du(7); y: root.dv(136); width: root.du(50); height: root.dv(14)
            text: "P<u>r</u>operties"
            onClicked: root.propsOpen = true
          }
          // Read-only, as answer 8 asks: shown, never enabled.
          XpButton {
            x: root.du(60); y: root.dv(136); width: root.du(55); height: root.dv(14)
            text: "<u>D</u>isable"
            enabled: false
          }
          XpButton {
            visible: root.wifiStationAvailable
            x: root.du(203) - width; y: root.dv(136); width: root.du(84); height: root.dv(14)
            text: "<u>V</u>iew Wireless Networks"
            onClicked: { root.wirelessOpen = true; root.refresh(true) }
          }
        }

        // -- Support (1806). Address Type is not derivable from what stock
        // reads, so that row is left out and the rest move up a row. --
        Item {
          parent: statusWin.page
          anchors.fill: parent
          visible: root.sheetTab === 1

          XpGroupBox { x: root.du(7); y: root.dv(7); width: root.du(196); height: root.dv(79); caption: "Internet Protocol (TCP/IP)" }
          XpLabel { x: root.du(14); y: root.dv(21); text: "IP Address:" }
          CopyValue { x: root.du(75); y: root.dv(21); text: root.info.ip || "0.0.0.0" }
          XpLabel { x: root.du(14); y: root.dv(36); text: "Subnet Mask:" }
          CopyValue { x: root.du(75); y: root.dv(36); text: root.xpMask(root.info.prefix) || "0.0.0.0" }
          XpLabel { x: root.du(14); y: root.dv(51); text: "Default Gateway:" }
          CopyValue { x: root.du(75); y: root.dv(51); text: root.info.gateway || "" }
          XpButton {
            x: root.du(141); y: root.dv(66); width: root.du(55); height: root.dv(14)
            text: "<u>D</u>etails..."
            onClicked: root.detailsOpen = true
          }
          XpLabel {
            x: root.du(7); y: root.dv(93); width: root.du(196)
            wrapMode: Text.WordWrap
            text: "Windows did not detect problems with this connection. If you cannot connect, click Repair."
          }
          XpButton {
            x: root.du(7); y: root.dv(111); width: root.du(55); height: root.dv(14)
            text: "Re<u>p</u>air"
            enabled: !root.repairing
            onClicked: root.xpRepair()
          }
        }

        // -- Advanced: stock's DNS provider, band and speed test --
        Item {
          id: advancedPage
          parent: statusWin.page
          anchors.fill: parent
          visible: root.sheetTab === 2
          readonly property string dnsNow: root.dnsEffective  // XP: 4.5.0 pending-or-current DNS

          XpGroupBox { x: root.du(7); y: root.dv(7); width: root.du(196); height: root.dv(64); caption: "DNS server" }
          Column {
            x: root.du(13); y: root.dv(19)
            spacing: root.dv(3)
            Repeater {
              model: [
                { p: "DHCP", t: "Obtain DNS server address <u>a</u>utomatically" },
                { p: "Cloudflare", t: "Use <u>C</u>loudflare DNS (1.1.1.1)" },
                { p: "Google", t: "Use <u>G</u>oogle Public DNS (8.8.8.8)" },
                { p: "Custom", t: "Use the following DNS server addresses..." }
              ]
              XpRadio {
                required property var modelData
                text: modelData.t
                checked: advancedPage.dnsNow === modelData.p
                enabled: root.pendingDnsProvider === ""
                onClicked: root.setDns(modelData.p)
              }
            }
          }

          XpGroupBox {
            visible: root.canSelectBand
            x: root.du(7); y: root.dv(77); width: root.du(196); height: root.dv(52)
            caption: "Wireless band"
          }
          Flow {
            visible: root.canSelectBand
            x: root.du(13); y: root.dv(89); width: root.du(184)
            spacing: root.du(8)
            Repeater {
              model: root.canSelectBand ? ["auto"].concat(root.bandAvailable) : []
              XpRadio {
                required property var modelData
                text: modelData === "auto" ? "Automatic" : root.bandLabel(modelData)
                checked: root.bandEffective === modelData
                enabled: !root.bandBusy
                onClicked: {
                  if (modelData !== "auto") root.setBand(modelData)
                  else if (root.bandPinned) root.toggleBandAuto()
                }
              }
            }
          }

          XpButton {
            x: root.du(7); y: root.dv(136); width: root.du(60); height: root.dv(14)
            text: "<u>S</u>peed Test..."
            enabled: root.canRunSpeedTest
            onClicked: root.summonSpeedTest()
          }
          XpButton {
            visible: root.canShareWifi
            x: root.du(72); y: root.dv(136); width: root.du(66); height: root.dv(14)
            text: "Show <u>Q</u>R Code..."
            onClicked: root.summonWifiQr()
          }
        }
      }

      // ---- overlays: modal over the status window, kept on screen --------
      MouseArea {
        anchors.fill: parent
        visible: root.detailsOpen || root.propsOpen
        z: 30
      }

      // Network Connection Details (1807): stock's stats, click to copy.
      XpWindow {
        id: detailsWin
        visible: root.detailsOpen
        z: 31
        width: root.du(227) + root.s(6)
        height: root.dv(198) + root.s(29 + 3)
        x: Math.max(-panel.cardOrigin.x, Math.min((parent.width - width) / 2, panel.screenW - panel.cardOrigin.x - width))
        y: parent.height - height
        title: "Network Connection Details"
        buttons: ["close"]
        onCloseClicked: root.detailsOpen = false

        XpLabel { x: root.du(7); y: root.dv(7); text: "Network Connection <u>D</u>etails:" }
        XpListView {
          id: detailsList
          x: root.du(7); y: root.dv(17); width: root.du(213); height: root.dv(133)
          columns: [{ title: "Property", width: root.s(120) }, { title: "Value", width: root.s(200) }]
          rows: root.detailsOpen ? root.xpDetailsRows : []
          onClicked: function(i) {
            detailsList.currentIndex = i
            root.copyToClipboard(root.xpDetailsRows[i][1])
          }
        }
        XpLabel { x: root.du(7); y: root.dv(155); enabled: false; text: "Click a row to copy its value." }
        XpEtched { x: root.du(7); y: root.dv(172); width: root.du(213) }
        XpButton {
          x: root.du(170); y: root.dv(177); width: root.du(50); height: root.dv(14)
          text: "<u>C</u>lose"
          isDefault: true
          onClicked: root.detailsOpen = false
        }
      }

      // Local Area Connection Properties > General (16004), read-only.
      XpPropertySheet {
        id: propsWin
        visible: root.propsOpen
        z: 31
        x: Math.max(-panel.cardOrigin.x, Math.min((parent.width - width) / 2, panel.screenW - panel.cardOrigin.x - width))
        y: parent.height - height
        title: (root.info.type === "wifi" ? "Wireless Network Connection" : "Local Area Connection") + " Properties"
        buttons: ["help", "close"]
        disabledButtons: ["help"]
        onCloseClicked: root.propsOpen = false
        titles: ["General"]
        pageWidth: root.du(227)
        pageHeight: root.dv(207)
        buttonLabels: ["OK", "Cancel"]
        onButtonClicked: root.propsOpen = false

        Item {
          parent: propsWin.page
          anchors.fill: parent
          XpLabel { x: root.du(7); y: root.dv(7); text: "Connect using:" }
          Rectangle {
            x: root.du(7); y: root.dv(18); width: root.du(213); height: root.dv(18)
            color: "#EBEBE4"
            border.width: 1
            border.color: XpScheme.sc.edit
            Image {
              x: root.s(6)
              anchors.verticalCenter: parent.verticalCenter
              width: root.s(16)
              height: root.s(16)
              source: XpScheme.graphics + "/netshell/16/1901.png"
            }
            XpLabel {
              x: root.s(28)
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: (root.info.iface || "No adapter") + (root.info.type ? " (" + (root.info.type === "wifi" ? "Wireless" : "Ethernet") + ")" : "")
            }
          }
          XpButton {
            x: root.du(160); y: root.dv(39); width: root.du(60); height: root.dv(14)
            text: "<u>C</u>onfigure..."
            enabled: false
          }
          XpLabel { x: root.du(7); y: root.dv(54); text: "This c<u>o</u>nnection uses the following items:" }
          Rectangle {
            x: root.du(7); y: root.dv(66); width: root.du(213); height: root.dv(52)
            color: "#FFFFFF"
            border.width: 1
            border.color: XpScheme.sc.edit
            Row {
              x: root.s(4); y: root.s(4)
              spacing: root.s(4)
              XpCheckBox { checked: true; enabled: false; anchors.verticalCenter: parent.verticalCenter }
              Image { width: root.s(16); height: root.s(16); source: XpScheme.graphics + "/netshell/16/1902.png" }
              XpLabel { text: "Internet Protocol (TCP/IP)"; anchors.verticalCenter: parent.verticalCenter }
            }
          }
          XpButton { x: root.du(7); y: root.dv(122); width: root.du(67); height: root.dv(14); text: "I<u>n</u>stall..."; enabled: false }
          XpButton { x: root.du(80); y: root.dv(122); width: root.du(67); height: root.dv(14); text: "<u>U</u>ninstall"; enabled: false }
          XpButton { x: root.du(153); y: root.dv(122); width: root.du(67); height: root.dv(14); text: "P<u>r</u>operties"; enabled: false }
          XpGroupBox { x: root.du(7); y: root.dv(139); width: root.du(213); height: root.dv(42); caption: "Description" }
          XpLabel {
            x: root.du(16); y: root.dv(150); width: root.du(196)
            wrapMode: Text.WordWrap
            text: "Transmission Control Protocol/Internet Protocol. The default wide area network protocol that provides communication across diverse interconnected networks."
          }
          XpCheckBox {
            x: root.du(7); y: root.dv(186)
            text: "Sho<u>w</u> icon in notification area when connected"
            checked: true
            enabled: false
          }
        }
      }

      // ---- Wireless Network Connection (answer 9), left of the status ----
      XpWireless {
        id: wireless
        host: root
        visible: root.wirelessOpen
        z: 25
        width: Math.min(root.s(620), panel.screenW - root.s(16))
        height: root.s(440)
        x: Math.max(-panel.cardOrigin.x + root.s(8), -width - root.s(8))
        y: parent.height - height
        onCloseRequested: root.wirelessOpen = false
      }
    }
  }
}
