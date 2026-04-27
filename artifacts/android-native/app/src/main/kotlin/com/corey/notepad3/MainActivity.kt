package com.corey.notepad3

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

/**
 * Phase 0 entry point. Empty Compose surface that proves the toolchain
 * works end-to-end. Phase 1 replaces this with the real editor + theme
 * controller; for now we just verify the wrapper / AGP / Compose / IDE
 * bind together and produce a launchable APK.
 */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            MaterialTheme {
                HelloScreen()
            }
        }
    }
}

@Composable
private fun HelloScreen() {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFFDBE5F1))      // Classic palette background
            .padding(32.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = "Notepad 3++ — Phase 0\n(skeleton + CI + first APK)",
            color = Color(0xFF0F1F33),          // Classic foreground
            style = MaterialTheme.typography.titleMedium,
        )
    }
}
