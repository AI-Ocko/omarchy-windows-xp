import QtQuick
import qs.Commons

// XpTabs: [Tab.*] of the active scheme, a property-sheet tab control. Tabs
// are [Tab.TabItem] / [Tab.TabItemLeftEdge] (SizingMargins 6), the selected
// one [Tab.TopTabItem*], drawn 2 px taller so it covers the pane's top edge;
// 5 frames: normal, hot, selected, disabled, focused. The page is
// [Tab.Pane] (TabPaneEdge, SizingMargins 2, 4, 2, 4). Children go in the
// page; show one per tab by binding `visible: tabs.currentIndex === n`.
// Tabs that do not fit wrap onto more rows, as a multi-line Windows tab
// control does; the pane starts below the last row.
Item {
  id: tabs

  property string artDir: XpScheme.artDir
  property var titles: []
  property int currentIndex: 0
  property bool focused: false
  default property alias content: page.data
  readonly property alias page: page
  signal activated(int index)

  readonly property real tabHeight: Style.space(21)

  implicitWidth: Style.space(360)
  implicitHeight: Style.space(300)

  XpArt {
    id: pane
    anchors.fill: parent
    anchors.topMargin: Math.max(tabs.tabHeight, strip.height)
    source: tabs.artDir + "/tab-pane.png"
    margins: [2, 4, 2, 4]

    Item {
      id: page
      anchors.fill: parent
      anchors.margins: Style.space(2)
    }
  }

  Flow {
    id: strip
    x: Style.space(2)
    width: tabs.width - Style.space(4)
    Repeater {
      model: tabs.titles
      Item {
        id: tab
        required property int index
        required property var modelData
        readonly property bool selected: index === tabs.currentIndex
        width: label.implicitWidth + Style.space(12)
        // Flow places the slot; the art inside keeps the selected tab 1 px
        // taller and the others 2 px lower, over the row below or the pane.
        height: tabs.tabHeight
        z: selected ? 1 : 0

        XpArt {
          id: tabArt
          x: 0
          y: tab.selected ? 0 : Style.space(2)
          width: parent.width
          height: tabs.tabHeight + (tab.selected ? Style.space(1) : 0)
          readonly property int frame: tab.selected ? (tabs.focused ? 4 : 2)
                                       : (!tabs.enabled ? 3 : tabMouse.containsMouse ? 1 : 0)
          source: tabs.artDir + "/tab" + (tab.selected ? "-top" : "") + (tab.index === 0 ? (tab.selected ? "left" : "-left") : "")
                  + "-" + frame + ".png"
          margins: [6, 6, 6, 6]
        }

        Text {
          id: label
          anchors.centerIn: tabArt
          anchors.verticalCenterOffset: tab.selected ? -Style.space(1) : 0
          text: String(tab.modelData)
          color: tabs.enabled ? "#000000" : "#A1A192"
          font.family: "Tahoma"
          font.pixelSize: Style.font.bodySmall
        }

        MouseArea {
          id: tabMouse
          anchors.fill: parent
          hoverEnabled: true
          enabled: tabs.enabled
          onClicked: tabs.activated(tab.index)
        }
      }
    }
  }
}
