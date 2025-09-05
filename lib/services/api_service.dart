import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/notification.dart';

class ApiService {
  static const String _baseUrl = 'http://10.0.2.2:8081'; // Altere conforme necessário
  static const Duration _defaultTimeout = Duration(seconds: 10);
  static const Duration _statusTimeout = Duration(seconds: 3);

  Future<ApiResult<bool>> enviarNotificacao({
    required String mensagemId,
    required String conteudoMensagem,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/notificar'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'mensagemId': mensagemId,
          'conteudoMensagem': conteudoMensagem,
        }),
      ).timeout(_defaultTimeout);

      if (response.statusCode == 200 || response.statusCode == 201 ||
          response.statusCode == 202) {
        return ApiResult.success(true);
      } else {
        return ApiResult.error(
          'Erro HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } on TimeoutException {
      return ApiResult.error('Timeout: Servidor não respondeu em tempo hábil');
    } catch (e) {
      return ApiResult.error('Erro de conexão: ${e.toString()}');
    }
  }

  Future<ApiResult<String>> consultarStatus(String mensagemId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/status/$mensagemId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(_statusTimeout);

      if (response.statusCode == 200 || response.statusCode == 201  ||
          response.statusCode == 202  ) {
        final data = json.decode(response.body);
        final status = data['status'] ?? 'DESCONHECIDO';
        return ApiResult.success(status);
      } else if (response.statusCode == 404) {
        return ApiResult.error('Notificação não encontrada');
      } else {
        return ApiResult.error('Erro HTTP ${response.statusCode}');
      }
    } on TimeoutException {
      return ApiResult.error('Timeout na consulta de status');
    } catch (e) {
      return ApiResult.error('Erro: ${e.toString()}');
    }
  }

  Future<ApiResult<bool>> testarConectividade() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/health'),
        headers: {'Accept': 'application/json'},
      ).timeout(Duration(seconds: 3));

      return ApiResult.success(response.statusCode == 200);
    } catch (e) {
      return ApiResult.error('Servidor indisponível');
    }
  }
}

class ApiResult<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  ApiResult._({this.data, this.error, required this.isSuccess});

  factory ApiResult.success(T data) {
    return ApiResult._(data: data, isSuccess: true);
  }

  factory ApiResult.error(String error) {
    return ApiResult._(error: error, isSuccess: false);
  }

  bool get isError => !isSuccess;
}