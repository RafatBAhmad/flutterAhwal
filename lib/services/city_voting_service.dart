import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/checkpoint.dart';

class CityVotingService {
  static const String _votePrefix = 'city_vote_';
  static const String _suggestionsPrefix = 'city_suggestions_';
  
  /// Submit a city suggestion for a checkpoint
  static Future<void> submitCitySuggestion(
    String checkpointId, 
    String checkpointName,
    String suggestedCity,
    String userDeviceId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_suggestionsPrefix$checkpointId';
    
    // Get existing suggestions
    final existingSuggestions = prefs.getStringList(key) ?? [];
    
    // Create vote entry format: "city|userDeviceId|timestamp"
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final voteEntry = '$suggestedCity|$userDeviceId|$timestamp';
    
    // Add the new suggestion if user hasn't already voted
    final userAlreadyVoted = existingSuggestions.any(
      (suggestion) => suggestion.split('|')[1] == userDeviceId,
    );
    
    if (!userAlreadyVoted) {
      existingSuggestions.add(voteEntry);
      await prefs.setStringList(key, existingSuggestions);
    }
  }
  
  /// Get city suggestions for a checkpoint
  static Future<Map<String, int>> getCitySuggestions(String checkpointId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_suggestionsPrefix$checkpointId';
    
    final suggestions = prefs.getStringList(key) ?? [];
    final Map<String, int> cityVotes = {};
    
    for (final suggestion in suggestions) {
      final parts = suggestion.split('|');
      if (parts.length >= 3) {
        final city = parts[0];
        cityVotes[city] = (cityVotes[city] ?? 0) + 1;
      }
    }
    
    return cityVotes;
  }
  
  /// Get the most voted city for a checkpoint
  static Future<String?> getMostVotedCity(String checkpointId) async {
    final votes = await getCitySuggestions(checkpointId);
    
    if (votes.isEmpty) return null;
    
    // Return city with most votes
    var maxVotes = 0;
    String? topCity;
    
    votes.forEach((city, count) {
      if (count > maxVotes) {
        maxVotes = count;
        topCity = city;
      }
    });
    
    // Only return if it has at least 3 votes
    return maxVotes >= 3 ? topCity : null;
  }
  
  /// Check if user has already voted for this checkpoint
  static Future<bool> hasUserVoted(String checkpointId, String userDeviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_suggestionsPrefix$checkpointId';
    
    final suggestions = prefs.getStringList(key) ?? [];
    
    return suggestions.any(
      (suggestion) => suggestion.split('|')[1] == userDeviceId,
    );
  }
  
  /// Get total vote count for a checkpoint
  static Future<int> getTotalVotes(String checkpointId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_suggestionsPrefix$checkpointId';
    
    final suggestions = prefs.getStringList(key) ?? [];
    return suggestions.length;
  }
  
  /// Show city voting dialog
  static void showCityVotingDialog(
    BuildContext context,
    Checkpoint checkpoint,
    String userDeviceId,
  ) {
    final TextEditingController cityController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'اقتراح مدينة',
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
            const Text(
              'هذا الحاجز لا توجد مدينة محددة له. ساعدنا بإضافة المدينة الصحيحة:',
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: cityController,
              textDirection: TextDirection.rtl,
              decoration: const InputDecoration(
                labelText: 'اسم المدينة',
                border: OutlineInputBorder(),
                hintText: 'مثال: القدس، نابلس، جنين...',
                hintTextDirection: TextDirection.rtl,
              ),
            ),
            const SizedBox(height: 8),
            FutureBuilder<Map<String, int>>(
              future: getCitySuggestions(checkpoint.id),
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
                              Text(
                                entry.key,
                                textDirection: TextDirection.rtl,
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
            onPressed: () async {
              final cityName = cityController.text.trim();
              if (cityName.isNotEmpty) {
                await submitCitySuggestion(
                  checkpoint.id,
                  checkpoint.name,
                  cityName,
                  userDeviceId,
                );
                
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'تم إرسال اقتراحك بنجاح! شكراً لمساعدتنا',
                        textDirection: TextDirection.rtl,
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
  }
  
  /// Get a unique device ID
  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');
    
    if (deviceId == null) {
      deviceId = DateTime.now().millisecondsSinceEpoch.toString();
      await prefs.setString('device_id', deviceId);
    }
    
    return deviceId;
  }
}