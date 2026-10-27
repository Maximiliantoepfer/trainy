import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:url_launcher/url_launcher.dart';
import '../l10n/refinement_l10n.dart';
import '../l10n/plan_l10n.dart';
import '../models/cardio_route.dart';
import '../l10n/cardio_l10n.dart';

class CardioRouteView extends StatefulWidget {
  const CardioRouteView({
    super.key,
    required this.samples,
    this.thumbnail = false,
    this.tileProviderFactory,
  });
  final List<Map<String, dynamic>> samples;
  final bool thumbnail;
  final TileProvider Function()? tileProviderFactory;
  @override
  State<CardioRouteView> createState() => _CardioRouteState();
}

class _CardioRouteState extends State<CardioRouteView> {
  bool _map = false;
  bool _loading = true, _failed = false;
  int _attempt = 0;
  TileProvider? _provider;
  TileProvider _tiles() =>
      _provider ??=
          widget.tileProviderFactory?.call() ??
          NetworkTileProvider(
            headers: {
              'User-Agent':
                  'Trainy/1.0 (+https://github.com/Maximiliantoepfer/trainy)',
            },
            cachingProvider: BuiltInMapCachingProvider.getOrCreateInstance(
              maxCacheSize: 64 * 1024 * 1024,
            ),
          );
  void _loaded({bool failed = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && (_loading || (failed && !_failed))) {
        setState(() {
          _loading = false;
          _failed |= failed;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final segments = routeSegments(widget.samples),
        points = segments.expand((s) => s).toList();
    if (points.length < 2) {
      return widget.thumbnail
          ? const SizedBox.shrink()
          : Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(context.refine('noRoute')),
          );
    }
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: ColoredBox(
            color: scheme.surfaceContainerHighest,
            child: SizedBox(
              height: widget.thumbnail ? 100 : 240,
              child: CustomPaint(
                painter: RouteTracePainter(segments, scheme.primary),
              ),
            ),
          ),
        ),
        if (!widget.thumbnail) ...[
          const SizedBox(height: 8),
          if (!_map)
            TextButton.icon(
              icon: const Icon(Icons.map_outlined),
              label: Text(context.refine('streetMap')),
              onPressed: () async {
                final accepted = await showDialog<bool>(
                  context: context,
                  builder:
                      (c) => AlertDialog(
                        title: Text(c.refine('streetMap')),
                        content: Text(c.refine('mapPrivacy')),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: Text(c.plan('cancel')),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: Text(c.refine('streetMap')),
                          ),
                        ],
                      ),
                );
                if (accepted == true && mounted) setState(() => _map = true);
              },
            ),
          // No map, tile provider, cache or network request exists before consent.
          if (_map)
            SizedBox(
              height: 300,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: FlutterMap(
                  key: ValueKey(_attempt),
                  options: MapOptions(
                    initialCameraFit: CameraFit.bounds(
                      bounds: LatLngBounds.fromPoints(
                        points
                            .map((p) => LatLng(p.latitude, p.longitude))
                            .toList(),
                      ),
                      padding: const EdgeInsets.all(32),
                      maxZoom: 17,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.trainy',
                      panBuffer: 0,
                      tileProvider: _tiles(),
                      errorTileCallback: (_, _, _) => _loaded(failed: true),
                      tileBuilder: (_, tile, image) {
                        if (image.loadFinishedAt != null) {
                          _loaded(failed: image.loadError);
                        }
                        return tile;
                      },
                    ),
                    PolylineLayer(
                      polylines: [
                        for (final s in segments.where((s) => s.length > 1))
                          Polyline(
                            points:
                                s
                                    .map((p) => LatLng(p.latitude, p.longitude))
                                    .toList(),
                            color: scheme.primary,
                            strokeWidth: 4,
                          ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        for (final p in [points.first, points.last])
                          Marker(
                            point: LatLng(p.latitude, p.longitude),
                            width: 20,
                            height: 20,
                            child: Icon(
                              p == points.first ? Icons.circle : Icons.flag,
                              color: scheme.primary,
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: ColoredBox(
                        color: scheme.surface,
                        child: TextButton(
                          onPressed:
                              () => launchUrl(
                                Uri.parse(
                                  'https://www.openstreetmap.org/copyright',
                                ),
                              ),
                          child: const Text(
                            '© OpenStreetMap contributors',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_map && _loading) const LinearProgressIndicator(),
          if (_map && _failed)
            Row(
              children: [
                Expanded(child: Text(context.recording('mapFailed'))),
                TextButton.icon(
                  onPressed:
                      () => setState(() {
                        _attempt++;
                        _provider = null;
                        _loading = true;
                        _failed = false;
                      }),
                  icon: const Icon(Icons.refresh),
                  label: Text(context.recording('retry')),
                ),
              ],
            ),
        ],
      ],
    );
  }
}

class RouteTracePainter extends CustomPainter {
  const RouteTracePainter(this.segments, this.color);
  final List<List<RoutePoint>> segments;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final points = segments.expand((s) => s).toList();
    if (points.length < 2) return;
    final first = points.first;
    final coords =
        points.map((p) => Offset(routeX(p, first), -p.latitude)).toList();
    final left = coords.map((p) => p.dx).reduce(math.min),
        right = coords.map((p) => p.dx).reduce(math.max),
        top = coords.map((p) => p.dy).reduce(math.min),
        bottom = coords.map((p) => p.dy).reduce(math.max);
    final scale = math.min(
      (size.width - 32) / math.max(.000001, right - left),
      (size.height - 32) / math.max(.000001, bottom - top),
    );
    Offset project(RoutePoint p) => Offset(
      size.width / 2 + (routeX(p, first) - (left + right) / 2) * scale,
      size.height / 2 + (-p.latitude - (top + bottom) / 2) * scale,
    );
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
    for (final segment in segments) {
      final path = Path();
      for (var i = 0; i < segment.length; i++) {
        final point = project(segment[i]);
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(path, paint);
    }
    canvas.drawCircle(project(first), 5, Paint()..color = color);
    canvas.drawCircle(project(points.last), 7, paint);
  }

  @override
  bool shouldRepaint(covariant RouteTracePainter old) =>
      old.segments != segments || old.color != color;
}
