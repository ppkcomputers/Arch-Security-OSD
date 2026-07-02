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
    property int deletionStep: 0 // 0: standard/blinky, 1: ghost2, 2: ghost3, 3: ghost4, 4: gone/blank

    // Animation timeline control states
    property int introStep: 0 // 0: showing blinky, 1: showing blue ghost, 2: pacman moving/chomp complete
    property bool chompSequenceActive: false
    property bool showScore: false
    property bool showGameOver: false
    property bool cinematicDone: false
    property string pacmanMouthSource: "pacman.png"

    // Jitter offsets applied to the 800 text score element
    property int scoreJitterX: 0
    property int scoreJitterY: 0

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

                    // Reset custom cinematic chomp variables
                    root.introStep = 0;
                    root.chompSequenceActive = false;
                    root.showScore = false;
                    root.showGameOver = false;
                    root.cinematicDone = false;
                    root.pacmanMouthSource = "pacman.png";

                    // Kickoff the intro pacing controller
                    introTimelineTimer.restart();
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

    // Controls the discrete delays before launching the chomp sequence
    Timer {
        id: introTimelineTimer
        interval: 2000 // 2-second increments
        repeat: true
        running: false
        onTriggered: {
            if (root.introStep === 0) {
                // Step 0 ended: We've seen blinky for 2s. Now turn him blue.
                root.introStep = 1;
            } else if (root.introStep === 1) {
                // Step 1 ended: We've seen the blue ghost for 2s. Stop timer and launch Pacman.
                introTimelineTimer.stop();
                root.introStep = 2;
                root.chompSequenceActive = true;
                chompLoopTimer.start();
                pacmanChompAnim.restart();
            }
        }
    }

    // Handles the 2-second score jitter sequence before transitioning to Game Over
    Timer {
        id: jitterDurationTimer
        interval: 2000
        repeat: false
        running: false
        onTriggered: {
            jitterEffectTimer.stop();
            root.showScore = false;
            root.scoreJitterX = 0;
            root.scoreJitterY = 0;
            root.showGameOver = true; // Show game-over.png after score disappears
        }
    }

    // Rapid loop timer changing position offsets every 40ms to create a jitter/shake effect
    Timer {
        id: jitterEffectTimer
        interval: 40
        repeat: true
        running: false
        onTriggered: {
            root.scoreJitterX = (Math.random() * 6) - 3;
            root.scoreJitterY = (Math.random() * 6) - 3;
        }
    }

    // Sequence timer handling the final post-deletion 1-second interval image swaps
    Timer {
        id: deletionSequenceTimer
        interval: 1000
        repeat: true
        running: false
        onTriggered: {
            root.deletionStep++;
            if (root.deletionStep > 4) {
                deletionSequenceTimer.stop();
                root.isDeleting = false;
                root.ghostFound = false;
                root.scanFinished = true;
                root.statusMessage = "GHOST VAPORIZED SAFE!";
                root.threatPath = "";
                root.chompSequenceActive = false;
                root.showScore = false;
                root.showGameOver = false;
                root.cinematicDone = false;
                root.introStep = 0;
            }
        }
    }

    // Rapid loop timer to flip textures back and forth during movement
    Timer {
        id: chompLoopTimer
        interval: 150
        repeat: true
        running: false
        onTriggered: {
            if (root.pacmanMouthSource === "pacman.png") {
                root.pacmanMouthSource = "pacman3.png";
            } else {
                root.pacmanMouthSource = "pacman.png";
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
        chompSequenceActive = false;
        showScore = false;
        showGameOver = false;
        cinematicDone = false;
        introStep = 0;
        scoreJitterX = 0;
        scoreJitterY = 0;
        introTimelineTimer.stop();
        chompLoopTimer.stop();
        jitterDurationTimer.stop();
        jitterEffectTimer.stop();
        clamScanProc.running = false;
        clamScanProc.running = true;
    }

    function executeGhostDeletion() {
        if (!root.threatPath || root.isDeleting) return;

        root.isDeleting = true;
        root.statusMessage = "Purging Threat Source...";
        root.deletionStep = 1;
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
                    id: arcadeMonitor
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

                        // Interactive Animation Canvas for the left side item
                        Item {
                            id: animationCanvas
                            width: (parent.width * 0.35)
                            height: parent.height

                            // The Ghost Graphic (Changes to blue, then stays completely hidden once cinematicDone triggers)
                            Image {
                                id: threatImage
                                anchors.centerIn: parent
                                width: parent.width
                                height: parent.height
                                fillMode: Image.PreserveAspectFit
                                visible: !root.showScore && !root.showGameOver && !root.cinematicDone
                                source: {
                                    if (root.ghostFound && !root.isDeleting) {
                                        if (root.introStep === 1) return "blue.png";
                                        if (root.introStep === 2) return "blue.png";
                                        return "blinky.png";
                                    }
                                    if (root.deletionStep === 1) return "ghost2.png";
                                    if (root.deletionStep === 2) return "ghost3.png";
                                    if (root.deletionStep === 3) return "ghost4.png";
                                    if (root.deletionStep === 4) return "";
                                    return "blinky.png";
                                }
                            }

                            // The aqua blue "800" score indicator with dynamic jitter offsets applied
                            Text {
                                text: "800"
                                color: "#00ffff"
                                font.pixelSize: 24
                                font.family: "Monospace"
                                font.bold: true
                                x: ((parent.width - width) / 2) + root.scoreJitterX
                                y: ((parent.height - height) / 2) + root.scoreJitterY
                                visible: root.showScore
                            }

                            // Game Over image displayed after the score finishes jittering
                            Image {
                                id: gameOverImage
                                anchors.centerIn: parent
                                width: parent.width
                                height: parent.height
                                fillMode: Image.PreserveAspectFit
                                source: "game-over.png"
                                visible: root.showGameOver
                            }

                            // Animated Chomping Pacman Layer
                            Image {
                                id: chompingPacman
                                x: -width // Starts completely off-screen to the left
                                width: parent.width * 0.8
                                height: parent.height * 0.8
                                anchors.verticalCenter: parent.verticalCenter
                                fillMode: Image.PreserveAspectFit
                                source: root.pacmanMouthSource
                                visible: root.chompSequenceActive

                                onXChanged: {
                                    // Switch on score when pacman overlaps the center point of the vulnerable ghost
                                    if (x >= (animationCanvas.width / 2) - (width / 2) && !root.showScore && root.chompSequenceActive) {
                                        root.showScore = true;
                                        root.cinematicDone = true; // Block blue.png from reappearing
                                        jitterEffectTimer.start();
                                        jitterDurationTimer.start();
                                    }
                                }

                                NumberAnimation on x {
                                    id: pacmanChompAnim
                                    from: -chompingPacman.width
                                    to: arcadeMonitor.width + chompingPacman.width
                                    duration: 1800
                                    running: false
                                    onFinished: {
                                        root.chompSequenceActive = false;
                                        chompLoopTimer.stop();
                                    }
                                }
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
                        width: (root.ghostFound && !root.isDeleting && root.deletionStep === 0) ? 120 : 160
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
                        id: vtButton
                        width: (root.ghostFound && !root.isDeleting && root.deletionStep === 0) ? 140 : 160
                        height: 48
                        enabled: true

                        background: Rectangle {
                            radius: 8
                            color: parent.pressed ? "#1a233a" : "#24304f"
                            border.color: "#4361ee"
                            border.width: 1
                        }

                        contentItem: Text {
                            text: "Open VirusTotal"
                            font.pixelSize: 14
                            font.family: "Monospace"
                            font.bold: true
                            color: "#a4b3f6"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            Qt.openUrlExternally("https://www.virustotal.com/");
                        }
                    }

                    Button {
                        id: deleteButton
                        width: 130
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
                        width: (root.ghostFound && !root.isDeleting && root.deletionStep === 0) ? 80 : 100
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
