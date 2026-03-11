typedef SyncBenchmark = void Function();
typedef AsyncBenchmark = Future<void> Function();

int measureBestSyncMillis(
  SyncBenchmark action, {
  int warmupRuns = 1,
  int samples = 3,
}) {
  for (var i = 0; i < warmupRuns; i++) {
    action();
  }

  var best = 1 << 30;
  for (var i = 0; i < samples; i++) {
    final stopwatch = Stopwatch()..start();
    action();
    stopwatch.stop();
    best = best < stopwatch.elapsedMilliseconds
        ? best
        : stopwatch.elapsedMilliseconds;
  }

  return best;
}

Future<int> measureBestAsyncMillis(
  AsyncBenchmark action, {
  int warmupRuns = 1,
  int samples = 3,
}) async {
  for (var i = 0; i < warmupRuns; i++) {
    await action();
  }

  var best = 1 << 30;
  for (var i = 0; i < samples; i++) {
    final stopwatch = Stopwatch()..start();
    await action();
    stopwatch.stop();
    best = best < stopwatch.elapsedMilliseconds
        ? best
        : stopwatch.elapsedMilliseconds;
  }

  return best;
}
