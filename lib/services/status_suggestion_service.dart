import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/checkpoint.dart';
import 'api_service.dart';

class StatusSuggestionService {
  static const String _suggestionsPrefix = 'status_suggestions_';
  
  // Available status options
  static const List<String> availableStatuses = [
    'سالك',
    'مغلق',
    'ازدحام',
    'فحص دقيق',
    'فحص عادي',
  ];
  
  /// Submit a status suggestion for a checkpoint
  static Future<void> submitStatusSuggestion(
    String checkpointId, 
    String checkpointName,
    String suggestedStatus,
    String userDeviceId,
  ) async {
    try {
      // Try to submit to backend first
      await ApiService.submitStatusSuggestion(
        checkpointId: checkpointId,
        checkpointName: checkpointName,
        suggestedStatus: suggestedStatus,
        userDeviceId: userDeviceId,
      );
    } catch (e) {
      // Fallback to local storage if backend fails
      print('⚠️ الخدمة غير متاحة، استخدام التخزين المحلي: $e');
      final prefs = await SharedPreferences.getInstance();
      final key = '$_suggestionsPrefix$checkpointId';
      
      // Get existing suggestions
      final existingSuggestions = prefs.getStringList(key) ?? [];
      
      // Create vote entry format: "status|userDeviceId|timestamp"
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final voteEntry = '$suggestedStatus|$userDeviceId|$timestamp';
      
      // Add the new suggestion if user hasn't already voted
      final userAlreadyVoted = existingSuggestions.any(
        (suggestion) => suggestion.split('|')[1] == userDeviceId,
      );
      
      if (!userAlreadyVoted) {
        existingSuggestions.add(voteEntry);
        await prefs.setStringList(key, existingSuggestions);
      }
    }
  }
  
  /// Get status suggestions for a checkpoint
  static Future<Map<String, int>> getStatusSuggestions(String checkpointId) async {
    try {
      // Try to get from backend first
      return await ApiService.getStatusVotes(checkpointId);
    } catch (e) {
      // Fallback to local storage
      print('⚠️ الخدمة غير متاحة، استخدام التخزين المحلي: $e');
      final prefs = await SharedPreferences.getInstance();
      final key = '$_suggestionsPrefix$checkpointId';
      
      final suggestions = prefs.getStringList(key) ?? [];
      final Map<String, int> statusVotes = {};
      
      for (final suggestion in suggestions) {
        final parts = suggestion.split('|');
        if (parts.length >= 3) {
          final status = parts[0];
          statusVotes[status] = (statusVotes[status] ?? 0) + 1;
        }
      }
      
      return statusVotes;
    }
  }
  
  /// Get the most voted status for a checkpoint
  static Future<String?> getMostVotedStatus(String checkpointId) async {
    final votes = await getStatusSuggestions(checkpointId);
    
    if (votes.isEmpty) return null;
    
    // Return status with most votes
    var maxVotes = 0;
    String? topStatus;
    
    votes.forEach((status, count) {
      if (count > maxVotes) {
        maxVotes = count;
        topStatus = status;
      }
    });
    
    // Only return if it has at least 3 votes
    return maxVotes >= 3 ? topStatus : null;
  }
  
  /// Check if user has already voted for this checkpoint status
  static Future<bool> hasUserVoted(String checkpointId, String userDeviceId) async {
    try {
      // Check backend first
      return await ApiService.hasUserVotedForStatus(checkpointId, userDeviceId);
    } catch (e) {
      // Fallback to local storage
      final prefs = await SharedPreferences.getInstance();
      final key = '$_suggestionsPrefix$checkpointId';
      
      final suggestions = prefs.getStringList(key) ?? [];
      
      return suggestions.any(
        (suggestion) => suggestion.split('|')[1] == userDeviceId,
      );
    }
  }
  
  /// Get total vote count for a checkpoint
  static Future<int> getTotalVotes(String checkpointId) async {
    try {
      final votes = await getStatusSuggestions(checkpointId);
      return votes.values.fold<int>(0, (sum, count) => sum + count);
    } catch (e) {
      return 0;
    }
  }
  
  /// Show status voting dialog
  static void showStatusVotingDialog(
    BuildContext context,
    Checkpoint checkpoint,
    String userDeviceId,
  ) {
    String? selectedStatus;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text(
            'اقتراح حالة الحاجز',
            textDirection: TextDirection.rtl,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'حاجز: ${checkpoint.name}',
                style: const TextStyle(fontWeight: FontWeight.bold),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 12),
              Text(
                'الحالة الحالية: ${checkpoint.status}',
                style: TextStyle(
                  color: _getStatusColor(checkpoint.status),
                  fontWeight: FontWeight.w600,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 16),
              const Text(
                'هل تعرف الحالة الصحيحة لهذا الحاجز؟ ساعدنا بتحديث المعلومات:',
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 16),
              
              // Status options
              ...availableStatuses.map((status) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      selectedStatus = status;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: selectedStatus == status 
                            ? Theme.of(context).primaryColor 
                            : Colors.grey,
                        width: selectedStatus == status ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: selectedStatus == status 
                          ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: _getStatusColor(status),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            status,
                            style: TextStyle(
                              fontWeight: selectedStatus == status 
                                  ? FontWeight.bold 
                                  : FontWeight.normal,
                              color: selectedStatus == status 
                                  ? Theme.of(context).primaryColor 
                                  : null,
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                        ),
                        if (selectedStatus == status)
                          Icon(
                            Icons.check_circle,
                            color: Theme.of(context).primaryColor,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),
              )),
              
              const SizedBox(height: 16),
              
              // Show existing suggestions
              FutureBuilder<Map<String, int>>(
                future: getStatusSuggestions(checkpoint.id),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'اقتراحات سابقة:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                        const SizedBox(height: 4),
                        ...snapshot.data!.entries.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(entry.key),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      entry.key,
                                      textDirection: TextDirection.rtl,
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${entry.value} صوت',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: selectedStatus != null ? () async {
                if (selectedStatus != null) {
                  try {
                    await submitStatusSuggestion(
                      checkpoint.id,
                      checkpoint.name,
                      selectedStatus!,
                      userDeviceId,
                    );
                    
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'تم إرسال اقتراحك بنجاح! شكراً لمساعدتنا',
                            textDirection: TextDirection.rtl,
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'خطأ في إرسال الاقتراح: ${e.toString()}',
                            textDirection: TextDirection.rtl,
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              } : null,
              child: const Text('إرسال'),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Get status color
  static Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'سالك':
      case 'سالكة':
      case 'سالكه':
      case 'مفتوح':
        return Colors.green;
      case 'مغلق':
        return Colors.red;
      case 'ازدحام':
        return Colors.orange;
      case 'فحص دقيق':
        return Colors.purple;
      case 'فحص عادي':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
  
  /// Get a unique device ID
  static Future<String> getDeviceId() async {
    return await ApiService.getOrCreateDeviceId();
  }
}