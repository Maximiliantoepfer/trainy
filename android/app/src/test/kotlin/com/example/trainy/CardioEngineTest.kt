package com.example.trainy

import org.junit.Assert.*
import org.junit.Test
import org.json.JSONArray
import org.json.JSONObject

class CardioEngineTest {
    private fun step(id: String, amount: Double, goal: String = "time", movement: String = "run") = JSONObject()
        .put("id", id).put("amount", amount).put("goal", goal).put("movement", movement).put("primaryTarget", "effort")
        .put("displayName", id).put("startCue", "start $id").put("halfCue", "half $id").put("nearCue", "near $id")
    private fun engine(steps: List<JSONObject>, indoor: Boolean = false, cues: MutableList<String> = mutableListOf()): CardioEngine {
        val state = CardioEngine.fresh(JSONObject().put("version", 1).put("sessionId", "test")
            .put("sport", "running").put("indoor", indoor).put("autoPause", true)
            .put("steps", JSONArray(steps)).put("messages", JSONObject().put("paused", "paused").put("resume", "resume").put("completed", "completed").put("faster", "faster").put("slower", "slower")))
        state.put("countdown", 0.0)
        return CardioEngine(state, cues::add)
    }
    @Test fun timedRepeatsFinishWithoutUiAndPreserveOvershoot() {
        val e = engine(listOf(step("a", 2.5), step("b", 2.5)), indoor = true)
        for (second in 0..6) e.tick(second.toDouble())
        assertEquals("completed", e.state.getString("status"))
        assertEquals(5.0, e.state.getDouble("activeSeconds"), .001)
        assertEquals(2, e.state.getJSONArray("results").length())
        assertEquals(2.5, e.state.getJSONArray("results").getJSONObject(0).getDouble("seconds"), .001)
    }
    @Test fun missingGpsDoesNotMeanStoppedAndCannotCompleteDistance() {
        val e = engine(listOf(step("a", 100.0, "distance")))
        for (second in 0..30) e.tick(second.toDouble())
        assertEquals("active", e.state.getString("status"))
        assertEquals("gpsLost", e.state.getString("gps"))
        assertEquals(0.0, e.state.getDouble("distanceMeters"), .001)
    }
    @Test fun stationaryFixesPauseAfterTenSecondsAndMovementResumes() {
        val e = engine(listOf(step("a", 300.0)))
        for (second in 0..10) {
            e.location(52.0, 13.0, 5.0, 0.0, second.toDouble(), second * 1000L)
            e.tick(second.toDouble())
        }
        assertEquals("paused", e.state.getString("status"))
        assertTrue(e.state.getBoolean("autoPaused"))
        e.location(52.00001, 13.0, 5.0, 1.0, 11.0, 11000)
        assertEquals("active", e.state.getString("status"))
        assertEquals(0.0, e.state.getDouble("distanceMeters"), .001)
    }
    @Test fun walkingRecoveryKeepsItsClockWhenStationary() {
        val e = engine(listOf(step("rest", 30.0, movement = "walk")))
        for (second in 0..20) { e.location(52.0, 13.0, 5.0, 0.0, second.toDouble(), second * 1000L); e.tick(second.toDouble()) }
        assertEquals("active", e.state.getString("status"))
        assertEquals(20.0, e.state.getDouble("activeSeconds"), .001)
    }
    @Test fun inaccurateFixesAndTeleportsAreRejected() {
        val e = engine(listOf(step("a", 1000.0, "distance")))
        assertNull(e.location(52.0, 13.0, 80.0, 2.0, 0.0, 0))
        assertNull(e.location(52.0, 13.0, Double.NaN, 2.0, 0.0, 0))
        assertNull(e.location(91.0, 13.0, 5.0, 2.0, 0.0, 0))
        assertNotNull(e.location(52.0, 13.0, 5.0, 2.0, 1.0, 1000))
        assertNull(e.location(53.0, 14.0, 5.0, 2.0, 2.0, 2000))
        assertEquals(0.0, e.state.getDouble("distanceMeters"), .001)
    }
    @Test fun manualPauseNeverAutoResumes() {
        val e = engine(listOf(step("a", 100.0)))
        e.pause()
        e.location(52.0, 13.0, 5.0, 3.0, 1.0, 1000); e.tick(1.0)
        assertEquals("paused", e.state.getString("status"))
        e.resume(); e.tick(3.0); e.tick(4.0)
        assertEquals(1.0, e.state.getDouble("activeSeconds"), .001)
    }
    @Test fun paceCuesHaveGraceSustainedDeviationAndCooldown() {
        val cues = mutableListOf<String>()
        val s = step("a", 300.0).put("primaryTarget", "pace").put("minSpeed", 2.5).put("maxSpeed", 3.0)
        val e = engine(listOf(s), cues = cues)
        for (second in 0..90) {
            e.location(52.0 + second * .000009, 13.0, 5.0, 1.0, second.toDouble(), second * 1000L)
            e.tick(second.toDouble())
        }
        assertEquals(2, cues.count { it == "faster" })
        assertEquals(0, cues.count { it == "slower" })
    }
    @Test fun halfwayAndNearEndAreEmittedOnce() {
        val cues = mutableListOf<String>()
        val e = engine(listOf(step("a", 60.0)), indoor = true, cues = cues)
        for (second in 0..65) e.tick(second.toDouble())
        assertEquals(1, cues.count { it == "half a" }); assertEquals(1, cues.count { it == "near a" })
        val count = e.state.getJSONArray("results").length(); e.finish()
        assertEquals(count, e.state.getJSONArray("results").length())
    }
}
