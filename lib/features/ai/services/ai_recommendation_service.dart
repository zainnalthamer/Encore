import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/recommendation_item.dart';

class AiRecommendationService {
  static String get _baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000';
    }
    return 'http://10.0.2.2:3000';
  }

  Future<List<RecommendationItem>> getRecommendations({
    required String prompt,
    required String category,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/recommend'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'prompt': prompt,
        'category': category,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to get AI recommendations: ${response.body}',
      );
    }

    final Map<String, dynamic> data = jsonDecode(response.body);
    final List items = data['items'] ?? [];

    return items
        .map((item) => RecommendationItem.fromJson(item))
        .toList();
  }
}