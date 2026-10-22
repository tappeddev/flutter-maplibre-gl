# Snapshot callback serialization regression

`SnapshotCaptureQueueTest` is a dependency-free Java harness for the queue used
by the Android plugin. It deterministically holds SDK capture A in flight while
replacing/cancelling requests, proving that B cannot overwrite A's single native
callback and accidentally receive A's bitmap.

From `maplibre_gl/android`, with a JDK installed:

```sh
javac -d build/snapshot-queue-test src/main/java/org/maplibre/maplibregl/SnapshotCaptureQueue.java src/test/java/org/maplibre/maplibregl/SnapshotCaptureQueueTest.java
java -cp build/snapshot-queue-test org.maplibre.maplibregl.SnapshotCaptureQueueTest
```

The queue does not replace native pixel testing. Run the Flutter integration
fixture on Android/iOS to verify renderer output, sizing and teardown as well.
