import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

// 任务模型
class Task {
  final int id;
  final String title;
  bool completed;

  Task({
    required this.id,
    required this.title,
    this.completed = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'completed': completed,
      };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as int,
        title: json['title'] as String,
        completed: json['completed'] as bool,
      );
}

// 任务存储
class TaskStore {
  final List<Task> _tasks = [
    Task(id: 1, title: '学习 Flutter'),
    Task(id: 2, title: '学习 Dart'),
  ];
  int _nextId = 3;

  List<Task> getTasks() => List.unmodifiable(_tasks);

  Task addTask(String title) {
    final task = Task(id: _nextId++, title: title);
    _tasks.add(task);
    return task;
  }

  bool toggleTask(int id) {
    final task = _tasks.firstWhere(
      (task) => task.id == id,
      orElse: () => throw 'Task not found',
    );
    task.completed = !task.completed;
    return task.completed;
  }

  void deleteTask(int id) {
    _tasks.removeWhere((task) => task.id == id);
  }
}

void main() async {
  final store = TaskStore();
  final app = Router();

  // 获取所有任务
  app.get('/', (shelf.Request request) {
    return shelf.Response.ok(
      json.encode(store.getTasks().map((t) => t.toJson()).toList()),
      headers: {'content-type': 'application/json'},
    );
  });

  // 添加新任务
  app.post('/', (shelf.Request request) async {
    try {
      final body = await request.readAsString();
      final data = json.decode(body) as Map<String, dynamic>;
      final task = store.addTask(data['title'] as String);
      return shelf.Response(201,
          body: json.encode(task.toJson()),
          headers: {'content-type': 'application/json'});
    } catch (e) {
      return shelf.Response.badRequest(
          body: json.encode({'error': '无效的请求数据'}));
    }
  });

  // 切换任务状态
  app.put('/<id>', (shelf.Request request, String id) {
    try {
      final taskId = int.parse(id);
      store.toggleTask(taskId);
      return shelf.Response.ok('');
    } catch (e) {
      return shelf.Response.notFound('任务未找到');
    }
  });

  // 删除任务
  app.delete('/<id>', (shelf.Request request, String id) {
    try {
      final taskId = int.parse(id);
      store.deleteTask(taskId);
      return shelf.Response.ok('');
    } catch (e) {
      return shelf.Response.notFound('任务未找到');
    }
  });

  // 创建处理管道
  final handler = const shelf.Pipeline()
      .addMiddleware(corsHeaders()) // 添加 CORS 支持
      .addHandler(app);

  // 启动服务器
  final server = await io.serve(handler, InternetAddress.anyIPv4, 3000);
  print('服务器运行在: http://${server.address.host}:${server.port}');
} 