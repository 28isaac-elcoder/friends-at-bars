package com.barfest.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.Place
import androidx.compose.material.icons.filled.SportsEsports
import androidx.compose.material.icons.filled.Tag
import androidx.compose.material.icons.filled.Forum
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier.Modifier

/**
 * Kotlin shell sharing the same Supabase catalog + live APIs as the Swift app.
 * Map: Google Maps or MapLibre Native (plug in later). Location engine deferred.
 */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            var tab by remember { mutableIntStateOf(3) }
            val titles = listOf("Activities", "Deals", "Chat", "Map", "Games")
            Scaffold(
                bottomBar = {
                    NavigationBar {
                        titles.forEachIndexed { index, title ->
                            NavigationBarItem(
                                selected = tab == index,
                                onClick = { tab = index },
                                icon = {
                                    Icon(
                                        when (index) {
                                            0 -> Icons.Default.Place
                                            1 -> Icons.Default.Tag
                                            2 -> Icons.Default.Forum
                                            3 -> Icons.Default.Map
                                            else -> Icons.Default.SportsEsports
                                        },
                                        contentDescription = title
                                    )
                                },
                                label = { Text(title) }
                            )
                        }
                    }
                }
            ) { padding ->
                Text(
                    text = when (tab) {
                        0 -> "Activities — fetch live_locations / checkins (see CatalogApi)"
                        1 -> "Deals — catalog_listings"
                        2 -> "Chat — create_chat_post RPC"
                        3 -> "Map — CatalogApi.venues() → MapLibre / Google Maps"
                        else -> "Games — catalog_game_content word packs"
                    },
                    modifier = Modifier.padding(padding)
                )
            }
        }
    }
}
