import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart' hide Error;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'off-screen inline-style snapshots include runtime lines and images',
    (tester) async {
      final created = Completer<MapLibreMapController>();
      final styled = Completer<void>();
      Completer<void>? idle;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  left: -600,
                  top: 0,
                  width: 584,
                  height: 291,
                  child: MapLibreMap(
                    styleString:
                        '{"version":8,"sources":{},"layers":[{"id":"background","type":"background","paint":{"background-color":"#ffffff"}}]}',
                    initialCameraPosition: const CameraPosition(
                      target: LatLng(0, 0),
                      zoom: 3,
                    ),
                    onMapCreated: created.complete,
                    onStyleLoadedCallback: () {
                      if (!styled.isCompleted) styled.complete();
                    },
                    onMapIdle: () {
                      if (idle != null && !idle!.isCompleted) idle!.complete();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      final controller = await _withFrames(tester, created.future);
      await _withFrames(tester, styled.future);

      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 24, 24),
        Paint()..color = const Color(0xff00ff00),
      );
      final picture = recorder.endRecording();
      final marker = await picture.toImage(24, 24);
      final markerBytes = await marker.toByteData(
        format: ui.ImageByteFormat.png,
      );
      await controller.addImage(
        'snapshot-marker',
        markerBytes!.buffer.asUint8List(),
      );
      marker.dispose();
      picture.dispose();

      idle = Completer<void>();
      await controller.addLine(
        const LineOptions(
          geometry: [LatLng(0, -5), LatLng(0, 5)],
          lineColor: '#ff0000',
          lineWidth: 12,
        ),
      );
      await controller.addSymbol(
        const SymbolOptions(
          geometry: LatLng(5, 0),
          iconImage: 'snapshot-marker',
        ),
      );
      await _withFrames(tester, idle!.future);
      final png = await _withFrames(tester, controller.takeSnapshot());
      final codec = await ui.instantiateImageCodec(png);
      final image = (await codec.getNextFrame()).image;
      final pixels =
          (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
      var red = 0;
      var green = 0;
      for (var i = 0; i < pixels.length; i += 4) {
        if (pixels[i] > 200 && pixels[i + 1] < 40 && pixels[i + 2] < 40) red++;
        if (pixels[i] < 40 && pixels[i + 1] > 200 && pixels[i + 2] < 40)
          green++;
      }
      expect(image.width / image.height, closeTo(584 / 291, .01));
      expect(
        red,
        greaterThan(100),
        reason: 'Snapshot must include the runtime route line',
      );
      expect(
        green,
        greaterThan(100),
        reason: 'Snapshot must include the custom marker image',
      );
      image.dispose();
      codec.dispose();
      await _withFrames(
        tester,
        expectLater(
          controller.takeSnapshot(width: 0, height: 0),
          throwsA(
            isA<PlatformException>().having(
              (e) => e.code,
              'code',
              'INVALID_SIZE',
            ),
          ),
        ),
      );

      // The native renderer may finish before disposal wins. Either result must
      // settle promptly; a missing callback must not leave the Dart future open.
      Object? disposalError;
      final removing = controller.takeSnapshot().then<void>(
        (_) {},
        onError: (Object error, StackTrace stack) {
          disposalError = error;
        },
      );
      await tester.pumpWidget(const SizedBox());
      await _withFrames(tester, removing, timeout: const Duration(seconds: 2));
      if (disposalError != null) {
        expect(
          disposalError,
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'SNAPSHOT_CANCELLED',
          ),
        );
      }
    },
  );
}

Future<T> _withFrames<T>(
  WidgetTester tester,
  Future<T> future, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  var done = false;
  T? value;
  Object? error;
  StackTrace? stack;
  unawaited(
    future.then(
      (result) {
        value = result;
        done = true;
      },
      onError: (Object e, StackTrace s) {
        error = e;
        stack = s;
        done = true;
      },
    ),
  );
  final deadline = DateTime.now().add(timeout);
  while (!done) {
    if (DateTime.now().isAfter(deadline))
      fail('Native map operation timed out');
    await tester.pump(const Duration(milliseconds: 100));
  }
  if (error != null) Error.throwWithStackTrace(error!, stack!);
  return value as T;
}
