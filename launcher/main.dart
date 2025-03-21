import 'dart:io';
import 'package:path/path.dart' as path;

Future<void> openBrowser(String url) async {
  if (Platform.isWindows) {
    await Process.run('cmd', ['/c', 'start', url]);
  } else if (Platform.isMacOS) {
    await Process.run('open', [url]);
  } else if (Platform.isLinux) {
    await Process.run('xdg-open', [url]);
  }
}

Future<void> main() async {
  // 获取当前执行文件的目录
  final exePath = Platform.resolvedExecutable;
  final exeDir = path.dirname(exePath);
  
  print('启动服务器...');
  // 启动服务器进程
  final serverProcess = await Process.start(
    path.join(exeDir, 'server', 'server.exe'),
    [],
    workingDirectory: path.join(exeDir, 'server'),
  );

  // 输出服务器日志
  serverProcess.stdout.transform(const SystemEncoding().decoder).listen(print);
  serverProcess.stderr.transform(const SystemEncoding().decoder).listen(print);

  // 等待服务器启动
  print('等待服务器就绪...');
  await Future.delayed(const Duration(seconds: 2));

  print('启动 Windows 客户端...');
  // 启动 Flutter Windows 客户端
  final clientProcess = await Process.start(
    path.join(exeDir, 'client', 'client.exe'),
    [],
    workingDirectory: path.join(exeDir, 'client'),
  );

  print('打开网页版...');
  // 打开网页版
  await openBrowser('http://localhost:3000');

  // 监听进程退出
  print('等待客户端关闭...');
  int exitCode = await clientProcess.exitCode;
  print('客户端已关闭，正在关闭服务器...');
  serverProcess.kill(); // 当客户端关闭时，关闭服务器
  exit(exitCode);
} 