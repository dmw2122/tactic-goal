import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final progressProvider = NotifierProvider<ProgressNotifier, PlayerProgress>(
  ProgressNotifier.new,
);
final soundProvider = NotifierProvider<SoundNotifier, bool>(SoundNotifier.new);

class PlayerProgress {
  const PlayerProgress({this.stars = const <String, int>{}});

  final Map<String, int> stars;

  int starsFor(String id) => stars[id] ?? 0;

  bool isUnlocked(int world, int number) {
    if (world == 1 && number == 1) return true;
    if (world == 2 && starsFor('1-10') == 0) return false;
    if (number == 1) return world == 2;
    return starsFor('$world-${number - 1}') > 0;
  }

  PlayerProgress withStars(String id, int value) {
    final updated = Map<String, int>.of(stars);
    if (value > (updated[id] ?? 0)) updated[id] = value;
    return PlayerProgress(stars: Map.unmodifiable(updated));
  }
}

class ProgressNotifier extends Notifier<PlayerProgress> {
  @override
  PlayerProgress build() => const PlayerProgress();

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString('tactic_goal_stars');
    if (stored == null) return;
    final decoded = jsonDecode(stored);
    if (decoded is! Map<String, dynamic>) return;
    state = PlayerProgress(
      stars: Map<String, int>.unmodifiable(
        decoded.map((key, value) => MapEntry(key, value as int)),
      ),
    );
  }

  Future<void> completeLevel(String id, int stars) async {
    state = state.withStars(id, stars);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('tactic_goal_stars', jsonEncode(state.stars));
  }
}

class SoundNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    state = preferences.getBool('tactic_goal_sound') ?? true;
  }

  Future<void> toggle() async {
    state = !state;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('tactic_goal_sound', state);
  }
}
