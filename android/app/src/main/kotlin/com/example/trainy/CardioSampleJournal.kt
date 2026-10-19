package com.example.trainy

import java.io.File
import java.io.RandomAccessFile
import org.json.JSONArray
import org.json.JSONObject

/** Append-only journal cursor. Repeated/uncommitted reads can safely replay a page. */
class CardioSampleJournal {
    private var offset = 0L
    private var delivered = -1L
    private var session: String? = null

    fun read(file: File, after: Long, sessionId: String?): String {
        if (!file.exists()) { offset = 0; delivered = after; session = sessionId; return "[]" }
        if (session != sessionId || after != delivered || offset > file.length()) offset = 0
        session = sessionId
        val values = JSONArray()
        RandomAccessFile(file, "r").use { reader ->
            reader.seek(offset)
            while (values.length() < 1000) {
                val start = reader.filePointer
                val line = reader.readLine() ?: break
                val end = reader.filePointer
                reader.seek(end - 1)
                val complete = reader.read() == 10
                reader.seek(end)
                if (!complete) { offset = start; break }
                offset = end
                val value = try { JSONObject(line) } catch (_: Exception) { null }
                if (value != null && value.optLong("sequence", -1) > after) values.put(value)
            }
        }
        delivered = if (values.length() == 0) after else values.getJSONObject(values.length() - 1).getLong("sequence")
        return values.toString()
    }

    companion object {
        /** Repair only an incomplete tail after process loss and avoid reusing its sequence IDs. */
        fun reconcile(file: File, checkpoint: Long): Long {
            if (!file.exists() || file.length() == 0L) return checkpoint
            return RandomAccessFile(file, "rw").use { journal ->
                val start = (journal.length() - 65536).coerceAtLeast(0)
                journal.seek(start)
                val bytes = ByteArray((journal.length() - start).toInt()); journal.readFully(bytes)
                val end = bytes.indexOfLast { it == 10.toByte() }
                if (end < 0) { journal.setLength(start); return@use checkpoint }
                journal.setLength(start + end + 1)
                String(bytes, 0, end + 1, Charsets.UTF_8).lineSequence().fold(checkpoint) { seq, line ->
                    maxOf(seq, try { JSONObject(line).optLong("sequence", -1) } catch (_: Exception) { -1L })
                }
            }
        }
    }
}
