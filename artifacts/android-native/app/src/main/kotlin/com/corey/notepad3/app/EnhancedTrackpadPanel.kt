package com.corey.notepad3.app

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.filled.OpenInFull
import androidx.compose.material.icons.filled.PushPin
import androidx.compose.material.icons.filled.TouchApp
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.corey.notepad3.theme.Palette

@Composable
fun EnhancedTrackpadPanel(
    state: VirtualTrackpadState,
    containerBounds: TrackpadBounds,
    pointerBounds: TrackpadBounds,
    palette: Palette,
    onStateChange: (VirtualTrackpadState) -> Unit,
    onPointerDelta: (TrackpadDelta) -> Unit,
    onMoveCaret: (TrackpadDirection) -> Unit,
    onClose: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Surface(
        color = palette.card.toTrackpadColor(),
        border = BorderStroke(1.dp, palette.primary.toTrackpadColor()),
        shape = RoundedCornerShape(palette.radius.dp),
        modifier = modifier
            .width(state.bounds.width.dp)
            .height(state.bounds.height.dp),
    ) {
        Column {
            TrackpadHeader(
                state = state,
                containerBounds = containerBounds,
                palette = palette,
                onStateChange = onStateChange,
                onClose = onClose,
            )
            TrackpadDragSurface(
                state = state,
                pointerBounds = pointerBounds,
                palette = palette,
                onStateChange = onStateChange,
                onPointerDelta = onPointerDelta,
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth(),
            )
            DirectionalFallbackRow(
                palette = palette,
                onMoveCaret = onMoveCaret,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 8.dp, vertical = 8.dp),
            )
        }
    }
}

@Composable
private fun TrackpadHeader(
    state: VirtualTrackpadState,
    containerBounds: TrackpadBounds,
    palette: Palette,
    onStateChange: (VirtualTrackpadState) -> Unit,
    onClose: () -> Unit,
) {
    val currentState = rememberUpdatedState(state)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(28.dp)
            .background(palette.titleGradientEnd.toTrackpadColor())
            .pointerInput(containerBounds) {
                detectDragGestures { change, dragAmount ->
                    change.consume()
                    val latest = currentState.value
                    onStateChange(
                        latest.movePanelBy(
                            dx = dragAmount.x,
                            dy = dragAmount.y,
                            container = containerBounds,
                        ),
                    )
                }
            }
            .padding(start = 8.dp, end = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            Icons.Filled.TouchApp,
            contentDescription = null,
            tint = palette.primaryForeground.toTrackpadColor(),
            modifier = Modifier.size(15.dp),
        )
        Text(
            text = if (state.isPinned) "Trackpad pinned" else "Trackpad",
            color = palette.primaryForeground.toTrackpadColor(),
            style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.SemiBold),
            modifier = Modifier
                .weight(1f)
                .padding(horizontal = 6.dp),
            maxLines = 1,
        )
        TrackpadIconButton(
            icon = Icons.Filled.PushPin,
            label = if (state.isPinned) "Unpin trackpad" else "Pin trackpad",
            tint = palette.primaryForeground.toTrackpadColor(),
            onClick = { onStateChange(state.togglePinned()) },
        )
        TrackpadIconButton(
            icon = Icons.Filled.OpenInFull,
            label = "Cycle trackpad size",
            tint = palette.primaryForeground.toTrackpadColor(),
            onClick = { onStateChange(state.cycleSize(containerBounds)) },
        )
        TrackpadIconButton(
            icon = Icons.Filled.Close,
            label = "Close trackpad",
            tint = palette.primaryForeground.toTrackpadColor(),
            onClick = onClose,
        )
    }
}

@Composable
private fun TrackpadDragSurface(
    state: VirtualTrackpadState,
    pointerBounds: TrackpadBounds,
    palette: Palette,
    onStateChange: (VirtualTrackpadState) -> Unit,
    onPointerDelta: (TrackpadDelta) -> Unit,
    modifier: Modifier = Modifier,
) {
    val drag = remember { TrackpadPointerDrag() }
    val currentState = rememberUpdatedState(state)
    Box(
        modifier = modifier
            .background(palette.muted.toTrackpadColor())
            .border(1.dp, palette.border.toTrackpadColor())
            .pointerInput(pointerBounds) {
                var dragState = drag.reset()
                detectDragGestures(
                    onDragStart = { dragState = drag.reset() },
                    onDragEnd = { dragState = drag.reset() },
                    onDragCancel = { dragState = drag.reset() },
                ) { change, dragAmount ->
                    change.consume()
                    val last = dragState.lastTranslation
                    val nextTranslation = Offset(
                        x = last.x + dragAmount.x,
                        y = last.y + dragAmount.y,
                    )
                    val result = dragState.update(
                        state = currentState.value,
                        translation = TrackpadPoint(nextTranslation.x, nextTranslation.y),
                        pointerBounds = pointerBounds,
                    )
                    dragState = result.drag
                    onStateChange(result.state)
                    onPointerDelta(result.delta)
                }
            },
        contentAlignment = Alignment.Center,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                text = "Drag to move pointer",
                color = palette.mutedForeground.toTrackpadColor(),
                style = MaterialTheme.typography.labelSmall,
            )
        }
    }
}

@Composable
private fun DirectionalFallbackRow(
    palette: Palette,
    onMoveCaret: (TrackpadDirection) -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Spacer(Modifier.weight(1f))
        DirectionButton(Icons.AutoMirrored.Filled.KeyboardArrowLeft, "Move left", palette, Modifier.weight(1f)) {
            onMoveCaret(TrackpadDirection.LEFT)
        }
        DirectionButton(Icons.Filled.KeyboardArrowUp, "Move up", palette, Modifier.weight(1f)) {
            onMoveCaret(TrackpadDirection.UP)
        }
        DirectionButton(Icons.Filled.KeyboardArrowDown, "Move down", palette, Modifier.weight(1f)) {
            onMoveCaret(TrackpadDirection.DOWN)
        }
        DirectionButton(Icons.AutoMirrored.Filled.KeyboardArrowRight, "Move right", palette, Modifier.weight(1f)) {
            onMoveCaret(TrackpadDirection.RIGHT)
        }
        Spacer(Modifier.weight(1f))
    }
}

@Composable
private fun DirectionButton(
    icon: ImageVector,
    label: String,
    palette: Palette,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    Button(
        onClick = onClick,
        contentPadding = androidx.compose.foundation.layout.PaddingValues(0.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = palette.secondary.toTrackpadColor(),
            contentColor = palette.foreground.toTrackpadColor(),
        ),
        shape = RoundedCornerShape(maxOf(2, palette.radius).dp),
        modifier = modifier.size(width = 36.dp, height = 30.dp),
    ) {
        Icon(icon, contentDescription = label, modifier = Modifier.size(18.dp))
    }
}

@Composable
private fun TrackpadIconButton(
    icon: ImageVector,
    label: String,
    tint: Color,
    onClick: () -> Unit,
) {
    IconButton(onClick = onClick, modifier = Modifier.size(26.dp)) {
        Icon(icon, contentDescription = label, tint = tint, modifier = Modifier.size(16.dp))
    }
}

private fun String.toTrackpadColor(): Color =
    Color(android.graphics.Color.parseColor(this))
