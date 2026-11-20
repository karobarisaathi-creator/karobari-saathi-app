// lib/core/services/worker_service.dart

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:account_app/core/models/worker_model.dart';

class WorkerService extends ChangeNotifier {
  static const String _boxName = 'workers_box_v1';
  Box? _box;
  List<WorkerModel> _workers = [];

  List<WorkerModel> get workers => _workers;

  WorkerService() {
    _init();
  }

  Future<void> _init() async {
    if (_box == null || !(_box?.isOpen ?? false)) {
      if (!Hive.isBoxOpen(_boxName)) {
        _box = await Hive.openBox(_boxName);
      } else {
        _box = Hive.box(_boxName);
      }
    }
    _loadWorkers();
  }

  Future<void> ensureInitialized() async {
    await _init();
  }

  void _loadWorkers() {
    if (_box == null) return;
    try {
      _workers = _box!.values.map((e) {
        if (e is Map) {
          return WorkerModel.fromMap(e);
        }
        return null;
      }).whereType<WorkerModel>().toList();

      // Sort by creation date desc
      _workers.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading workers: $e');
    }
  }

  Future<void> addWorker({
    required String name,
    required String phone,
    required String skill,
  }) async {
    await _init();
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final worker = WorkerModel(
      id: id,
      name: name,
      phone: phone,
      skill: skill,
      createdAt: DateTime.now(),
    );

    await _box?.put(id, worker.toMap());
    _loadWorkers();
  }

  Future<void> updateWorker(WorkerModel worker) async {
    await _init();
    await _box?.put(worker.id, worker.toMap());
    _loadWorkers();
  }

  Future<void> deleteWorker(String id) async {
    await _init();
    await _box?.delete(id);
    _loadWorkers();
  }
}
