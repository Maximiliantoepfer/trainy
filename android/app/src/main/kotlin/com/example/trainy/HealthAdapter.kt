package com.example.trainy

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.contracts.ExerciseRouteRequestContract
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.*
import androidx.health.connect.client.records.metadata.DataOrigin
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.records.metadata.Device
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.health.connect.client.units.Length
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.launch
import java.time.Instant

/** Post-workout access only. No background health reads, calories, steps or live sensors. */
class HealthAdapter(private val activity: MainActivity) : HealthHostApi {
    private val client get() = HealthConnectClient.getOrCreate(activity)
    private val own get() = activity.packageName
    private var permissionReply: ((Result<HealthAccess>) -> Unit)? = null
    private var routeReply: ((Result<HealthRoute>) -> Unit)? = null
    private val permissions = activity.registerForActivityResult(
        PermissionController.createRequestPermissionResultContract()
    ) { _ ->
        val reply = permissionReply; permissionReply = null
        if (reply != null) run(reply) { status() }
    }
    private val routes = activity.registerForActivityResult(ExerciseRouteRequestContract()) { route ->
        val reply = routeReply; routeReply = null
        reply?.invoke(Result.success(route?.let { convertRoute(it) } ?: HealthRoute("denied", emptyList())))
    }
    private fun <T> run(reply: (Result<T>) -> Unit, action: suspend () -> T) {
        activity.lifecycleScope.launch { reply(runCatching { action() }) }
    }
    private val readWorkout = HealthPermission.getReadPermission(ExerciseSessionRecord::class)
    private val writeWorkout = HealthPermission.getWritePermission(ExerciseSessionRecord::class)
    private val readDistance = HealthPermission.getReadPermission(DistanceRecord::class)
    private val readHeart = HealthPermission.getReadPermission(HeartRateRecord::class)
    private suspend fun status(): HealthAccess {
        if (HealthConnectClient.getSdkStatus(activity) != HealthConnectClient.SDK_AVAILABLE)
            return HealthAccess(false, "unavailable", false, own)
        val granted = client.permissionController.getGrantedPermissions()
        return HealthAccess(true, when {
            readWorkout !in granted -> "denied"
            readDistance !in granted || readHeart !in granted -> "limited"
            else -> "granted"
        }, writeWorkout in granted, own)
    }
    override fun access(request: Boolean, write: Boolean, heartRate: Boolean, route: Boolean,
                        callback: (Result<HealthAccess>) -> Unit) {
      activity.lifecycleScope.launch {
       try {
        val current = status()
        if (!current.available || !request) { callback(Result.success(current)); return@launch }
        val needed = mutableSetOf(readWorkout, readDistance)
        if (heartRate) needed += readHeart
        if (write) {
            needed += writeWorkout
            needed += HealthPermission.getWritePermission(DistanceRecord::class)
        }
        if (route && write) needed += HealthPermission.PERMISSION_WRITE_EXERCISE_ROUTE
        if (client.permissionController.getGrantedPermissions().containsAll(needed)) {
            callback(Result.success(current)); return@launch
        }
        check(permissionReply == null) { "health_request_pending" }
        permissionReply = callback
        permissions.launch(needed)
       } catch (error: Exception) { permissionReply = null; callback(Result.failure(error)) }
      }
    }

    private suspend inline fun <reified T : Record> records(start: Instant, end: Instant,
                                                          source: String? = null): List<T> {
        val all = mutableListOf<T>()
        var token: String? = null
        do {
            val page = client.readRecords(ReadRecordsRequest(T::class,
                TimeRangeFilter.between(start, end),
                dataOriginFilter = source?.let { setOf(DataOrigin(it)) } ?: emptySet(),
                pageToken = token))
            all += page.records; token = page.pageToken
        } while (token != null)
        return all
    }
    override fun workouts(start: Long, end: Long, callback: (Result<List<HealthWorkout>>) -> Unit) = run(callback) {
        val granted = client.permissionController.getGrantedPermissions()
        check(readWorkout in granted) { "health_read_denied" }
        val sessions = records<ExerciseSessionRecord>(Instant.ofEpochMilli(start), Instant.ofEpochMilli(end))
        sessions.mapNotNull { session ->
            val sport = sport(session.exerciseType) ?: return@mapNotNull null
            val origin = session.metadata.dataOrigin.packageName
            val ambiguous = sessions.any { it.metadata.id != session.metadata.id &&
                it.metadata.dataOrigin == session.metadata.dataOrigin &&
                it.startTime < session.endTime && it.endTime > session.startTime }
            // Only fully contained records from this origin/device can belong to this workout.
            val distance = if (readDistance in granted && !ambiguous) runCatching {
                val samples = records<DistanceRecord>(session.startTime, session.endTime, origin)
                    .filter { it.startTime >= session.startTime && it.endTime <= session.endTime && it.metadata.device == session.metadata.device }
                    .sortedBy { it.startTime }
                if (samples.isEmpty() || samples.zipWithNext().any { (a,b) -> a.endTime > b.startTime }) null
                else samples.sumOf { it.distance.inMeters }.takeIf { it > 0 && it.isFinite() }
            }.getOrNull() else null
            val pulse = if (readHeart in granted && !ambiguous) runCatching {
                records<HeartRateRecord>(session.startTime, session.endTime, origin)
                    .filter { it.metadata.device == session.metadata.device }
                    .flatMap { it.samples }.filter { it.time >= session.startTime && it.time <= session.endTime }
                    .distinctBy { it.time }.map { it.beatsPerMinute }.takeIf { it.isNotEmpty() }?.average()
            }.getOrNull() else null
            HealthWorkout(session.metadata.id, origin, session.title ?: sport, sport,
                session.startTime.toEpochMilli(), session.endTime.toEpochMilli(),
                session.exerciseType in setOf(ExerciseSessionRecord.EXERCISE_TYPE_RUNNING_TREADMILL,
                    ExerciseSessionRecord.EXERCISE_TYPE_BIKING_STATIONARY), distance, null, pulse,
                session.metadata.device?.let { "${it.manufacturer ?: ""}/${it.model ?: ""}/${it.type}" }, session.metadata.clientRecordId)
        }
    }
    private fun convertRoute(route: ExerciseRoute) = HealthRoute("available", route.route.map {
        HealthRoutePoint(it.time.toEpochMilli(), it.latitude, it.longitude,
            it.horizontalAccuracy?.inMeters, it.altitude?.inMeters)
    })
    override fun openSettings(callback: (Result<Unit>) -> Unit) {
        callback(runCatching {
            val intent = android.content.Intent(HealthConnectClient.ACTION_HEALTH_CONNECT_SETTINGS)
            activity.startActivity(intent)
        })
    }
    override fun route(workoutId: String, allowPrompt: Boolean, callback: (Result<HealthRoute>) -> Unit) {
        activity.lifecycleScope.launch {
            try {
                val record = client.readRecord(ExerciseSessionRecord::class, workoutId).record
                when (val result = record.exerciseRouteResult) {
                    is ExerciseRouteResult.Data -> callback(Result.success(convertRoute(result.exerciseRoute)))
                    is ExerciseRouteResult.ConsentRequired -> {
                        if (!allowPrompt) {
                            callback(Result.success(HealthRoute("consentRequired", emptyList())))
                            return@launch
                        }
                        check(routeReply == null) { "route_request_pending" }
                        routeReply = callback; routes.launch(workoutId)
                    }
                    else -> callback(Result.success(HealthRoute("noData", emptyList())))
                }
            } catch (error: Exception) { callback(Result.failure(error)) }
        }
    }
    override fun saveWorkout(workout: HealthWorkout, callback: (Result<String>) -> Unit) = run(callback) {
        require(!workout.clientId.isNullOrBlank() && workout.end > workout.start)
        val start = Instant.ofEpochMilli(workout.start); val end = Instant.ofEpochMilli(workout.end)
        val type = type(workout.sport, workout.indoor)
        val prior = records<ExerciseSessionRecord>(start, end, own).filter {
            it.metadata.clientRecordId == workout.clientId ||
                (it.startTime == start && it.endTime == end && it.exerciseType == type)
        }
        require(prior.size <= 1) { "ambiguous_legacy_export" }
        // Never rewrite an existing workout: doing so without its route would delete its route.
        val id = prior.singleOrNull()?.metadata?.id ?: client.insertRecords(listOf(
            ExerciseSessionRecord(startTime = start, startZoneOffset = null, endTime = end, endZoneOffset = null,
                exerciseType = type, metadata = Metadata.activelyRecorded(
                    device = Device(type = Device.TYPE_PHONE), clientRecordId = workout.clientId), title = workout.name)
        )).recordIdsList.single()
        val distance = workout.distance
        if (distance != null && distance.isFinite() && distance > 0) {
            // Deterministic key makes a partial workout/distance export retry idempotent.
            val existing = records<DistanceRecord>(start, end, own).any { it.startTime == start && it.endTime == end }
            if (!existing) client.insertRecords(listOf(DistanceRecord(startTime = start, startZoneOffset = null,
                endTime = end, endZoneOffset = null, distance = Length.meters(distance),
                metadata = Metadata.activelyRecorded(device = Device(type = Device.TYPE_PHONE), clientRecordId = "${workout.clientId}:distance"))))
        }
        id
    }
    override fun saveRoute(workoutId: String, points: List<HealthRoutePoint>, callback: (Result<Unit>) -> Unit) = run(callback) {
        val session = client.readRecord(ExerciseSessionRecord::class, workoutId).record
        check(session.metadata.dataOrigin.packageName == own) { "not_own_workout" }
        val route = ExerciseRoute(points.distinctBy { it.timestamp }.sortedBy { it.timestamp }.map {
            require(it.timestamp >= session.startTime.toEpochMilli() && it.timestamp <= session.endTime.toEpochMilli())
            ExerciseRoute.Location(Instant.ofEpochMilli(it.timestamp), it.latitude, it.longitude,
                it.accuracy?.let(Length::meters), altitude = it.altitude?.let(Length::meters))
        })
        client.updateRecords(listOf(ExerciseSessionRecord(startTime = session.startTime, startZoneOffset = session.startZoneOffset,
            endTime = session.endTime, endZoneOffset = session.endZoneOffset, exerciseType = session.exerciseType, metadata = session.metadata,
            title = session.title, notes = session.notes, segments = session.segments,
            laps = session.laps, exerciseRoute = route)))
    }
    private fun sport(type: Int): String? = when (type) {
        ExerciseSessionRecord.EXERCISE_TYPE_RUNNING, ExerciseSessionRecord.EXERCISE_TYPE_RUNNING_TREADMILL -> "running"
        ExerciseSessionRecord.EXERCISE_TYPE_WALKING -> "walking"
        ExerciseSessionRecord.EXERCISE_TYPE_BIKING, ExerciseSessionRecord.EXERCISE_TYPE_BIKING_STATIONARY -> "cycling"
        ExerciseSessionRecord.EXERCISE_TYPE_STAIR_CLIMBING, ExerciseSessionRecord.EXERCISE_TYPE_STAIR_CLIMBING_MACHINE -> "stepper"
        ExerciseSessionRecord.EXERCISE_TYPE_ELLIPTICAL -> "elliptical"
        ExerciseSessionRecord.EXERCISE_TYPE_ROWING, ExerciseSessionRecord.EXERCISE_TYPE_ROWING_MACHINE -> "rowing"
        else -> null
    }
    private fun type(sport: String, indoor: Boolean): Int = when (sport) {
        "running" -> if (indoor) ExerciseSessionRecord.EXERCISE_TYPE_RUNNING_TREADMILL else ExerciseSessionRecord.EXERCISE_TYPE_RUNNING
        "walking" -> ExerciseSessionRecord.EXERCISE_TYPE_WALKING
        "cycling" -> if (indoor) ExerciseSessionRecord.EXERCISE_TYPE_BIKING_STATIONARY else ExerciseSessionRecord.EXERCISE_TYPE_BIKING
        "stepper" -> ExerciseSessionRecord.EXERCISE_TYPE_STAIR_CLIMBING_MACHINE
        "elliptical" -> ExerciseSessionRecord.EXERCISE_TYPE_ELLIPTICAL
        "rowing" -> ExerciseSessionRecord.EXERCISE_TYPE_ROWING_MACHINE
        else -> error("unsupported_sport")
    }
}
