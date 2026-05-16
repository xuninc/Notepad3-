package com.corey.notepad3.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class VirtualTrackpadStateTest {
    @Test
    fun defaultSizeStartsAtMediumAndCyclesThroughLargeExtraLargeSmallMedium() {
        val initial = VirtualTrackpadState()

        assertEquals(VirtualTrackpadSize.MEDIUM, initial.size)
        assertEquals(TrackpadBounds(width = 220f, height = 160f), initial.bounds)

        val large = initial.cycleSize(container = TrackpadBounds(width = 500f, height = 500f))
        val extraLarge = large.cycleSize(container = TrackpadBounds(width = 500f, height = 500f))
        val small = extraLarge.cycleSize(container = TrackpadBounds(width = 500f, height = 500f))
        val medium = small.cycleSize(container = TrackpadBounds(width = 500f, height = 500f))

        assertEquals(VirtualTrackpadSize.LARGE, large.size)
        assertEquals(TrackpadBounds(width = 270f, height = 198f), large.bounds)
        assertEquals(VirtualTrackpadSize.EXTRA_LARGE, extraLarge.size)
        assertEquals(TrackpadBounds(width = 336f, height = 248f), extraLarge.bounds)
        assertEquals(VirtualTrackpadSize.SMALL, small.size)
        assertEquals(TrackpadBounds(width = 180f, height = 132f), small.bounds)
        assertEquals(VirtualTrackpadSize.MEDIUM, medium.size)
    }

    @Test
    fun cycleSizePreservesCenterBeforeClamping() {
        val state = VirtualTrackpadState(position = TrackpadPoint(x = 100f, y = 80f))

        val resized = state.cycleSize(container = TrackpadBounds(width = 600f, height = 500f))

        assertEquals(VirtualTrackpadSize.LARGE, resized.size)
        assertEquals(75f, resized.position.x, 0.001f)
        assertEquals(61f, resized.position.y, 0.001f)
        assertEquals(210f, resized.center.x, 0.001f)
        assertEquals(160f, resized.center.y, 0.001f)
    }

    @Test
    fun anchorLockPreventsPanelDragUntilUnpinned() {
        val container = TrackpadBounds(width = 480f, height = 360f)
        val pinned = VirtualTrackpadState(position = TrackpadPoint(x = 120f, y = 90f)).togglePinned()

        val stillPinned = pinned.movePanelBy(dx = 40f, dy = 30f, container = container)
        val moved = stillPinned.togglePinned().movePanelBy(dx = 40f, dy = 30f, container = container)

        assertTrue(pinned.isPinned)
        assertEquals(TrackpadPoint(x = 120f, y = 90f), stillPinned.position)
        assertFalse(moved.isPinned)
        assertEquals(TrackpadPoint(x = 160f, y = 120f), moved.position)
    }

    @Test
    fun panelDragClampsInsideContainerWithInsets() {
        val container = TrackpadBounds(width = 320f, height = 260f)
        val insets = TrackpadInsets(left = 8f, top = 10f, right = 12f, bottom = 14f)
        val state = VirtualTrackpadState(
            position = TrackpadPoint(x = 100f, y = 70f),
            size = VirtualTrackpadSize.SMALL,
            insets = insets,
        )

        val lowerRight = state.movePanelBy(dx = 500f, dy = 500f, container = container)
        val upperLeft = lowerRight.movePanelBy(dx = -500f, dy = -500f, container = container)

        assertEquals(128f, lowerRight.position.x, 0.001f)
        assertEquals(114f, lowerRight.position.y, 0.001f)
        assertEquals(8f, upperLeft.position.x, 0.001f)
        assertEquals(10f, upperLeft.position.y, 0.001f)
    }

    @Test
    fun pointerDeltaUsesSensitivityAndClampsToPointerBounds() {
        val pointerBounds = TrackpadBounds(width = 100f, height = 80f)
        val state = VirtualTrackpadState(pointerPosition = TrackpadPoint(x = 50f, y = 40f))

        val moved = state.movePointerBy(dx = 10f, dy = -5f, pointerBounds = pointerBounds)
        val clamped = moved.movePointerBy(dx = 100f, dy = 100f, pointerBounds = pointerBounds)

        assertEquals(68f, moved.pointerPosition.x, 0.001f)
        assertEquals(31f, moved.pointerPosition.y, 0.001f)
        assertEquals(99f, clamped.pointerPosition.x, 0.001f)
        assertEquals(79f, clamped.pointerPosition.y, 0.001f)
    }

    @Test
    fun dragTranslationProducesIncrementalScaledPointerDelta() {
        val state = VirtualTrackpadState(pointerPosition = TrackpadPoint(x = 10f, y = 10f))
        val drag = TrackpadPointerDrag()

        val first = drag.update(state, translation = TrackpadPoint(x = 3f, y = 4f), pointerBounds = TrackpadBounds(width = 200f, height = 200f))
        val second = first.drag.update(first.state, translation = TrackpadPoint(x = 5f, y = 1f), pointerBounds = TrackpadBounds(width = 200f, height = 200f))

        assertEquals(5.4f, first.delta.dx, 0.001f)
        assertEquals(7.2f, first.delta.dy, 0.001f)
        assertFalse(first.movedPastTapSlop)
        assertEquals(3.6f, second.delta.dx, 0.001f)
        assertEquals(-5.4f, second.delta.dy, 0.001f)
        assertTrue(second.movedPastTapSlop)
        assertEquals(19f, second.state.pointerPosition.x, 0.001f)
        assertEquals(11.8f, second.state.pointerPosition.y, 0.001f)
    }
}
