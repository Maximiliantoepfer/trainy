package com.example.trainy

import android.app.Activity
import android.os.Bundle
import android.widget.TextView
import android.widget.ScrollView
import java.util.Locale

/** Health Connect must be able to open this rationale without a Flutter engine. */
class HealthPrivacyActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val de = Locale.getDefault().language == "de"
        val text = TextView(this).apply {
            textSize = 18f; setPadding(32, 48, 32, 48)
            text = if (de) "Trainy – Gesundheitsdaten\n\nTrainy liest Trainings und auf Wunsch Pulswerte aus Health Connect, um vergangene Einheiten lokal anzuzeigen und nach deiner Bestätigung zuzuordnen. Es besteht keine Live-Verbindung zu deiner Uhr. Einheiten werden nur auf deine Aktion nach Health exportiert.\n\nDaten werden lokal verarbeitet. Das optionale Cloud-Backup enthält Trainingszusammenfassungen. Detaillierte Standort- und Sensordaten werden nur mit zusätzlicher Freigabe gesichert. Es gibt keine Verwendung für Werbung. Berechtigungen lassen sich jederzeit in Health Connect widerrufen. Lokale Daten können in Trainys Einstellungen gelöscht werden."
            else "Trainy – Health data\n\nTrainy reads workouts and optional heart rates from Health Connect to display past sessions locally and link them after your confirmation. This is not a live connection to your watch. Sessions are exported to Health only when you request it.\n\nData is processed locally. Optional cloud backup contains workout summaries. Detailed location and sensor data require separate backup consent. Data is not used for advertising. Revoke access in Health Connect at any time. Local data can be deleted in Trainy settings."
        }
        setContentView(ScrollView(this).apply { addView(text) })
    }
}
