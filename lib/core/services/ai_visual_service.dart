import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;

import 'package:account_app/core/config/ai_prompts.dart';

/// ============================================================
/// AI ERROR TYPES
/// ============================================================

enum AIErrorType {
  auth,
  quota,
  timeout,
  payment,
  network,
  parsing,
  unknown,
}

/// ============================================================
/// RESULT MODEL
/// ============================================================

class AIResult {
  final Map<String, String>? data;
  final AIErrorType? error;

  const AIResult({
    this.data,
    this.error,
  });

  bool get isSuccess => data != null && error == null;

  factory AIResult.success(Map<String, String> data) {
    return AIResult(data: data);
  }

  factory AIResult.failure(AIErrorType error) {
    return AIResult(error: error);
  }
}

/// ============================================================
/// API CLIENTS
/// ============================================================

class DeepSeekApiClient {
  final String apiKey;

  const DeepSeekApiClient(this.apiKey);

  Future<Map<String, dynamic>?> sendPrompt(String prompt) async {
    try {
      final response = await http
          .post(
            Uri.parse('https://api.deepseek.com/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'model': 'deepseek-chat',
              'messages': [
                {
                  'role': 'user',
                  'content': prompt,
                }
              ],
              'response_format': {
                'type': 'json_object',
              },
            }),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('DeepSeek Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      if (response.statusCode == 402) {
        throw AIException(AIErrorType.payment);
      }

      if (response.statusCode == 401) {
        throw AIException(AIErrorType.auth);
      }

      return null;
    } on TimeoutException {
      throw AIException(AIErrorType.timeout);
    } on SocketException {
      throw AIException(AIErrorType.network);
    } catch (e, stack) {
      debugPrint('DeepSeek Error: $e');
      debugPrintStack(stackTrace: stack);

      throw AIException(AIErrorType.unknown);
    }
  }
}

/// ============================================================
/// CUSTOM EXCEPTION
/// ============================================================

class AIException implements Exception {
  final AIErrorType type;

  AIException(this.type);

  @override
  String toString() => 'AIException: $type';
}

/// ============================================================
/// MAIN SERVICE
/// ============================================================

class AIVisualService {
  static final String _geminiApiKey =
      dotenv.env['GEMINI_API_KEY'] ?? '';

  static final String _deepSeekApiKey =
      dotenv.env['DEEPSEEK_API_KEY'] ?? '';

  static const List<String> _geminiModels = [
    'gemini-2.0-flash',
    'gemini-1.5-flash',
    'gemini-1.5-pro',
  ];

  late final DeepSeekApiClient _deepSeekClient;

  AIVisualService() {
    _deepSeekClient = DeepSeekApiClient(_deepSeekApiKey);
  }

  /// ============================================================
  /// CONTENT MODERATION (AI MODERATOR)
  /// ============================================================

  Future<AIResult> checkContentSafety(String title, String description) async {
    if (_geminiApiKey.isEmpty) {
      return AIResult.failure(AIErrorType.auth);
    }

    final prompt = """
      Act as a professional marketplace moderator. Analyze the following ad content for safety and professionalism.
      
      Title: $title
      Description: $description
      
      Return a JSON object with:
      1. "isSafe": boolean (true if no prohibited items like weapons, drugs, fraud, or inappropriate language).
      2. "reason": string (if unsafe, explain why in simple English).
      3. "professionalismScore": integer (1-10).
      4. "suggestion": string (how to make the ad more professional in one short sentence).
      
      JSON Only.
    """;

    for (final modelName in _geminiModels) {
      try {
        final model = GenerativeModel(model: modelName, apiKey: _geminiApiKey);
        final response = await model.generateContent([Content.text(prompt)]).timeout(const Duration(seconds: 10));

        if (response.text == null) continue;
        final parsed = _parseJsonResponse(response.text!);
        if (parsed != null) return AIResult.success(parsed);
      } catch (e) {
        debugPrint('Moderation Error: $e');
      }
    }
    return AIResult.failure(AIErrorType.unknown);
  }

  /// ============================================================
  /// IMAGE ANALYSIS
  /// ============================================================

  Future<AIResult> analyzeProductImage(File imageFile) async {
    if (_geminiApiKey.isEmpty) {
      return AIResult.failure(AIErrorType.auth);
    }

    try {
      final imageBytes = await imageFile.readAsBytes();

      final prompt = AIPrompts.buildPrompt(
        AIPrompts.imageAnalysisPrompt,
      );

      for (final modelName in _geminiModels) {
        try {
          debugPrint('Trying Gemini Model: $modelName');

          final model = GenerativeModel(
            model: modelName,
            apiKey: _geminiApiKey,
          );

          final content = [
            Content.multi([
              TextPart(prompt),
              DataPart('image/jpeg', imageBytes),
            ])
          ];

          final response = await model
              .generateContent(content)
              .timeout(const Duration(seconds: 15));

          if (response.text == null) {
            continue;
          }

          final parsed = _parseJsonResponse(response.text!);

          if (parsed != null) {
            return AIResult.success(parsed);
          }
        } on TimeoutException {
          return AIResult.failure(AIErrorType.timeout);
        } catch (e, stack) {
          debugPrint('Gemini Image Error: $e');
          debugPrintStack(stackTrace: stack);

          if (e.toString().contains('quota')) {
            return AIResult.failure(AIErrorType.quota);
          }
        }
      }

      return AIResult.failure(AIErrorType.unknown);
    } catch (e, stack) {
      debugPrint('Analyze Product Error: $e');
      debugPrintStack(stackTrace: stack);

      return AIResult.failure(AIErrorType.unknown);
    }
  }

  /// ============================================================
  /// TEXT SEARCH
  /// ============================================================

  Future<AIResult> searchProductByText(String query) async {
    if (query.trim().isEmpty) {
      return AIResult.failure(AIErrorType.parsing);
    }

    /// 1. TRY DEEPSEEK FIRST
    if (_deepSeekApiKey.isNotEmpty &&
        _deepSeekApiKey != 'YOUR_DEEPSEEK_API_KEY') {
      final deepSeekResult = await _searchWithDeepSeek(query);

      if (deepSeekResult.isSuccess) {
        return deepSeekResult;
      }

      if (deepSeekResult.error == AIErrorType.payment) {
        return deepSeekResult;
      }
    }

    /// 2. FALLBACK TO GEMINI
    return _searchWithGemini(query);
  }

  /// ============================================================
  /// DEEPSEEK SEARCH
  /// ============================================================

  Future<AIResult> _searchWithDeepSeek(String query) async {
    try {
      final prompt = AIPrompts.buildPrompt(
        AIPrompts.textSearchPrompt,
        query: query,
      );

      final data = await _deepSeekClient.sendPrompt(prompt);

      if (data == null) {
        return AIResult.failure(AIErrorType.unknown);
      }

      if (data['choices'] == null ||
          data['choices'] is! List ||
          (data['choices'] as List).isEmpty) {
        return AIResult.failure(AIErrorType.parsing);
      }

      final content =
          data['choices'][0]['message']['content'];

      if (content == null) {
        return AIResult.failure(AIErrorType.parsing);
      }

      final parsed = _parseJsonResponse(content);

      if (parsed == null) {
        return AIResult.failure(AIErrorType.parsing);
      }

      return AIResult.success(parsed);
    } on AIException catch (e) {
      return AIResult.failure(e.type);
    } catch (e, stack) {
      debugPrint('DeepSeek Search Error: $e');
      debugPrintStack(stackTrace: stack);

      return AIResult.failure(AIErrorType.unknown);
    }
  }

  /// ============================================================
  /// GEMINI SEARCH
  /// ============================================================

  Future<AIResult> _searchWithGemini(String query) async {
    if (_geminiApiKey.isEmpty) {
      return AIResult.failure(AIErrorType.auth);
    }

    final prompt = AIPrompts.buildPrompt(
      AIPrompts.textSearchPrompt,
      query: query,
    );

    for (final modelName in _geminiModels) {
      try {
        debugPrint('Trying Gemini Model: $modelName');

        final model = GenerativeModel(
          model: modelName,
          apiKey: _geminiApiKey,
        );

        final response = await model
            .generateContent([Content.text(prompt)])
            .timeout(const Duration(seconds: 15));

        if (response.text == null) {
          continue;
        }

        final parsed = _parseJsonResponse(response.text!);

        if (parsed != null) {
          return AIResult.success(parsed);
        }
      } on TimeoutException {
        return AIResult.failure(AIErrorType.timeout);
      } catch (e, stack) {
        debugPrint('Gemini Search Error: $e');
        debugPrintStack(stackTrace: stack);

        if (e.toString().contains('quota')) {
          return AIResult.failure(AIErrorType.quota);
        }
      }
    }

    return AIResult.failure(AIErrorType.unknown);
  }

  /// ============================================================
  /// JSON PARSER
  /// ============================================================

  Map<String, String>? _parseJsonResponse(String text) {
    try {
      String cleanText = text.trim();

      if (cleanText.startsWith('```')) {
        cleanText = cleanText
            .replaceAll(RegExp(r'```json|```'), '')
            .trim();
      }

      final decoded = jsonDecode(cleanText);

      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      return decoded.map(
        (key, value) => MapEntry(
          key.toString(),
          value.toString(),
        ),
      );
    } catch (e, stack) {
      debugPrint('JSON Parse Error: $e');
      debugPrintStack(stackTrace: stack);

      return null;
    }
  }
}
