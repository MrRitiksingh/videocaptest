import 'package:flutter/material.dart';

/// Performance monitoring utility for tracking crop operations and identifying bottlenecks
class PerformanceMonitor {
  static final Map<String, List<int>> _operationTimes = {};
  static final Map<String, int> _operationCounts = {};
  static final Map<String, int> _slowOperationCounts = {};

  // Performance thresholds
  static const int _fpsThreshold = 16; // 60fps threshold (1000ms / 60fps)
  static const int _warningThreshold = 33; // 30fps threshold

  /// Start timing an operation
  static void startOperation(String operationName) {
    _operationTimes[operationName] = [DateTime.now().millisecondsSinceEpoch];
  }

  /// End timing an operation and record metrics
  static void endOperation(String operationName) {
    if (_operationTimes.containsKey(operationName)) {
      final startTime = _operationTimes[operationName]!.first;
      final endTime = DateTime.now().millisecondsSinceEpoch;
      final duration = endTime - startTime;

      // Track operation count
      _operationCounts[operationName] =
          (_operationCounts[operationName] ?? 0) + 1;

      // Track slow operations
      if (duration > _fpsThreshold) {
        _slowOperationCounts[operationName] =
            (_slowOperationCounts[operationName] ?? 0) + 1;
      }

      // Log performance metrics
      _logPerformance(operationName, duration);

      // Clear the start time
      _operationTimes.remove(operationName);
    }
  }

  /// Log performance information with appropriate warning levels
  static void _logPerformance(String operationName, int duration) {
    if (duration > _fpsThreshold) {
      // Critical: Below 60fps
      debugPrint(
          '🚨 Performance CRITICAL: $operationName took ${duration}ms (below 60fps threshold)');
    } else if (duration > _warningThreshold) {
      // Warning: Below 30fps
      debugPrint(
          '⚠️  Performance WARNING: $operationName took ${duration}ms (below 30fps threshold)');
    } else {
      // Good: Above 30fps
      debugPrint('✅ Performance GOOD: $operationName took ${duration}ms');
    }
  }

  /// Get performance statistics for an operation
  static Map<String, dynamic> getOperationStats(String operationName) {
    final count = _operationCounts[operationName] ?? 0;
    final slowCount = _slowOperationCounts[operationName] ?? 0;
    final slowPercentage =
        count > 0 ? (slowCount / count * 100).toStringAsFixed(1) : '0.0';

    return {
      'totalOperations': count,
      'slowOperations': slowCount,
      'slowPercentage': '$slowPercentage%',
      'performanceRating': _getPerformanceRating(slowCount, count),
    };
  }

  /// Get overall performance summary
  static Map<String, dynamic> getOverallStats() {
    final totalOps =
        _operationCounts.values.fold(0, (sum, count) => sum + count);
    final totalSlowOps =
        _slowOperationCounts.values.fold(0, (sum, count) => sum + count);
    final overallSlowPercentage = totalOps > 0
        ? (totalSlowOps / totalOps * 100).toStringAsFixed(1)
        : '0.0';

    return {
      'totalOperations': totalOps,
      'totalSlowOperations': totalSlowOps,
      'overallSlowPercentage': '$overallSlowPercentage%',
      'operations': _operationCounts.keys.toList(),
      'performanceRating': _getPerformanceRating(totalSlowOps, totalOps),
    };
  }

  /// Get performance rating based on slow operation percentage
  static String _getPerformanceRating(int slowCount, int totalCount) {
    if (totalCount == 0) return 'N/A';

    final slowPercentage = slowCount / totalCount;

    if (slowPercentage < 0.05) return 'Excellent';
    if (slowPercentage < 0.10) return 'Good';
    if (slowPercentage < 0.20) return 'Fair';
    if (slowPercentage < 0.30) return 'Poor';
    return 'Critical';
  }

  /// Clear all performance data
  static void clearStats() {
    _operationTimes.clear();
    _operationCounts.clear();
    _slowOperationCounts.clear();
  }

  /// Get cache size for debugging
  static int get cacheSize =>
      _operationTimes.length +
      _operationCounts.length +
      _slowOperationCounts.length;
}

/// Performance monitoring mixin for widgets
mixin PerformanceMonitoringMixin<T extends StatefulWidget> on State<T> {
  /// Monitor a specific operation with automatic timing
  Future<T> monitorOperation<T>(
      String operationName, Future<T> Function() operation) async {
    PerformanceMonitor.startOperation(operationName);
    try {
      final result = await operation();
      return result;
    } finally {
      PerformanceMonitor.endOperation(operationName);
    }
  }

  /// Monitor a synchronous operation
  T monitorSyncOperation<T>(String operationName, T Function() operation) {
    PerformanceMonitor.startOperation(operationName);
    try {
      final result = operation();
      return result;
    } finally {
      PerformanceMonitor.endOperation(operationName);
    }
  }

  /// Get performance stats for this widget's operations
  Map<String, dynamic> getPerformanceStats() {
    return PerformanceMonitor.getOverallStats();
  }
}
