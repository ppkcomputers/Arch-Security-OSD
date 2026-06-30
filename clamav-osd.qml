import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root
    property bool isScanning: false
    property bool scanFinished: false
    property bool ghostFound: false
    property string statusMessage: "SYSTEM READY"
    property string threatPath: ""

    // Deletion animation state properties
    property bool isDeleting: false
    property int deletionStep: 0 // 0: blinky, 1: ghost2, 2: ghost3, 3: ghost4, 4: gone/blank

    Process {
        id: clamScanProc
        command: ["sh", "-c", "clamscan -r ~/Downloads --bell -i --stdout"]

        stdout: SplitParser {
            onRead: function(line) {
                if (!line) return;
                if (line.includes("FOUND")) {
                    root.ghostFound = true;
                    root.statusMessage = "GHOST FOUND!";

                    let cleanLine = line.trim();
                    let endIdx = cleanLine.indexOf(":");
                    if (endIdx !== -1) {
                        root.threatPath = cleanLine.substring(0, endIdx);
                    } else {
                        root.threatPath = cleanLine;
                    }
                }
            }
        }

        onRunningChanged: {
            if (!running && isScanning) {
                isScanning = false;
                scanFinished = true;
                if (!root.ghostFound) {
                    statusMessage = "SCAN COMPLETE: GHOSTS PURGED!";
                }
            }
        }
    }

    // Process executor to physically delete the virus file
    Process {
        id: deleteFileProc
    }

    // Sequence timer handling the 1-second interval image swaps
    Timer {
        id: deletionSequenceTimer
        interval: 1000
        repeat: true
        running: false
        onTriggered: {
            root.deletionStep++;
            if (root.deletionStep > 4) {
                deletionSequenceTimer.stop();
                root.isDeleting = false; // Restores control and button interactivity
                root.ghostFound = false;  // Clear ghost layout to return to standard view or end state
                root.scanFinished = true;
                root.statusMessage = "GHOST VAPORIZED SAFE!";
                root.threatPath = "";
            }
        }
    }

    function startScan() {
        statusMessage = "Hunting Ghosts...";
        scanFinished = false;
        ghostFound = false;
        threatPath = "";
        isDeleting = false;
        deletionStep = 0;
        isScanning = true;
        clamScanProc.running = false;
        clamScanProc.running = true;
    }

    function executeGhostDeletion() {
        if (!root.threatPath || root.isDeleting) return;

        root.isDeleting = true;
        root.statusMessage = "Purging Threat Source...";
        root.deletionStep = 1; // Immediately transition to blue ghost2.png
        deletionSequenceTimer.start();

        // Run system shell remove against tracked threat path target
        deleteFileProc.command = ["rm", "-f", root.threatPath];
        deleteFileProc.running = false;
        deleteFileProc.running = true;
    }

    function terminateAndExit() {
        if (clamScanProc.running) {
            clamScanProc.running = false;
        }
        Qt.quit();
    }

    PanelWindow {
        id: osdWindow
        anchors { top: true; bottom: true; left: true; right: true }
        implicitWidth: 605
        implicitHeight: 495
        visible: true
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrLayershell.OnDemand

        Item {
            anchors.fill: parent
            focus: true
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Space && scanFinished && !isScanning && !root.isDeleting) {
                    root.startScan();
                    event.accepted = true;
                }
            }
        }

        Rectangle {
            width: 572
            height: 440
            anchors.centerIn: parent
            color: "#121317"
            opacity: 0.95
            border.color: "#555839"
            border.width: 1
            radius: 16

            Column {
                anchors.fill: parent
                anchors.margins: 22
                spacing: 18

                // Header Block
                Rectangle {
                    width: parent.width
                    height: 55
                    color: Qt.rgba(0.22, 0.24, 0.21, 0.85)
                    radius: 10
                    border.color: "#b0ac63"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "Clamav Pacman Scanner"
                        color: "#dde5a2"
                        font.pixelSize: 18
                        font.family: "Monospace"
                        font.weight: Font.Bold
                    }
                }

                // Status Indicator Block
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12

                    Text {
                        text: "🦪"
                        font.pixelSize: 28
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "STATUS: " + statusMessage
                        font.pixelSize: 15
                        font.family: "Monospace"
                        font.bold: true
                        color: root.isDeleting ? "#77ccff" : (ghostFound ? "#ff8888" : (isScanning ? "#c0d0a0" : (scanFinished ? "#ffcc77" : "#555839")))
                    }
                }

                // Arcade Monitor Viewport Container
                Rectangle {
                    width: parent.width
                    height: 176
                    color: "#000000"
                    radius: 8
                    border.color: root.isDeleting ? "#33aaff" : (ghostFound ? "#ff3333" : (isScanning ? "#b0ac63" : (scanFinished ? "#774444" : "#222222")))
                    border.width: 1
                    clip: true

                    // Side-by-Side threat info layout
                    Row {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 15
                        visible: ghostFound || root.isDeleting

                        Image {
                            id: threatImage
                            width: (parent.width * 0.35)
                            height: parent.height
                            fillMode: Image.PreserveAspectFit
                            // Handles cascading blue fade steps and turns empty ("") on stage 4
                            source: {
                                if (root.deletionStep === 1) return "ghost2.png";
                                if (root.deletionStep === 2) return "ghost3.png";
                                if (root.deletionStep === 3) return "ghost4.png";
                                if (root.deletionStep === 4) return "";
                                return "blinky.png";
                            }
                        }

                        Column {
                            width: (parent.width * 0.65) - 15
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Text {
                                text: root.isDeleting ? "CONTAINING & PURGING:" : "PATHOGEN DETECTED:"
                                color: root.isDeleting ? "#55ccff" : "#ff5555"
                                font.pixelSize: 13
                                font.family: "Monospace"
                                font.bold: true
                            }

                            ScrollView {
                                width: parent.width
                                height: 90
                                clip: true
                                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                                Text {
                                    width: parent.width - 10
                                    text: root.threatPath
                                    color: root.isDeleting ? "#bbeeff" : "#ffaaaa"
                                    font.pixelSize: 11
                                    font.family: "Monospace"
                                    wrapMode: Text.WrapAnywhere
                                }
                            }
                        }
                    }

                    // Standard Idle Display Mode (pacman.png)
                    Image {
                        id: idleStaticImage
                        anchors.centerIn: parent
                        width: parent.width - 20
                        height: parent.height - 20
                        fillMode: Image.PreserveAspectFit
                        source: "pacman.png"
                        visible: !isScanning && !scanFinished && !ghostFound && !root.isDeleting
                    }

                    // Active Scanning Display Mode (pacman1.gif)
                    AnimatedImage {
                        id: scanningGif
                        anchors.centerIn: parent
                        width: parent.width - 20
                        height: parent.height - 20
                        fillMode: Image.PreserveAspectFit
                        source: "pacman1.gif"
                        playing: isScanning && !ghostFound
                        visible: isScanning && !ghostFound
                    }

                    // Complete Clean Finished Display Mode (pacman2.gif)
                    AnimatedImage {
                        id: finishedGif
                        anchors.centerIn: parent
                        width: parent.width - 20
                        height: parent.height - 20
                        fillMode: Image.PreserveAspectFit
                        source: "pacman2.gif"
                        playing: scanFinished && !ghostFound && !root.isDeleting
                        visible: scanFinished && !ghostFound && !root.isDeleting
                    }
                }

                // Control Center Actions Row
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 15

                    Button {
                        id: scanButton
                        width: (root.ghostFound && !root.isDeleting && root.deletionStep === 0) ? 160 : 240
                        height: 48
                        enabled: !isScanning && !root.isDeleting

                        background: Rectangle {
                            radius: 8
                            color: parent.enabled ? (parent.pressed ? "#252921" : "#363c30") : "#222520"
                            border.color: parent.enabled ? "#555839" : "#333525"
                            border.width: 1
                        }

                        contentItem: Text {
                            text: isScanning ? "Hunting..." : "Scan Home"
                            font.pixelSize: 14
                            font.family: "Monospace"
                            color: parent.enabled ? "#dde5a2" : "#666855"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            root.startScan();
                        }
                    }

                    Button {
                        id: deleteButton
                        width: 160
                        height: 48
                        visible: root.ghostFound && !root.isDeleting && root.deletionStep === 0
                        enabled: !isScanning && !root.isDeleting

                        background: Rectangle {
                            radius: 8
                            color: parent.pressed ? "#1a2a3a" : "#223545"
                            border.color: "#336699"
                            border.width: 1
                        }

                        contentItem: Text {
                            text: "Delete Ghost"
                            font.pixelSize: 14
                            font.family: "Monospace"
                            font.bold: true
                            color: "#99ccff"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            root.executeGhostDeletion();
                        }
                    }

                    Button {
                        id: closeButton
                        width: (root.ghostFound && !root.isDeleting && root.deletionStep === 0) ? 100 : 120
                        height: 48
                        // Keeps exit accessible even while deletion runs
                        enabled: true

                        background: Rectangle {
                            radius: 8
                            color: parent.pressed ? "#502020" : "#3c3030"
                            border.color: "#774444"
                            border.width: 1
                        }

                        contentItem: Text {
                            text: "Exit"
                            font.pixelSize: 14
                            font.family: "Monospace"
                            font.bold: true
                            color: "#ffaaaa"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            root.terminateAndExit();
                        }
                    }
                }
            }
        }
    }
}
