import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphview/GraphView.dart';

import 'perf_test_utils.dart';

const itemHeight = 100.0;
const itemWidth = 100.0;
const samples = 2;

void main() {
  Graph _createGraph(int n) {
    final graph = Graph();
    final nodes = List.generate(n, (i) => Node.Id(i + 1));
    for (var i = 0; i < n - 1; i++) {
      final children = (i < n / 3) ? 3 : 2;
      for (var j = 1; j <= children && i * children + j < n; j++) {
        graph.addEdge(nodes[i], nodes[i * children + j]);
      }
    }
    for (var i = 0; i < graph.nodeCount(); i++) {
      graph.getNodeAtPosition(i).size = const Size(itemWidth, itemHeight);
    }
    return graph;
  }

  test('Algorithm performance', () {
    final algorithms = {
      'Buchheim': BuchheimWalkerAlgorithm(BuchheimWalkerConfiguration(), null),
      'Balloon': BalloonLayoutAlgorithm(BuchheimWalkerConfiguration(), null),
      'RadialTree':
          RadialTreeLayoutAlgorithm(BuchheimWalkerConfiguration(), null),
      'TidierTree':
          TidierTreeLayoutAlgorithm(BuchheimWalkerConfiguration(), null),
      'Eiglsperger': EiglspergerAlgorithm(SugiyamaConfiguration()),
      'Sugiyama': SugiyamaAlgorithm(SugiyamaConfiguration()),
      'Circle': CircleLayoutAlgorithm(CircleLayoutConfiguration(), null),
    };

    final results = <String, int>{};

    for (final entry in algorithms.entries) {
      results[entry.key] = measureBestSyncMillis(
        () => entry.value.run(_createGraph(1000), 0, 0),
        warmupRuns: 0,
        samples: samples,
      );
    }

    final sorted = results.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    print('\nPerformance Results (best of $samples runs):');
    for (var i = 0; i < sorted.length; i++) {
      print(
          '${(i + 1).toString().padLeft(2)}. ${sorted[i].key.padRight(12)}: ${sorted[i].value.toStringAsFixed(1)} ms');
    }

    for (final result in results.values) {
      expect(result < 30000, true);
    }
  });
}
