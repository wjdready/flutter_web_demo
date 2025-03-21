import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';
import 'package:shelf_router/shelf_router.dart';

// 获取本机所有 IPv4 地址
Future<List<String>> getLocalIPs() async {
  List<String> addresses = [];
  try {
    final interfaces = await NetworkInterface.list();
    for (var interface in interfaces) {
      for (var addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
          addresses.add(addr.address);
        }
      }
    }
  } catch (e) {
    print('获取本地IP地址失败: $e');
  }
  // 如果没有找到任何IP地址，返回localhost
  if (addresses.isEmpty) {
    addresses.add('localhost');
  }
  return addresses;
}

// 计算两个IP的匹配程度（返回匹配的段数）
int getMatchingSegments(String ip1, String ip2) {
  try {
    final parts1 = ip1.split('.');
    final parts2 = ip2.split('.');
    
    if (parts1.length != 4 || parts2.length != 4) {
      return 0;
    }

    int matchCount = 0;
    for (int i = 0; i < 4; i++) {
      if (parts1[i] == parts2[i]) {
        matchCount++;
      } else {
        break; // 一旦不匹配就停止，因为后面的段已经没有意义
      }
    }
    return matchCount;
  } catch (e) {
    return 0;
  }
}

// 获取客户端IP地址
String getClientIP(shelf.Request request) {
  // 尝试从X-Forwarded-For获取
  final forwardedFor = request.headers['x-forwarded-for'];
  if (forwardedFor != null && forwardedFor.isNotEmpty) {
    final ips = forwardedFor.split(',');
    return ips.first.trim();
  }
  
  // 从连接信息获取
  final remoteAddress = request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
  if (remoteAddress != null) {
    return remoteAddress.remoteAddress.address;
  }
  
  return 'localhost';
}

Future<void> openBrowser(String url) async {
  if (Platform.isWindows) {
    await Process.run('cmd', ['/c', 'start', url]);
  } else if (Platform.isMacOS) {
    await Process.run('open', [url]);
  } else if (Platform.isLinux) {
    await Process.run('xdg-open', [url]);
  }
}

Future<HttpServer> startWebServer(String webRoot) async {
  // 创建路由处理器
  final app = Router();

  // 添加配置接口
  app.get('/api/config', (shelf.Request request) async {
    final clientIP = getClientIP(request);
    final addresses = await getLocalIPs();
    
    // 找到匹配程度最高的IP
    String serverIP = addresses.fold<(String, int)>(
      (addresses.first, 0),  // 默认值：(第一个IP, 0个匹配段)
      (current, ip) {
        final matchCount = getMatchingSegments(ip, clientIP);
        return matchCount > current.$2 ? (ip, matchCount) : current;
      }
    ).$1;
    
    final config = {
      'serverHost': serverIP,
      'serverPort': 3000,
      'wsPort': 3000,
      'clientIP': clientIP,  // 用于调试
      'matchSegments': getMatchingSegments(serverIP, clientIP),  // 添加匹配段数，用于调试
    };
    
    print('客户端IP: $clientIP, 选择的服务器IP: $serverIP, 匹配段数: ${getMatchingSegments(serverIP, clientIP)}');
    
    return shelf.Response.ok(
      json.encode(config),
      headers: {
        'content-type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    );
  });

  // 创建静态文件处理器
  final staticHandler = createStaticHandler(
    webRoot,
    defaultDocument: 'index.html',
  );

  // 组合处理器
  final handler = shelf.Pipeline()
      .addMiddleware(shelf.logRequests())
      .addHandler((request) {
        if (request.url.path.startsWith('api/')) {
          return app(request);
        }
        return staticHandler(request);
      });

  final server = await io.serve(
    handler,
    InternetAddress.anyIPv4,
    8080,
  );
  
  print('Web 服务器运行在: http://localhost:8080');
  print('可通过以下地址访问：');
  final ips = await getLocalIPs();
  for (var ip in ips) {
    print('- http://$ip:8080');
  }
  return server;
}

Future<void> main() async {
  // 获取当前执行文件的目录
  final exePath = Platform.resolvedExecutable;
  final exeDir = path.dirname(exePath);
  
  print('启动后端服务器...');
  // 启动后端服务器进程
  final serverProcess = await Process.start(
    path.join(exeDir, 'server', 'server.exe'),
    [],
    workingDirectory: path.join(exeDir, 'server'),
  );

  // 输出服务器日志
  serverProcess.stdout.transform(const SystemEncoding().decoder).listen(print);
  serverProcess.stderr.transform(const SystemEncoding().decoder).listen(print);

  // 等待后端服务器启动
  print('等待后端服务器就绪...');
  await Future.delayed(const Duration(seconds: 2));

  print('启动 Web 服务器...');
  // 启动 Web 服务器
  final webServer = await startWebServer(path.join(exeDir, 'web'));

  print('启动 Windows 客户端...');
  // 启动 Flutter Windows 客户端
  final clientProcess = await Process.start(
    path.join(exeDir, 'client', 'client.exe'),
    [],
    workingDirectory: path.join(exeDir, 'client'),
  );

  print('打开网页版...');
  // 打开网页版
  await openBrowser('http://localhost:8080');

  // 监听进程退出
  print('等待客户端关闭...');
  int exitCode = await clientProcess.exitCode;
  print('客户端已关闭，正在关闭所有服务...');
  
  // 关闭所有服务
  serverProcess.kill();
  await webServer.close();
  
  exit(exitCode);
} 