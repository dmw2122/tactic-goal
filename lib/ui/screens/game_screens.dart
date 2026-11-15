import 'dart:async';

import 'package:flame/game.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/game_assets.dart';
import '../../core/engine/movement_solver.dart';
import '../../core/engine/undo_manager.dart';
import '../../core/levels/level_repository.dart';
import '../../core/models/game_models.dart';
import '../../core/progress/progress_provider.dart';
import '../../game/tactic_goal_game.dart';

const _ink = Color(0xFF243B2B);
const _grass = Color(0xFFEAF4D7);
const _cream = Color(0xFFFFF8E8);
const _green = Color(0xFF4FAD58);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(ref.read(progressProvider.notifier).load());
    unawaited(ref.read(soundProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final sound = ref.watch(soundProvider);
    final stars = ref
        .watch(progressProvider)
        .stars
        .values
        .fold<int>(0, (sum, value) => sum + value);
    return Scaffold(
      backgroundColor: _grass,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              right: 18,
              top: 16,
              child: IconButton(
                tooltip: sound ? 'Sesi kapat' : 'Sesi aç',
                onPressed: () => ref.read(soundProvider.notifier).toggle(),
                icon: Image.asset(
                  sound ? GameAssets.soundOn : GameAssets.soundOff,
                  width: 48,
                  height: 48,
                ),
              ),
            ),
            Positioned(
              right: 76,
              top: 16,
              child: IconButton(
                tooltip: 'Ayarlar',
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: _cream,
                    title: const Text('Ayarlar'),
                    content: const Text(
                      'Ses ayarını üst köşedeki düğmeden değiştirebilirsin.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('TAMAM'),
                      ),
                    ],
                  ),
                ),
                icon: Image.asset(GameAssets.settings, width: 44, height: 44),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(GameAssets.ball, width: 128, height: 128),
                    const SizedBox(height: 8),
                    Text(
                      'TACTIC GOAL',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: _ink,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Kartlarını seç. Pasını planla. Golü bul!',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _ink.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 30),
                    _MenuButton(
                      icon: GameAssets.leagues,
                      label: 'OYNA',
                      color: _green,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const LeagueScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '$stars ⭐ kazanıldı',
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LeagueScreen extends ConsumerWidget {
  const LeagueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final secondWorldUnlocked = progress.starsFor('1-10') > 0;
    return _PageScaffold(
      title: 'Ligler',
      child: Column(
        children: [
          _WorldCard(
            number: 1,
            name: 'Antrenman Sahası',
            detail: 'Temel paslar ve ilk goller',
            stars: _worldStars(progress, 1),
            unlocked: true,
            onTap: () => _openWorld(context, 1),
          ),
          const SizedBox(height: 16),
          _WorldCard(
            number: 2,
            name: 'Amatör Küme',
            detail: 'Daha zorlu taktik mücadeleleri',
            stars: _worldStars(progress, 2),
            unlocked: secondWorldUnlocked,
            onTap: secondWorldUnlocked ? () => _openWorld(context, 2) : null,
          ),
        ],
      ),
    );
  }

  int _worldStars(PlayerProgress progress, int world) => progress.stars.entries
      .where((entry) => entry.key.startsWith('$world-'))
      .fold(0, (sum, entry) => sum + entry.value);

  void _openWorld(BuildContext context, int world) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => LevelSelectScreen(world: world)),
    );
  }
}

class LevelSelectScreen extends ConsumerWidget {
  const LevelSelectScreen({required this.world, super.key});

  final int world;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final title = world == 1 ? 'Antrenman Sahası' : 'Amatör Küme';
    return _PageScaffold(
      title: title,
      child: GridView.builder(
        shrinkWrap: true,
        itemCount: 10,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.25,
        ),
        itemBuilder: (context, index) {
          final number = index + 1;
          final id = '$world-$number';
          final unlocked = progress.isUnlocked(world, number);
          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: unlocked
                ? () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => GameScreen(world: world, number: number),
                    ),
                  )
                : null,
            child: _ToyCard(
              color: unlocked ? _cream : const Color(0xFFD8DDCF),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    unlocked ? GameAssets.ball : GameAssets.settings,
                    width: 42,
                    height: 42,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Bölüm $number',
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    unlocked ? _starsText(progress.starsFor(id)) : 'KİLİTLİ',
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({required this.world, required this.number, super.key});

  final int world;
  final int number;

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  late final Future<LevelModel> _levelFuture;
  final _solver = const MovementSolver();
  final _undo = UndoManager<_GameSnapshot>();
  LevelModel? _level;
  TacticGoalGame? _game;
  GridPosition? _position;
  List<bool> _remaining = const [];
  int? _selectedCard;
  int _moves = 0;
  bool _busy = false;
  bool _won = false;
  bool _showInvalid = false;

  @override
  void initState() {
    super.initState();
    _levelFuture = const LevelRepository().load(widget.world, widget.number);
  }

  void _loadLevel(LevelModel level) {
    if (_level != null) return;
    _level = level;
    _position = level.start;
    _remaining = List<bool>.filled(level.cards.length, true);
    _game = TacticGoalGame(level: level, onGoal: _onGoal);
  }

  Future<void> _play(GridDirection direction) async {
    final level = _level;
    final cardIndex = _selectedCard;
    final position = _position;
    if (_busy || level == null || cardIndex == null || position == null) {
      return;
    }
    final result = _solver.solve(
      level: level,
      start: position,
      card: level.cards[cardIndex],
      direction: direction,
    );
    if (!result.isValid) {
      setState(() => _showInvalid = true);
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (mounted) {
        setState(() => _showInvalid = false);
      }
      if (ref.read(soundProvider)) {
        unawaited(FlameAudio.play(GameAssets.bounceAudio));
      }
      return;
    }

    _undo.push(
      _GameSnapshot(
        position: position,
        remaining: List<bool>.of(_remaining),
        moves: _moves,
      ),
    );
    setState(() {
      _busy = true;
      _remaining[cardIndex] = false;
      _position = result.position;
      _moves++;
      _selectedCard = null;
      _showInvalid = false;
    });
    _game?.clearGuides();
    if (ref.read(soundProvider)) {
      unawaited(FlameAudio.play(GameAssets.kickAudio));
    }
    await _game?.animateMove(result);
    if (mounted && !_won) setState(() => _busy = false);
  }

  void _onGoal() {
    if (!mounted || _won || _level == null) return;
    _won = true;
    final level = _level!;
    final stars = _moves <= level.threeStarMoves
        ? 3
        : _moves <= level.twoStarMoves
        ? 2
        : 1;
    unawaited(
      ref.read(progressProvider.notifier).completeLevel(level.id, stars),
    );
    if (ref.read(soundProvider)) {
      unawaited(FlameAudio.play(GameAssets.goalAudio));
    }
    setState(() => _busy = false);
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: _cream,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          title: const Text('GOOOL! ⚽'),
          content: Text('Harika oyun! ${_starsText(stars)}'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('MENÜ'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                _nextLevel();
              },
              child: const Text('SONRAKİ'),
            ),
          ],
        ),
      ),
    );
  }

  void _nextLevel() {
    if (widget.number >= 10) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) =>
            GameScreen(world: widget.world, number: widget.number + 1),
      ),
    );
  }

  void _undoMove() {
    if (_busy || !_undo.canUndo) return;
    final snapshot = _undo.undo();
    if (snapshot == null) return;
    setState(() {
      _position = snapshot.position;
      _remaining = List<bool>.of(snapshot.remaining);
      _moves = snapshot.moves;
      _selectedCard = null;
      _won = false;
    });
    _game?.resetBall();
    _game?.clearGuides();
    if (ref.read(soundProvider)) {
      unawaited(FlameAudio.play(GameAssets.undoAudio));
    }
  }

  void _restart() {
    final level = _level;
    if (_busy || level == null) return;
    setState(() {
      _position = level.start;
      _remaining = List<bool>.filled(level.cards.length, true);
      _moves = 0;
      _selectedCard = null;
      _won = false;
      _showInvalid = false;
    });
    _undo.clear();
    _game?.resetBall();
    _game?.clearGuides();
    if (ref.read(soundProvider)) {
      unawaited(FlameAudio.play(GameAssets.undoAudio));
    }
  }

  GridDirection? _directionForSwipe(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond;
    if (velocity.distance < 90) return null;
    final directions = <GridDirection, Offset>{
      for (final direction in GridDirection.values)
        direction: Offset(
          (direction.dx - direction.dy).toDouble(),
          (direction.dx + direction.dy).toDouble(),
        ),
    };
    GridDirection? best;
    var bestDot = double.negativeInfinity;
    for (final entry in directions.entries) {
      final vector = entry.value;
      final dot = velocity.dx * vector.dx + velocity.dy * vector.dy;
      if (dot > bestDot) {
        bestDot = dot;
        best = entry.key;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<LevelModel>(
    future: _levelFuture,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
          body: Center(child: Text('Bölüm yüklenemedi: ${snapshot.error}')),
        );
      }
      if (!snapshot.hasData) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      _loadLevel(snapshot.data!);
      final level = _level!;
      return Scaffold(
        backgroundColor: _grass,
        body: SafeArea(
          child: Column(
            children: [
              _gameHeader(context, level),
              Expanded(
                child: GestureDetector(
                  onPanEnd: (details) {
                    final direction = _directionForSwipe(details);
                    if (direction != null) unawaited(_play(direction));
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      GameWidget<TacticGoalGame>(game: _game!),
                      if (_showInvalid)
                        Center(
                          child: Image.asset(
                            GameAssets.indicatorInvalid,
                            width: 72,
                            height: 72,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              _directionPad(level),
              _cardHand(level),
            ],
          ),
        ),
      );
    },
  );

  Widget _gameHeader(BuildContext context, LevelModel level) {
    final sound = ref.watch(soundProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  level.title,
                  maxLines: 1,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Dünya ${widget.world}  •  $_moves hamle',
                  style: const TextStyle(color: _ink, fontSize: 12),
                ),
              ],
            ),
          ),
          _ImageAction(
            path: GameAssets.undo,
            tooltip: 'Geri al',
            enabled: _undo.canUndo && !_busy,
            onTap: _undoMove,
          ),
          _ImageAction(
            path: GameAssets.restart,
            tooltip: 'Yeniden başlat',
            enabled: !_busy,
            onTap: _restart,
          ),
          IconButton(
            tooltip: sound ? 'Sesi kapat' : 'Sesi aç',
            onPressed: () => ref.read(soundProvider.notifier).toggle(),
            icon: Image.asset(
              sound ? GameAssets.soundOn : GameAssets.soundOff,
              width: 40,
              height: 40,
            ),
          ),
        ],
      ),
    );
  }

  Widget _directionPad(LevelModel level) {
    final selected = _selectedCard;
    final canPlay = selected != null && _remaining[selected] && !_busy;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final direction in GridDirection.values)
            _DirectionButton(
              direction: direction,
              valid:
                  selected != null &&
                  _solver
                      .solve(
                        level: level,
                        start: _position ?? level.start,
                        card: level.cards[selected],
                        direction: direction,
                      )
                      .isValid,
              enabled: canPlay,
              onTap: () => _play(direction),
            ),
        ],
      ),
    );
  }

  Widget _cardHand(LevelModel level) {
    final visible = level.cards
        .asMap()
        .entries
        .where((entry) => _remaining[entry.key])
        .toList();
    if (visible.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(18, 8, 18, 22),
        child: Text(
          'Kart kalmadı — geri al veya bölümü yeniden başlat.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _ink, fontWeight: FontWeight.w700),
        ),
      );
    }
    return SizedBox(
      height: 126,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
        scrollDirection: Axis.horizontal,
        itemCount: visible.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final entry = visible[index];
          final selected = _selectedCard == entry.key;
          return GestureDetector(
            onTap: _busy
                ? null
                : () {
                    setState(() => _selectedCard = selected ? null : entry.key);
                    _refreshGuides(level);
                    if (ref.read(soundProvider)) {
                      unawaited(FlameAudio.play(GameAssets.cardAudio));
                    }
                  },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 88,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFFFD86B) : _cream,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? _green : Colors.white,
                  width: selected ? 3 : 2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x334D412E),
                    blurRadius: 5,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Image.asset(
                      _cardImage(entry.value.type),
                      fit: BoxFit.contain,
                    ),
                  ),
                  Text(
                    'GÜÇ ${entry.value.power}',
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _cardImage(ActionType type) => switch (type) {
    ActionType.pass => GameAssets.cardPass,
    ActionType.shoot => GameAssets.cardShoot,
    ActionType.lob => GameAssets.cardLob,
    ActionType.curve => GameAssets.cardCurve,
  };

  void _refreshGuides(LevelModel level) {
    final selected = _selectedCard;
    final position = _position;
    if (selected == null || position == null) {
      _game?.clearGuides();
      return;
    }
    _game?.showGuides(
      GridDirection.values.map(
        (direction) => _solver.solve(
          level: level,
          start: position,
          card: level.cards[selected],
          direction: direction,
        ),
      ),
    );
  }
}

class _GameSnapshot {
  const _GameSnapshot({
    required this.position,
    required this.remaining,
    required this.moves,
  });

  final GridPosition position;
  final List<bool> remaining;
  final int moves;
}

class _PageScaffold extends StatelessWidget {
  const _PageScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _grass,
    appBar: AppBar(
      backgroundColor: _grass,
      foregroundColor: _ink,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
    ),
    body: SafeArea(
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    ),
  );
}

class _WorldCard extends StatelessWidget {
  const _WorldCard({
    required this.number,
    required this.name,
    required this.detail,
    required this.stars,
    required this.unlocked,
    required this.onTap,
  });

  final int number;
  final String name;
  final String detail;
  final int stars;
  final bool unlocked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(24),
    child: _ToyCard(
      color: unlocked ? _cream : const Color(0xFFD8DDCF),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Image.asset(
              unlocked ? GameAssets.leagues : GameAssets.settings,
              width: 70,
              height: 70,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'DÜNYA $number',
                    style: const TextStyle(
                      color: _green,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    name,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    unlocked ? detail : '1. Dünyayı tamamla',
                    style: const TextStyle(color: _ink),
                  ),
                ],
              ),
            ),
            Text(
              unlocked ? '$stars ⭐' : '🔒',
              style: const TextStyle(color: _ink, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 260,
    height: 66,
    child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 5,
      ),
      onPressed: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(icon, width: 42, height: 42),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 19,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ToyCard extends StatelessWidget {
  const _ToyCard({required this.child, required this.color});

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white, width: 2),
      boxShadow: const [
        BoxShadow(
          color: Color(0x294D412E),
          blurRadius: 9,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: child,
  );
}

class _ImageAction extends StatelessWidget {
  const _ImageAction({
    required this.path,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });

  final String path;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: enabled ? onTap : null,
    icon: Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Image.asset(path, width: 40, height: 40),
    ),
  );
}

class _DirectionButton extends StatelessWidget {
  const _DirectionButton({
    required this.direction,
    required this.valid,
    required this.enabled,
    required this.onTap,
  });

  final GridDirection direction;
  final bool valid;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (direction) {
      GridDirection.northEast => Icons.north_east,
      GridDirection.northWest => Icons.north_west,
      GridDirection.southEast => Icons.south_east,
      GridDirection.southWest => Icons.south_west,
    };
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 66,
        height: 56,
        decoration: BoxDecoration(
          color: _cream,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x294D412E),
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: enabled ? _ink : _ink.withValues(alpha: 0.35)),
            if (enabled)
              Image.asset(
                valid ? GameAssets.indicatorValid : GameAssets.indicatorInvalid,
                width: 20,
                height: 20,
              ),
          ],
        ),
      ),
    );
  }
}

String _starsText(int value) => value == 0
    ? '☆☆☆'
    : '${List.filled(value, '⭐').join()}${List.filled(3 - value, '☆').join()}';
