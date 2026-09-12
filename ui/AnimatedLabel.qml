import QtQuick

// A label whose string swaps in-place with a fade + slide instead of jumping.
// Two stacked Text layers do the swap: the outgoing one fades to 0 and slides
// left while the incoming one slides in from the right - the shell equivalent of
// a crossfade - and only the new content is ever shown at rest.
//
// Shaping the whole swap as a single restartable animation pair means rapid
// changes converge to the newest string rather than queueing: each new content
// retargets the incoming layer (its text is always the newest already, reassigned
// on every change) and restarts the pair from wherever it currently is, so the
// incoming layer always lands on the newest frame and any stale run is dropped.
// `finished` on the in-animation is the only place a promotion happens, and it
// is guarded by a generation counter so an interrupted run can't promote a
// string that was already superseded.
//
// Width is the resting one for *root.content* (via TextMetrics, clamped by
// maxWidth), so a layout drawn around this label grows to the target string
// immediately while the swipe plays - the pill-shaped island relies on that to
// morph in step with a changing title rather than snapping.
Item {
    id: root

    // The real string to show. Bind the changing value here, not to `text`:
    // `text` belongs to whichever layer is painting, and both layers are fed
    // imperatively during a swap.
    property string content: ""
    property color color: "#e6eef4"
    property font font
    property int elide: Text.ElideRight
    property int horizontalAlignment: Text.AlignLeft
    property int verticalAlignment: Text.AlignVCenter
    // Cap the label's content-box width so long strings elide instead of
    // stretching the layout past what the caller can afford. -1 = no cap.
    property real maxWidth: -1

    // The content box this label claims: the string's advance width clamped to
    // maxWidth. This (and only this) is what the width a caller sees follows,
    // so it never breathes as the swipe plays.
    readonly property real contentWidth: {
        if (root.maxWidth >= 0)
            return Math.min(sizer.advanceWidth, root.maxWidth);
        return sizer.advanceWidth;
    }

    implicitWidth: root.contentWidth
    implicitHeight: sizer.height

    // ── the two layers. shown holds the outgoing string, incoming is the new
    // one sliding over it; incoming above (later sibling) so it reads on top
    // during the overlap.
    Text {
        id: shown
        anchors.fill: parent
        color: root.color
        font: root.font
        elide: root.elide
        horizontalAlignment: root.horizontalAlignment
        verticalAlignment: root.verticalAlignment
    }

    Text {
        id: incoming
        anchors.fill: parent
        color: root.color
        font: root.font
        elide: root.elide
        horizontalAlignment: root.horizontalAlignment
        verticalAlignment: root.verticalAlignment
        opacity: 0
    }

    // ── the swipe: shown out (opacity→0, x→-8), incoming in (opacity→1, x→0) ──
    ParallelAnimation {
        id: outAnim
        NumberAnimation {
            target: shown
            property: "opacity"
            to: 0
            duration: 140
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: shown
            property: "x"
            to: -8
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    ParallelAnimation {
        id: inAnim
        NumberAnimation {
            target: incoming
            property: "opacity"
            to: 1
            duration: 180
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: incoming
            property: "x"
            to: 0
            duration: 220
            easing.type: Easing.OutCubic
        }
        // Only a natural completion promotes; a restart (new content landing
        // mid-swap) emits stopped() instead and the generation check below
        // ignores whatever stale completion does slip through.
        onFinished: root.promote()
    }

    // Every swap bumps the generation; promote() checks a stale run can't win.
    property int swapGen: 0
    property int armedGen: -1

    onContentChanged: root.swap()

    function swap(): void {
        root.swapGen++;
        const gen = root.swapGen;
        root.armedGen = gen;

        incoming.text = root.content;
        incoming.opacity = 0;
        incoming.x = 8;

        outAnim.stop();
        inAnim.stop();

        shown.opacity = 1;
        shown.x = 0;

        outAnim.restart();
        inAnim.restart();
    }

    function promote(): void {
        if (root.armedGen < root.swapGen)
            return;
        shown.text = incoming.text;
        shown.opacity = 1;
        shown.x = 0;
        incoming.opacity = 0;
        incoming.x = 0;
        incoming.text = "";
    }

    TextMetrics {
        id: sizer
        font: root.font
        text: root.content
    }
}