import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' show Colors;

import '../core/constants/game_assets.dart';
import '../core/models/game_models.dart';

class TacticGoalGame extends FlameGame {
  TacticGoalGame({required this.level, required this.onGoal});

  final LevelModel level;
  final VoidCallback onGoal;

  static const double _tileWidth = 62;
  static const double _tileHeight = 44;
  static const double _elevationHeight = 18;

  late final SpriteComponent _ball;
  late final SpriteComponent _shadow;
  final List<SpriteComponent> _guides = [];
  bool _loaded = false;

  static const _allImages = <String>[
    GameAssets.tileGrassLight,
    GameAssets.tileGrassDark,
    GameAssets.tileMud,
    GameAssets.tileIce,
    GameAssets.tileRampNe,
    GameAssets.tileRampNw,
    GameAssets.tileRampSe,
    GameAssets.tileRampSw,
    GameAssets.tileTargetZone,
    GameAssets.ball,
    GameAssets.ballShadow,
    GameAssets.teammate,
    GameAssets.defender,
    GameAssets.goalkeeper,
    GameAssets.goalFront,
    GameAssets.obstacleCone,
    GameAssets.obstacleBarrier,
    GameAssets.arrowGuide,
    GameAssets.indicatorValid,
    GameAssets.indicatorInvalid,
  ];

  String _relative(String path) => path.replaceFirst('assets/images/', '');

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    for (final path in _allImages) {
      await images.load(_relative(path));
    }

    for (var y = 0; y < level.height; y++) {
      for (var x = 0; x < level.width; x++) {
        final position = GridPosition(x, y);
        final tile = level.tileAt(position);
        final path = _tileImage(tile, position);
        final center = _screenPosition(position, tile.elevation);
        add(
          SpriteComponent(
            sprite: Sprite(images.fromCache(_relative(path))),
            position: center,
            size: Vector2(_tileWidth, _tileHeight),
            anchor: Anchor.center,
            priority: (x + y) * 10,
          ),
        );
        _addOccupant(tile, center, (x + y) * 10 + 3);
      }
    }

    final goalCenter = _screenPosition(level.goal, 0);
    add(
      SpriteComponent(
        sprite: Sprite(images.fromCache(_relative(GameAssets.goalFront))),
        position: goalCenter + Vector2(0, -14),
        size: Vector2(76, 76),
        anchor: Anchor.center,
        priority: (level.goal.x + level.goal.y) * 10 + 6,
      ),
    );
    _shadow = SpriteComponent(
      sprite: Sprite(images.fromCache(_relative(GameAssets.ballShadow))),
      size: Vector2(38, 20),
      anchor: Anchor.center,
      priority: 10000,
    );
    add(_shadow);
    _ball = SpriteComponent(
      sprite: Sprite(images.fromCache(_relative(GameAssets.ball))),
      size: Vector2.all(31),
      anchor: Anchor.center,
      priority: 10001,
    );
    add(_ball);
    _loaded = true;
    _placeBall(level.start);
  }

  String _tileImage(TileData tile, GridPosition position) {
    if (tile.rampDirection != null) {
      return switch (tile.rampDirection!) {
        GridDirection.northEast => GameAssets.tileRampNe,
        GridDirection.northWest => GameAssets.tileRampNw,
        GridDirection.southEast => GameAssets.tileRampSe,
        GridDirection.southWest => GameAssets.tileRampSw,
      };
    }
    return switch (tile.kind) {
      TileKind.mud => GameAssets.tileMud,
      TileKind.ice => GameAssets.tileIce,
      TileKind.goal => GameAssets.tileTargetZone,
      _ =>
        (position.x + position.y).isEven
            ? GameAssets.tileGrassLight
            : GameAssets.tileGrassDark,
    };
  }

  void _addOccupant(TileData tile, Vector2 center, int priority) {
    final path = switch (tile.kind) {
      TileKind.defender => GameAssets.defender,
      TileKind.teammate => GameAssets.teammate,
      TileKind.obstacle =>
        tile.position.x.isEven
            ? GameAssets.obstacleCone
            : GameAssets.obstacleBarrier,
      _ => null,
    };
    if (path == null) return;
    add(
      SpriteComponent(
        sprite: Sprite(images.fromCache(_relative(path))),
        position: center + Vector2(0, -18),
        size: Vector2.all(54),
        anchor: Anchor.center,
        priority: priority,
      ),
    );
  }

  Vector2 _screenPosition(GridPosition position, int elevation) {
    final rawX = (position.x - position.y) * _tileWidth / 2;
    final rawY = (position.x + position.y) * _tileHeight / 2;
    final minX = -(level.height - 1) * _tileWidth / 2;
    final maxX = (level.width - 1) * _tileWidth / 2;
    final minY = 0.0;
    final maxY = (level.width + level.height - 2) * _tileHeight / 2;
    return Vector2(
      rawX - (minX + maxX) / 2,
      rawY - (minY + maxY) / 2 - elevation * _elevationHeight,
    );
  }

  void _placeBall(GridPosition position, {double height = 0}) {
    if (!_loaded && !isLoaded) return;
    final screen = _screenPosition(position, 0);
    _shadow.position = screen + Vector2(0, 7);
    _ball.position = screen + Vector2(0, -height * 28 - 5);
  }

  Future<void> animateMove(MoveResult result) async {
    if (!result.isValid || !_loaded) return;
    clearGuides();
    await _shake();
    for (final step in result.steps) {
      _placeBall(step.to, height: step.height);
      if (step.bounced) {
        _burst(_ball.position, Colors.orangeAccent, count: 5);
      }
      await Future<void>.delayed(const Duration(milliseconds: 95));
    }
    _placeBall(result.position);
    _burst(
      _ball.position,
      result.scored ? Colors.amber : Colors.lightGreen,
      count: result.scored ? 24 : 8,
    );
    if (result.scored) {
      unawaited(_shake(strength: 8));
      onGoal();
    }
  }

  void resetBall() {
    if (_loaded) _placeBall(level.start);
  }

  void showGuides(Iterable<MoveResult> previews) {
    if (!_loaded) return;
    clearGuides();
    for (final preview in previews.where((result) => result.isValid)) {
      for (final step in preview.steps.where((step) => !step.bounced)) {
        final angle = switch (step.direction) {
          GridDirection.northEast => 0.0,
          GridDirection.southEast => math.pi / 2,
          GridDirection.southWest => math.pi,
          GridDirection.northWest => -math.pi / 2,
        };
        final guide = SpriteComponent(
          sprite: Sprite(images.fromCache(_relative(GameAssets.arrowGuide))),
          position: _screenPosition(step.to, 0) + Vector2(0, -10),
          size: Vector2.all(28),
          angle: angle,
          anchor: Anchor.center,
          priority: 9000,
        );
        _guides.add(guide);
        add(guide);
      }
    }
  }

  void clearGuides() {
    for (final guide in _guides) {
      guide.removeFromParent();
    }
    _guides.clear();
  }

  Future<void> _shake({double strength = 3}) async {
    final original = camera.viewfinder.position.clone();
    for (var i = 0; i < 4; i++) {
      camera.viewfinder.position =
          original + Vector2((i.isEven ? 1 : -1) * strength, 0);
      await Future<void>.delayed(const Duration(milliseconds: 18));
    }
    camera.viewfinder.position = original;
  }

  void _burst(Vector2 origin, Color color, {required int count}) {
    for (var i = 0; i < count; i++) {
      final angle = i * 2.399963;
      final speed = 26 + (i % 5) * 9;
      world.add(
        _BurstParticle(
          position: origin.clone(),
          velocity: Vector2(
            math.cos(angle) * speed,
            math.sin(angle) * speed - 18,
          ),
          color: i.isEven ? color : Colors.white,
          radius: 2.5 + (i % 3),
        ),
      );
    }
  }
}

class _BurstParticle extends PositionComponent {
  _BurstParticle({
    required super.position,
    required this.velocity,
    required this.color,
    required this.radius,
  });

  final Vector2 velocity;
  final Color color;
  final double radius;
  double _age = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    position += velocity * dt;
    velocity.y += 52 * dt;
    if (_age >= 0.65) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final alpha = (255 * (1 - (_age / 0.65))).round().clamp(0, 255);
    final paint = Paint()..color = color.withAlpha(alpha);
    canvas.drawCircle(Offset.zero, radius * (1 - _age * 0.35), paint);
  }
}
