package com.example.trainy

import org.junit.Assert.*
import org.junit.Test
import org.json.JSONArray
import org.json.JSONObject

class CardioEngineTest {
    @Test fun sharedPlatformReplay() {
        val file = java.io.File("../../test/fixtures/cardio_replay.json")
        val cases = JSONObject(file.readText()).getJSONArray("cases")
        for (i in 0 until cases.length()) {
            val fixture = cases.getJSONObject(i)
            val state = CardioEngine.fresh(JSONObject().put("version", 1).put("sessionId", fixture.getString("name"))
                .put("indoor", fixture.getBoolean("indoor")).put("steps", fixture.getJSONArray("steps")))
            state.put("countdown", 0)
            val engine = CardioEngine(state) {}
            val ticks = fixture.getJSONArray("ticks")
            for (n in 0 until ticks.length()) engine.tick(ticks.getDouble(n))
            assertEquals(fixture.getString("expectedStatus"), state.getString("status"))
            assertEquals(fixture.getDouble("expectedSeconds"), state.getDouble("activeSeconds"), .001)
            assertEquals(fixture.getInt("expectedIndex"), state.getInt("index"))
        }
    }
    @Test fun slowRunningWithoutSpeedAccumulatesAgainstAnchor() {
        val e = engine(listOf(step("a", 1000.0, "distance")))
        for (second in 0..60) {
            e.tick(second.toDouble())
            e.location(52.0 + second * .000009, 13.0, 5.0, null, second.toDouble(), second * 1000L)
        }
        assertTrue(e.state.getDouble("distanceMeters") > 55)
        assertTrue(e.state.getDouble("distanceMeters") < 65)
    }
    @Test fun distanceOvershootUsesLatestFixIntervalNotWholeRun() {
        val e = engine(listOf(step("a", 1000.0, "distance"), step("b", 60.0)))
        e.location(52.0, 13.0, 5.0, 10.0, 100.0, 100000)
        e.state.put("stepMeters", 950.0).put("stepSeconds", 910.0)
            .put("distanceMeters", 950.0).put("activeSeconds", 910.0)
        e.location(52.00089932, 13.0, 5.0, 10.0, 110.0, 110000)
        assertEquals(1, e.state.getInt("index"))
        assertEquals(5.0, e.state.getDouble("stepSeconds"), .01)
        assertEquals(50.0, e.state.getDouble("stepMeters"), .1)
    }
    @Test fun routeMarksPauseAndCueIdentitySurvivesRecovery() {
        val cues = mutableListOf<String>()
        val e = engine(listOf(step("a", 60.0)), indoor = false, cues = cues)
        for (second in 0..35) e.tick(second.toDouble())
        e.pause()
        assertFalse(e.location(52.0, 13.0, 5.0, 1.0, 36.0, 36000)!!.getBoolean("active"))
        val resumed = CardioEngine(JSONObject(e.state.toString()), cues::add)
        resumed.resume()
        for (second in 36..80) resumed.tick(second.toDouble())
        assertEquals(1, cues.count { it == "half a" })
        assertEquals(1, cues.count { it == "completed" })
    }
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
    @Test fun easyPaceCapNeverAsksForAccelerationButWarnsWhenTooFast() {
        for (speed in listOf(1.0, 4.0)) {
            val cues = mutableListOf<String>()
            val s = step("easy", 300.0).put("primaryTarget", "pace").put("maxSpeed", 2.5)
            val e = engine(listOf(s), cues = cues)
            for (second in 0..90) {
                e.location(52.0 + second * .000009, 13.0, 5.0, speed, second.toDouble(), second * 1000L)
                e.tick(second.toDouble())
            }
            assertEquals(0, cues.count { it == "faster" })
            assertEquals(if (speed > 2.5) 2 else 0, cues.count { it == "slower" })
        }
    }
    @Test fun standingRecoveryRunsItsTimerAndNextRunStillAutoPauses() {
        val rest = step("rest", 15.0, movement = "rest").put("standingRecovery", true)
        val e = engine(listOf(rest, step("run", 300.0)))
        for (second in 0..30) {
            e.location(52.0, 13.0, 5.0, 0.0, second.toDouble(), second * 1000L)
            e.tick(second.toDouble())
        }
        assertEquals(1, e.state.getJSONArray("results").length())
        assertEquals("paused", e.state.getString("status"))
    }
}
