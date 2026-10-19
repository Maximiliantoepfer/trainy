package com.example.trainy

import org.junit.Assert.*
import org.junit.Test
import org.json.JSONArray
import java.io.File

class CardioSampleJournalTest {
    @Test fun pagesReplayAfterFailedCommitAndResumeFromCursor() {
        val file = File.createTempFile("trainy-journal-test", ".jsonl")
        try {
            file.writeText((0..2004).joinToString("\n", postfix = "\n") { "{\"sequence\":$it}" })
            val cursor = CardioSampleJournal()
            val first = cursor.read(file, -1, "one")
            assertEquals(1000, JSONArray(first).length())
            assertEquals(first, cursor.read(file, -1, "one"))
            assertEquals(1000, JSONArray(cursor.read(file, 999, "one")).length())
            assertEquals(5, JSONArray(cursor.read(file, 1999, "one")).length())
            assertEquals("[]", cursor.read(file, 2004, "one"))
            file.appendText("{\"sequence\":2005}\n")
            assertEquals(2005, JSONArray(cursor.read(file, 2004, "one")).getJSONObject(0).getInt("sequence"))
        } finally { file.delete() }
    }
    @Test fun crashTailRepairNeverReusesCommittedSequence() {
        val file = File.createTempFile("trainy-journal-test", ".jsonl")
        try {
            file.writeText("{\"sequence\":50}\n{\"sequence\":51}\n{\"sequence\":52")
            assertEquals(51L, CardioSampleJournal.reconcile(file, 49))
            assertTrue(file.readText().endsWith("{\"sequence\":51}\n"))
            assertEquals(60L, CardioSampleJournal.reconcile(file, 60))
        } finally { file.delete() }
    }
}
