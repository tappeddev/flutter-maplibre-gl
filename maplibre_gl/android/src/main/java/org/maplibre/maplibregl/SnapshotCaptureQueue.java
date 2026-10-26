package org.maplibre.maplibregl;

/**
 * Keeps at most one SDK capture in flight. MapLibre Android holds a single
 * snapshot callback, so replacing that callback before it fires can associate
 * an old frame with a newer request. All methods run on the main thread.
 */
final class SnapshotCaptureQueue {
  private boolean active;
  private Runnable pending;

  void replace(Runnable capture) {
    pending = capture;
    startIfIdle();
  }

  void cancelPending() {
    pending = null;
  }

  void complete() {
    active = false;
    startIfIdle();
  }

  private void startIfIdle() {
    if (active || pending == null) return;
    Runnable capture = pending;
    pending = null;
    active = true;
    capture.run();
  }
}
