import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';

class TaskProvider with ChangeNotifier {
  final TaskService _taskService = TaskService();
  List<Task> _tasks = [];
  late WebSocketChannel _channel;
  bool _connected = false;
  bool _isLoading = true;
  String? _error;

  bool get isLoading => _isLoading;
  bool get isConnected => _connected;
  String? get error => _error;
  List<Task> get tasks => List.unmodifiable(_tasks);

  TaskProvider() {
    _connectWebSocket();
  }

  void _connectWebSocket() {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse(TaskService.wsUrl),
      );

      _channel.stream.listen(
        (message) {
          final data = json.decode(message);
          switch (data['type']) {
            case 'init':
            case 'update':
              _updateTasks(data['tasks']);
              _connected = true;
              _isLoading = false;
              _error = null;
              break;
          }
          notifyListeners();
        },
        onDone: () {
          _connected = false;
          _error = '连接已断开';
          notifyListeners();
          // 尝试重新连接
          Future.delayed(Duration(seconds: 5), _connectWebSocket);
        },
        onError: (error) {
          print('WebSocket error: $error');
          _connected = false;
          _error = '连接错误: $error';
          _isLoading = false;
          notifyListeners();
        },
      );
    } catch (e) {
      _error = '无法连接到服务器: $e';
      _isLoading = false;
      notifyListeners();
      // 尝试重新连接
      Future.delayed(Duration(seconds: 5), _connectWebSocket);
    }
  }

  void _updateTasks(List<dynamic> tasksJson) {
    _tasks = tasksJson.map((json) => Task.fromJson(json)).toList();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadTasks() async {
    _connected = true;
    notifyListeners();

    try {
      _tasks = await _taskService.getTasks();
    } catch (e) {
      print('加载任务失败: $e');
    }

    _connected = false;
    notifyListeners();
  }

  Future<void> addTask(String title) async {
    try {
      _channel.sink.add(json.encode({
        'type': 'add',
        'title': title,
      }));
    } catch (e) {
      _error = '添加任务失败: $e';
      notifyListeners();
    }
  }

  Future<void> toggleTask(int id) async {
    try {
      _channel.sink.add(json.encode({
        'type': 'toggle',
        'id': id,
      }));
    } catch (e) {
      _error = '更新任务失败: $e';
      notifyListeners();
    }
  }

  Future<void> deleteTask(int id) async {
    try {
      _channel.sink.add(json.encode({
        'type': 'delete',
        'id': id,
      }));
    } catch (e) {
      _error = '删除任务失败: $e';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _channel.sink.close();
    super.dispose();
  }
} 