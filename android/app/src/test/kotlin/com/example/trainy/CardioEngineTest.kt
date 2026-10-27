package com.example.trainy

import org.junit.Assert.*
import org.junit.Test
import org.json.JSONArray
import org.json.JSONObject

class CardioEngineTest {
    @Test fun measurementContractReplayV2() {
        val cases = JSONObject(java.io.File("../../test/fixtures/gps_measurement_v2.json").readText()).getJSONArray("cases")
        for (i in 0 until cases.length()) {
            val fixture = cases.getJSONObject(i)
            val e = engine(listOf(step("run", 1000.0, "distance")))
            e.state.put("autoPause", false)
            val samples = fixture.getJSONArray("samples")
            for (n in 0 until samples.length()) {
                val p = samples.getJSONObject(n)
                e.tick(p.getDouble("received"))
                e.location(p.getDouble("lat"), p.getDouble("lon"), p.getDouble("accuracy"),
                    if (p.isNull("speed")) null else p.getDouble("speed"), p.getDouble("time"),
                    (p.getDouble("time") * 1000).toLong(),
                    if (p.isNull("speedAccuracy")) null else p.getDouble("speedAccuracy"), p.getDouble("received"))
            }
            val meters = e.state.optDouble("distanceMeters")
            assertTrue("${fixture.getString("name")}: $meters", meters in fixture.getDouble("minMeters")..fixture.getDouble("maxMeters"))
            assertEquals(fixture.getString("name"), fixture.getString("paceQuality"), e.state.optString("paceQuality"))
        }
    }
    @Test fun goalRemainsCompletedThroughExtraPauseAndRecovery() {
        val cues = mutableListOf<String>()
        val e = engine(listOf(step("run", 10.0)), indoor = true, cues = cues)
        e.tick(0.0); e.tick(15.0)
        assertEquals(5.0, e.state.getDouble("stepSeconds"), .001)
        e.pause()
        val recovered = CardioEngine(JSONObject(e.state.toString()), cues::add)
        recovered.resume(); recovered.tick(20.0); recovered.tick(25.0); recovered.finish()
        assertTrue(recovered.state.getBoolean("goalReached"))
        val results = recovered.state.getJSONArray("results")
        assertEquals(10.0, results.getJSONObject(0).getDouble("seconds"), .001)
        assertEquals(10.0, results.getJSONObject(1).getDouble("seconds"), .001)
        assertFalse(results.getJSONObject(1).getBoolean("partial"))
        assertTrue(results.getJSONObject(1).getBoolean("continuation"))
        assertEquals(1, cues.count { it == "goalReached" })
    }
    @Test fun staleDuplicateAndFutureSamplesNeverAddDistance() {
        val e = engine(listOf(step("run", 1000.0, "distance")))
        e.location(52.0, 13.0, 3.0, 2.0, 0.0, 0, .1)
        assertNull(e.location(52.0001, 13.0, 3.0, 2.0, 0.0, 0, .1))
        assertNull(e.location(52.0001, 13.0, 3.0, 2.0, 1.0, 1000, .1, 10.0))
        assertNull(e.location(52.0001, 13.0, 3.0, 2.0, 15.0, 15000, .1, 10.0))
        assertEquals(0.0, e.state.optDouble("distanceMeters"), .001)
    }
    @Test fun routeGoalIncludesPriorTimeStepsAndKeepsOvershoot() {
        val e = engine(listOf(step("warm", 5.0), step("easy", 10.0, "distance").put("routeTotalMeters", 20.0)))
        e.state.put("autoPause", false)
        for (t in 0..15) {
            e.tick(t.toDouble())
            e.location(52.0 + t * 2.0 / 111195, 13.0, 3.0, 2.0, t.toDouble(), t * 1000L, .1)
        }
        assertTrue(e.state.getBoolean("goalReached"))
        val results = e.state.getJSONArray("results")
        val planned = results.getJSONObject(0).getDouble("meters") + results.getJSONObject(1).getDouble("meters")
        assertEquals(20.0, planned, .2)
        assertTrue(e.state.getDouble("stepMeters") > 7)
        assertEquals("active", e.state.getString("status"))
    }
    @Test fun sustainedToleranceGraceAndCooldownShareDisplayedPace() {
        val cues = mutableListOf<String>()
        val s = step("easy", 400.0).put("primaryTarget", "pace").put("maxSpeed", 1000.0/570).put("intensity", "easy")
        val e = engine(listOf(s), cues = cues)
        val speed = 1000.0/480
        for (t in 0..150) {
            e.tick(t.toDouble())
            e.location(52.0 + t * speed / 111195, 13.0, 3.0, speed, t.toDouble(), t * 1000L, .1)
            if (t == 49) assertEquals(0, cues.count { it == "slower" })
            if (t == 60) assertEquals(1, cues.count { it == "slower" })
            if (t == 130) assertEquals(1, cues.count { it == "slower" })
        }
        assertEquals(2, cues.count { it == "slower" })
        assertEquals(speed, e.state.getDouble("speed"), .001)
    }
    @Test fun stationaryFixesWithoutSpeedStillAutoPause() {
        val e = engine(listOf(step("a", 300.0)))
        for (second in 0..35) {
            e.tick(second.toDouble())
            e.location(52.0 + minOf(second, 5) * .000009, 13.0, 3.0, null, second.toDouble(), second * 1000L)
        }
        assertEquals("paused", e.state.getString("status"))
        assertTrue(e.state.getBoolean("autoPaused"))
    }
    @Test fun delayedTickKeepsMonotonicTimeAndCountdownOvershoot() {
        val e = engine(listOf(step("a", 10.0), step("b", 20.0)), indoor = true)
        e.state.put("countdown", 3.0)
        e.tick(0.0); e.tick(18.0)
        assertEquals(15.0, e.state.getDouble("activeSeconds"), .001)
        assertEquals(1, e.state.getInt("index"))
        assertEquals(5.0, e.state.getDouble("stepSeconds"), .001)
    }
    @Test fun lateFixSplitsDistanceAcrossTimeBoundary() {
        val e = engine(listOf(step("a", 5.0), step("b", 50.0, "distance")))
        e.tick(0.0); e.location(52.0, 13.0, 3.0, 2.0, 0.0, 0)
        e.tick(10.0)
        e.location(52.000179864, 13.0, 3.0, 2.0, 10.0, 10000)
        assertEquals(10.0, e.state.getJSONArray("results").getJSONObject(0).getDouble("meters"), .1)
        assertEquals(10.0, e.state.getDouble("stepMeters"), .1)
        assertEquals(20.0, e.state.getDouble("distanceMeters"), .1)
    }
    @Test fun optingOutOfSpeechDoesNotDisableRecording() {
        val cues = mutableListOf<String>()
        val e = engine(listOf(step("a", 60.0)), indoor = true, cues = cues)
        e.state.put("audioEnabled", false)
        e.tick(0.0); e.tick(60.0)
        assertEquals("active", e.state.getString("status"))
        assertTrue(e.state.getBoolean("goalReached"))
        assertTrue(cues.isEmpty())
    }
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
        resumed.finish()
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
        assertEquals("active", e.state.getString("status"))
        assertTrue(e.state.getBoolean("goalReached"))
        assertEquals(6.0, e.state.getDouble("activeSeconds"), .001)
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
        assertEquals(1, cues.count { it == "faster" })
        assertEquals(0, cues.count { it == "slower" })
    }
    @Test fun halfwayAndNearEndAreEmittedOnce() {
        val cues = mutableListOf<String>()
        val e = engine(listOf(step("a", 60.0)), indoor = true, cues = cues)
        for (second in 0..65) e.tick(second.toDouble())
        assertEquals(1, cues.count { it == "half a" }); assertEquals(1, cues.count { it == "near a" })
        val count = e.state.getJSONArray("results").length(); e.finish()
        assertEquals(count + 1, e.state.getJSONArray("results").length())
        assertTrue(e.state.getJSONArray("results").getJSONObject(count).getBoolean("continuation"))
        assertFalse(e.state.getJSONArray("results").getJSONObject(count).getBoolean("partial"))
    }
    @Test fun easyPaceCapNeverAsksForAccelerationButWarnsWhenTooFast() {
        for (speed in listOf(1.0, 4.0)) {
            val cues = mutableListOf<String>()
            val s = step("easy", 300.0).put("primaryTarget", "pace").put("maxSpeed", 2.5)
                .put("intensity", "easy").put("minSpeed", 2.0)
            val e = engine(listOf(s), cues = cues)
            for (second in 0..90) {
                e.location(52.0 + second * speed / 111195, 13.0, 5.0, speed, second.toDouble(), second * 1000L, .1)
                e.tick(second.toDouble())
            }
            assertEquals(0, cues.count { it == "faster" })
            assertEquals(if (speed > 2.5) 1 else 0, cues.count { it == "slower" })
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
