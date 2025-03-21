import 'dart:convert';
import 'package:http/http.dart' as http;

class ConfigService {
  static Future<Map<String, dynamic>> getServerConfig() async {
    try {
      // 获取当前页面的主机名和端口
      final currentUrl = Uri.base;
      final configUrl = Uri(
        scheme: currentUrl.scheme,
        host: currentUrl.host,
        port: currentUrl.port,
        path: '/api/config',
      );

      final response = await http.get(configUrl);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('获取服务器配置失败');
      }
    } catch (e) {
      // 如果获取配置失败，使用默认配置（本地开发环境）
      return {
        'serverHost': 'localhost',
        'serverPort': 3000,
        'wsPort': 3000,
      };
    }
  }
} 