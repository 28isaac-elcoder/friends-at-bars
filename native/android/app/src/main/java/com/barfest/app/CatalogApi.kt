package com.barfest.app

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

data class CatalogVenue(
    val id: String,
    val name: String,
    val area: String,
    val latitude: Double,
    val longitude: Double,
    val radiusM: Int,
)

/**
 * Same Supabase REST catalog as iOS — no second CMS.
 */
object CatalogApi {
    // Inject via BuildConfig / local.properties in a full Gradle project.
    var supabaseUrl: String = "https://YOUR_PROJECT.supabase.co"
    var anonKey: String = "YOUR_ANON_KEY"

    suspend fun venues(includeTest: Boolean = false): List<CatalogVenue> =
        withContext(Dispatchers.IO) {
            val testFilter = if (includeTest) "" else "&is_test=eq.false"
            val url =
                "$supabaseUrl/rest/v1/catalog_venues?is_active=eq.true$testFilter&order=sort_order.asc&select=*"
            val body = get(url)
            val arr = JSONArray(body)
            buildList {
                for (i in 0 until arr.length()) {
                    val o = arr.getJSONObject(i)
                    add(
                        CatalogVenue(
                            id = o.getString("id"),
                            name = o.getString("name"),
                            area = o.getString("area"),
                            latitude = o.getDouble("latitude"),
                            longitude = o.getDouble("longitude"),
                            radiusM = o.optInt("radius_m", 100),
                        )
                    )
                }
            }
        }

    suspend fun listingsJson(): String =
        withContext(Dispatchers.IO) {
            get("$supabaseUrl/rest/v1/catalog_listings?is_active=eq.true&order=priority.desc&select=*")
        }

    private fun get(urlStr: String): String {
        val conn = (URL(urlStr).openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            setRequestProperty("apikey", anonKey)
            setRequestProperty("Authorization", "Bearer $anonKey")
        }
        return conn.inputStream.bufferedReader().readText()
    }
}
