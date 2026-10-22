package org.maplibre.maplibregl;

import java.util.ArrayList;
import java.util.List;

/** Dependency-free regression harness: run with javac/java (see ../README.md). */
public final class SnapshotCaptureQueueTest {
  public static void main(String[] args) {
    replacementDoesNotOverwriteAnActiveSdkCallback();
    cancelledPendingCaptureNeverStarts();
    completionAllowsAnotherCapture();
    aRecreatedRendererHasAnIndependentCaptureGate();
    System.out.println("SnapshotCaptureQueue: 4 regression tests passed.");
  }

  private static void replacementDoesNotOverwriteAnActiveSdkCallback() {
    SnapshotCaptureQueue queue = new SnapshotCaptureQueue();
    List<String> captures = new ArrayList<>();
    queue.replace(() -> captures.add("A"));
    queue.replace(() -> captures.add("B"));
    queue.replace(() -> captures.add("C"));
    check(captures.equals(List.of("A")), "B/C must not replace A's SDK callback");
    queue.complete();
    check(captures.equals(List.of("A", "C")), "Only the latest queued capture must start");
  }

  private static void cancelledPendingCaptureNeverStarts() {
    SnapshotCaptureQueue queue = new SnapshotCaptureQueue();
    List<String> captures = new ArrayList<>();
    queue.replace(() -> captures.add("A"));
    queue.replace(() -> captures.add("B"));
    queue.cancelPending();
    queue.complete();
    check(captures.equals(List.of("A")), "A timeout/disposal must discard queued B");
  }

  private static void completionAllowsAnotherCapture() {
    SnapshotCaptureQueue queue = new SnapshotCaptureQueue();
    List<String> captures = new ArrayList<>();
    queue.replace(() -> captures.add("A"));
    queue.cancelPending();
    queue.replace(() -> captures.add("B"));
    check(captures.equals(List.of("A")), "Retry must wait for A's late SDK completion");
    queue.complete();
    queue.complete();
    queue.replace(() -> captures.add("C"));
    check(captures.equals(List.of("A", "B", "C")), "Capture must resume after completion");
  }

  private static void check(boolean condition, String message) {
    if (!condition) throw new AssertionError(message);
  }

  private static void aRecreatedRendererHasAnIndependentCaptureGate() {
    SnapshotCaptureQueue oldRenderer = new SnapshotCaptureQueue();
    List<String> captures = new ArrayList<>();
    oldRenderer.replace(() -> captures.add("old"));
    oldRenderer.cancelPending();
    SnapshotCaptureQueue newRenderer = new SnapshotCaptureQueue();
    newRenderer.replace(() -> captures.add("new"));
    newRenderer.replace(() -> captures.add("next"));
    oldRenderer.complete();
    check(captures.equals(List.of("old", "new")), "Old completion must not release the new capture");
    newRenderer.complete();
    check(captures.equals(List.of("old", "new", "next")), "New renderer must progress independently");
  }
}
