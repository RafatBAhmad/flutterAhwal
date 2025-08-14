import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/checkpoint.dart';

class CheckpointHistoryEntry {
  final String id;
  final String name;
  final String status;
  final DateTime timestamp;
  final String? source;

  CheckpointHistoryEntry({
    required this.id,
    required this.name,
    required this.status,
    required this.timestamp,
    this.source,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'status': status,
      'timestamp': timestamp.toIso8601String(),
      'source': source,
    };
  }

  factory CheckpointHistoryEntry.fromJson(Map<String, dynamic> json) {
    return CheckpointHistoryEntry(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      status: json['status'] ?? '',
      timestamp: DateTime.parse(json['timestamp']),
      source: json['source'],
    );
  }
}

class CheckpointHistoryService {
  static const String _historyKey = 'checkpoint_history';
  static const int _maxHistoryEntries = 1000; // Keep last 1000 entries

  /// Record a checkpoint status change
  static Future<void> recordStatusChange(Checkpoint checkpoint) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList(_historyKey) ?? [];
      
      final entry = CheckpointHistoryEntry(
        id: checkpoint.id,
        name: checkpoint.name,
        status: checkpoint.status,
        timestamp: checkpoint.updatedAtDateTime ?? DateTime.now(),
        source: checkpoint.sourceText,
      );

      // Convert to JSON string
      historyJson.add(jsonEncode(entry.toJson()));
      
      // Keep only recent entries to prevent storage bloat
      if (historyJson.length > _maxHistoryEntries) {
        historyJson.removeRange(0, historyJson.length - _maxHistoryEntries);
      }
      
      await prefs.setStringList(_historyKey, historyJson);
      debugPrint('✅ Recorded status change for ${checkpoint.name}: ${checkpoint.status}');
    } catch (e) {
      debugPrint('❌ Error recording status change: $e');
    }
  }

  /// Get history for a specific checkpoint (last 48 hours only)
  static Future<List<CheckpointHistoryEntry>> getCheckpointHistory(String checkpointId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList(_historyKey) ?? [];
      
      final List<CheckpointHistoryEntry> entries = [];
      final now = DateTime.now();
      final cutoffTime = now.subtract(const Duration(hours: 48));
      
      for (final entryJson in historyJson) {
        try {
          final data = jsonDecode(entryJson);
          final entry = CheckpointHistoryEntry.fromJson(data);
          
          if (entry.id == checkpointId && entry.timestamp.isAfter(cutoffTime)) {
            entries.add(entry);
          }
        } catch (e) {
          debugPrint('❌ Error parsing history entry: $e');
        }
      }
      
      // Sort by timestamp (newest first)
      entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      return entries;
    } catch (e) {
      debugPrint('❌ Error getting checkpoint history: $e');
      return [];
    }
  }

  /// Get recent history for all checkpoints
  static Future<List<CheckpointHistoryEntry>> getRecentHistory({int limit = 50}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList(_historyKey) ?? [];
      
      final List<CheckpointHistoryEntry> entries = [];
      
      // Process in reverse order to get most recent first
      for (int i = historyJson.length - 1; i >= 0 && entries.length < limit; i--) {
        try {
          final data = jsonDecode(historyJson[i]);
          final entry = CheckpointHistoryEntry.fromJson(data);
          entries.add(entry);
        } catch (e) {
          debugPrint('❌ Error parsing history entry: $e');
        }
      }
      
      return entries;
    } catch (e) {
      debugPrint('❌ Error getting recent history: $e');
      return [];
    }
  }

  /// Record multiple checkpoints (batch operation)
  static Future<void> recordMultipleCheckpoints(List<Checkpoint> checkpoints) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList(_historyKey) ?? [];
      
      // Get existing entries to avoid duplicates
      final existingEntries = <String, String>{};
      for (final entryJson in historyJson) {
        try {
          final data = jsonDecode(entryJson);
          final entry = CheckpointHistoryEntry.fromJson(data);
          final key = '${entry.id}_${entry.timestamp.toIso8601String()}';
          existingEntries[key] = entryJson;
        } catch (e) {
          // Skip invalid entries
        }
      }
      
      int newEntriesAdded = 0;
      for (final checkpoint in checkpoints) {
        final timestamp = checkpoint.effectiveAtDateTime ?? checkpoint.updatedAtDateTime ?? DateTime.now();
        final key = '${checkpoint.id}_${timestamp.toIso8601String()}';
        
        // Only add if not already exists
        if (!existingEntries.containsKey(key)) {
          final entry = CheckpointHistoryEntry(
            id: checkpoint.id,
            name: checkpoint.name,
            status: checkpoint.status,
            timestamp: timestamp,
            source: checkpoint.sourceText,
          );

          historyJson.add(jsonEncode(entry.toJson()));
          newEntriesAdded++;
        }
      }
      
      // Keep only recent entries to prevent storage bloat
      if (historyJson.length > _maxHistoryEntries) {
        historyJson.removeRange(0, historyJson.length - _maxHistoryEntries);
      }
      
      await prefs.setStringList(_historyKey, historyJson);
      if (newEntriesAdded > 0) {
        debugPrint('✅ Recorded $newEntriesAdded new checkpoint entries out of ${checkpoints.length} total');
      }
    } catch (e) {
      debugPrint('❌ Error recording multiple checkpoints: $e');
    }
  }

  /// Clear all history (for testing/debugging)
  static Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
      debugPrint('🗑️ Checkpoint history cleared');
    } catch (e) {
      debugPrint('❌ Error clearing history: $e');
    }
  }

  /// Get history statistics
  static Future<Map<String, dynamic>> getHistoryStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList(_historyKey) ?? [];
      
      final Map<String, int> statusCounts = {};
      final Map<String, int> checkpointCounts = {};
      DateTime? oldestEntry;
      DateTime? newestEntry;
      
      for (final entryJson in historyJson) {
        try {
          final data = jsonDecode(entryJson);
          final entry = CheckpointHistoryEntry.fromJson(data);
          
          // Count statuses
          statusCounts[entry.status] = (statusCounts[entry.status] ?? 0) + 1;
          
          // Count checkpoints
          checkpointCounts[entry.id] = (checkpointCounts[entry.id] ?? 0) + 1;
          
          // Track date range
          if (oldestEntry == null || entry.timestamp.isBefore(oldestEntry)) {
            oldestEntry = entry.timestamp;
          }
          if (newestEntry == null || entry.timestamp.isAfter(newestEntry)) {
            newestEntry = entry.timestamp;
          }
        } catch (e) {
          debugPrint('❌ Error parsing history entry for stats: $e');
        }
      }
      
      return {
        'totalEntries': historyJson.length,
        'uniqueCheckpoints': checkpointCounts.length,
        'statusCounts': statusCounts,
        'oldestEntry': oldestEntry?.toIso8601String(),
        'newestEntry': newestEntry?.toIso8601String(),
        'mostActiveCheckpoint': checkpointCounts.entries
            .fold<MapEntry<String, int>?>(null, (max, entry) =>
                max == null || entry.value > max.value ? entry : max)?.key,
      };
    } catch (e) {
      debugPrint('❌ Error getting history stats: $e');
      return {};
    }
  }

  /// Format timestamp for display
  static String formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'الآن';
    } else if (difference.inMinutes < 60) {
      return 'منذ ${difference.inMinutes} دقيقة';
    } else if (difference.inHours < 24) {
      return 'منذ ${difference.inHours} ساعة';
    } else if (difference.inDays == 1) {
      return 'أمس ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} أيام';
    } else {
      final day = timestamp.day.toString().padLeft(2, '0');
      final month = timestamp.month.toString().padLeft(2, '0');
      final year = timestamp.year;
      final hour = timestamp.hour.toString().padLeft(2, '0');
      final minute = timestamp.minute.toString().padLeft(2, '0');
      return '$day/$month/$year $hour:$minute';
    }
  }
}