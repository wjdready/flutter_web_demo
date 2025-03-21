import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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

// 添加 WebSocket 连接管理
class ConnectionManager {
  final Set<WebSocketChannel> _connections = {};

  void add(WebSocketChannel channel) {
    _connections.add(channel);
  }

  void remove(WebSocketChannel channel) {
    _connections.remove(channel);
  }

  // 向所有连接的客户端广播更新
  void broadcast(dynamic data) {
    final message = json.encode(data);
    for (final connection in _connections) {
      connection.sink.add(message);
    }
  }
}

// 任务存储
class TaskStore {
  final ConnectionManager _connections;
  final List<Task> _tasks = [
    Task(id: 1, title: '学习 Flutter'),
    Task(id: 2, title: '学习 Dart'),
  ];
  int _nextId = 3;

  TaskStore(this._connections);

  List<Task> getTasks() => List.unmodifiable(_tasks);

  // 添加任务并通知所有客户端
  void addTask(String title) {
    final task = Task(id: _nextId++, title: title);
    _tasks.add(task);
    _notifyClients();
  }

  void toggleTask(int id) {
    final taskIndex = _tasks.indexWhere((task) => task.id == id);
    if (taskIndex != -1) {
      _tasks[taskIndex].completed = !_tasks[taskIndex].completed;
      _notifyClients();
    }
  }

  void deleteTask(int id) {
    _tasks.removeWhere((task) => task.id == id);
    _notifyClients();
  }

  // 其他方法类似，每次更新后都调用 _notifyClients
  void _notifyClients() {
    _connections.broadcast({
      'type': 'update',
      'tasks': _tasks.map((t) => t.toJson()).toList(),
    });
  }
}

void main() async {
  final connections = ConnectionManager();
  final store = TaskStore(connections);
  final app = Router();

  // WebSocket 处理
  app.get('/ws', webSocketHandler((WebSocketChannel webSocket, String? protocol) {
    print('新的客户端连接');
    connections.add(webSocket);
    
    // 发送初始数据
    webSocket.sink.add(json.encode({
      'type': 'init',
      'tasks': store.getTasks().map((t) => t.toJson()).toList(),
    }));

    // 处理客户端消息
    webSocket.stream.listen(
      (message) {
        try {
          final data = json.decode(message as String);
          switch (data['type']) {
            case 'add':
              store.addTask(data['title'] as String);
              break;
            case 'toggle':
              store.toggleTask(data['id'] as int);
              break;
            case 'delete':
              store.deleteTask(data['id'] as int);
              break;
            default:
              print('未知的消息类型: ${data['type']}');
          }
        } catch (e) {
          print('处理消息时出错: $e');
        }
      },
      onDone: () {
        print('客户端断开连接');
        connections.remove(webSocket);
      },
      onError: (error) {
        print('WebSocket 错误: $error');
        connections.remove(webSocket);
      },
    );
  }));

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
      store.addTask(data['title'] as String);
      return shelf.Response(201,
          body: json.encode({'message': '任务添加成功'}),
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
      .addMiddleware(corsHeaders(headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Origin, Content-Type',
      }))
      .addMiddleware(shelf.logRequests())
      .addHandler(app);

  // 启动服务器，监听所有网络接口
  final server = await io.serve(
    handler, 
    InternetAddress.anyIPv4,  // 监听所有IPv4地址
    3000,
    shared: true,  // 允许端口共享
  );
  print('服务器运行在: http://${server.address.host}:${server.port}');
  print('可以通过以下地址访问：');
  print('- http://localhost:3000');
  print('- http://${InternetAddress.anyIPv4.address}:3000');
  
  // 获取本机所有网络接口
  NetworkInterface.list().then((interfaces) {
    for (var interface in interfaces) {
      for (var addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv4) {
          print('- http://${addr.address}:3000');
        }
      }
    }
  });
} 