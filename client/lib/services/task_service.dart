import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/task.dart';
import 'config_service.dart';

class TaskService {
  static String? _serverHost;
  static int? _serverPort;
  static int? _wsPort;

  static Future<void> initialize() async {
    final config = await ConfigService.getServerConfig();
    _serverHost = config['serverHost'] as String;
    _serverPort = config['serverPort'] as int;
    _wsPort = config['wsPort'] as int;
  }

  static String get baseUrl => 'http://$_serverHost:$_serverPort';
  static String get wsUrl => 'ws://$_serverHost:$_wsPort/ws';

  Future<List<Task>> getTasks() async {
    if (_serverHost == null) await TaskService.initialize();
    final response = await http.get(Uri.parse(baseUrl));
    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);
      return jsonList.map((json) => Task.fromJson(json)).toList();
    } else {
      throw Exception('获取任务失败');
    }
  }

  Future<void> addTask(String title) async {
    if (_serverHost == null) await TaskService.initialize();
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'title': title}),
    );
    if (response.statusCode != 201) {
      throw Exception('添加任务失败');
    }
  }

  Future<void> toggleTask(int id) async {
    if (_serverHost == null) await TaskService.initialize();
    final response = await http.put(Uri.parse('$baseUrl/$id'));
    if (response.statusCode != 200) {
      throw Exception('更新任务状态失败');
    }
  }

  Future<void> deleteTask(int id) async {
    if (_serverHost == null) await TaskService.initialize();
    final response = await http.delete(Uri.parse('$baseUrl/$id'));
    if (response.statusCode != 200) {
      throw Exception('删除任务失败');
    }
  }
} 