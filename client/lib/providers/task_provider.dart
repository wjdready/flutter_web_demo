import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../services/task_service.dart';

class TaskProvider with ChangeNotifier {
  final TaskService _taskService = TaskService();
  List<Task> _tasks = [];
  bool _isLoading = false;

  List<Task> get tasks => _tasks;
  bool get isLoading => _isLoading;

  Future<void> loadTasks() async {
    _isLoading = true;
    notifyListeners();

    try {
      _tasks = await _taskService.getTasks();
    } catch (e) {
      print('加载任务失败: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addTask(String title) async {
    try {
      await _taskService.addTask(title);
      await loadTasks();
    } catch (e) {
      print('添加任务失败: $e');
    }
  }

  Future<void> toggleTask(int id) async {
    try {
      await _taskService.toggleTask(id);
      await loadTasks();
    } catch (e) {
      print('切换任务状态失败: $e');
    }
  }

  Future<void> deleteTask(int id) async {
    try {
      await _taskService.deleteTask(id);
      await loadTasks();
    } catch (e) {
      print('删除任务失败: $e');
    }
  }
} 