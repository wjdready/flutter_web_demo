import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/task.dart';

class TaskService {
  // 修改为您的服务器 IP 地址
  static const String serverHost = '192.168.1.89'; // 替换为您的实际 IP 地址
  static const int serverPort = 3000;
  
  static String get baseUrl => 'http://$serverHost:$serverPort';
  static String get wsUrl => 'ws://$serverHost:$serverPort/ws';

  Future<List<Task>> getTasks() async {
    final response = await http.get(Uri.parse(baseUrl));
    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);
      return jsonList.map((json) => Task.fromJson(json)).toList();
    } else {
      throw Exception('获取任务失败');
    }
  }

  Future<void> addTask(String title) async {
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
    final response = await http.put(Uri.parse('$baseUrl/$id'));
    if (response.statusCode != 200) {
      throw Exception('更新任务状态失败');
    }
  }

  Future<void> deleteTask(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/$id'));
    if (response.statusCode != 200) {
      throw Exception('删除任务失败');
    }
  }
} 