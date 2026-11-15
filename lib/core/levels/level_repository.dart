import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/game_models.dart';

class LevelRepository {
  const LevelRepository();

  Future<LevelModel> load(int world, int number) async {
    final suffix = number.toString().padLeft(2, '0');
    final path = 'assets/levels/world_${world}_level_$suffix.json';
    final contents = await rootBundle.loadString(path);
    return LevelModel.fromJson(jsonDecode(contents) as Map<String, Object?>);
  }
}
