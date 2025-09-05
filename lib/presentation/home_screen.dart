import 'package:flutter/material.dart' hide Notification;
import 'dart:async';
import 'package:uuid/uuid.dart';
import '../models/notification.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Notification> _notifications = [];
  final _apiService = ApiService();
  Timer? _pollingTimer;
  bool _isLoading = false;
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    _iniciarPolling();
    _verificarConectividade();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  void _iniciarPolling() {
    _pollingTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      _atualizarStatusNotificacoes();
    });
  }

  Future<void> _verificarConectividade() async {
    final result = await _apiService.testarConectividade();
    setState(() {
      _isConnected = result.isSuccess;
    });
  }

  Future<void> _enviarNotificacao() async {
    if (_messageController.text.trim().isEmpty) {
      _mostrarSnackBar('Por favor, insira uma mensagem', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final String mensagemId = Uuid().v4();
    final String conteudoMensagem = _messageController.text.trim();

    final novaNotificacao = Notification(
      id: mensagemId,
      content: conteudoMensagem,
      status: 'AGUARDANDO PROCESSAMENTO',
      timestamp: DateTime.now(),
    );

    setState(() {
      _notifications.insert(0, novaNotificacao);
    });

    final result = await _apiService.enviarNotificacao(
      mensagemId: mensagemId,
      conteudoMensagem: conteudoMensagem,
    );

    setState(() {
      _isLoading = false;
    });

    if (result.isSuccess) {
      _messageController.clear();
      _mostrarSnackBar('Notificação enviada com sucesso!');
      setState(() {
        _isConnected = true;
      });
    } else {
      _atualizarStatusNotificacao(mensagemId, 'ERRO DE ENVIO');
      _mostrarSnackBar('Erro: ${result.error}', isError: true);
      setState(() {
        _isConnected = false;
      });
    }
  }

  Future<void> _atualizarStatusNotificacoes() async {
    final notificacoesPendentes = _notifications
        .where((n) => _isStatusPendente(n.status))
        .toList();

    for (var notificacao in notificacoesPendentes) {
      await _consultarStatusNotificacao(notificacao.id);
    }
  }

  Future<void> _consultarStatusNotificacao(String mensagemId) async {
    final result = await _apiService.consultarStatus(mensagemId);

    if (result.isSuccess && result.data != null) {
      _atualizarStatusNotificacao(mensagemId, result.data!);
      setState(() {
        _isConnected = true;
      });
    } else {
      setState(() {
        _isConnected = false;
      });
    }
  }

  void _atualizarStatusNotificacao(String mensagemId, String novoStatus) {
    setState(() {
      final index = _notifications.indexWhere((n) => n.id == mensagemId);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(
          status: novoStatus,
        );
      }
    });
  }

  bool _isStatusPendente(String status) {
    return status == 'AGUARDANDO PROCESSAMENTO' || status == 'PROCESSANDO';
  }

  void _mostrarSnackBar(String mensagem, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'AGUARDANDO PROCESSAMENTO':
        return Colors.orange;
      case 'PROCESSANDO':
        return Colors.blue;
      case 'PROCESSADO':
      case 'SUCESSO':
        return Colors.green;
      case 'ERRO':
      case 'ERRO DE ENVIO':
      case 'ERRO DE CONEXÃO':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'AGUARDANDO PROCESSAMENTO':
        return Icons.schedule;
      case 'PROCESSANDO':
        return Icons.sync;
      case 'PROCESSADO':
      case 'SUCESSO':
        return Icons.check_circle;
      case 'ERRO':
      case 'ERRO DE ENVIO':
      case 'ERRO DE CONEXÃO':
        return Icons.error;
      default:
        return Icons.help;
    }
  }

  String _formatarTimestamp(DateTime timestamp) {
    return '${timestamp.day.toString().padLeft(2, '0')}/'
        '${timestamp.month.toString().padLeft(2, '0')}/'
        '${timestamp.year} '
        '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }

  void _limparNotificacoes() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmar'),
          content: Text('Deseja limpar todas as notificações?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _notifications.clear();
                });
                Navigator.of(context).pop();
                _mostrarSnackBar('Notificações removidas');
              },
              child: Text('Confirmar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sistema de Notificações'),
        elevation: 2,
        actions: [
          Container(
            margin: EdgeInsets.only(right: 16),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isConnected ? Icons.wifi : Icons.wifi_off,
                    color: _isConnected ? Colors.green : Colors.red,
                    size: 20,
                  ),
                  SizedBox(width: 4),
                  Text(
                    _isConnected ? 'Online' : 'Offline',
                    style: TextStyle(
                      fontSize: 12,
                      color: _isConnected ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_notifications.isNotEmpty)
            IconButton(
              onPressed: _limparNotificacoes,
              icon: Icon(Icons.clear_all),
              tooltip: 'Limpar todas',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Nova Notificação',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _messageController,
                      maxLines: 3,
                      maxLength: 500,
                      decoration: InputDecoration(
                        labelText: 'Conteúdo da Mensagem',
                        hintText: 'Digite sua mensagem aqui...',
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue),
                        ),
                        counterText: '', // Remove contador padrão
                      ),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _enviarNotificacao,
                      icon: _isLoading
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Icon(Icons.send),
                      label: Text(_isLoading ? 'Enviando...' : 'Enviar Notificação'),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Histórico de Notificações',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (_notifications.isNotEmpty)
                  Text(
                    '${_notifications.length} ${_notifications.length == 1 ? 'item' : 'itens'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            SizedBox(height: 10),
            Expanded(
              child: _notifications.isEmpty
                  ? _buildEmptyState()
                  : _buildNotificationsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'Nenhuma notificação enviada',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Envie sua primeira notificação!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList() {
    return ListView.builder(
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        return Card(
          margin: EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(notification.status),
              child: Icon(
                _getStatusIcon(notification.status),
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(
              notification.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 4),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(notification.status).withValues(alpha:  0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getStatusColor(notification.status),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    notification.status,
                    style: TextStyle(
                      color: _getStatusColor(notification.status),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'ID: ${notification.id.substring(0, 8)}...',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  _formatarTimestamp(notification.timestamp),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            isThreeLine: true,
            trailing: _isStatusPendente(notification.status)
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getStatusColor(notification.status),
                      ),
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }
}