import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tactic_goal/core/engine/movement_solver.dart';
import 'package:tactic_goal/core/models/game_models.dart';

void main() {
  const solver = MovementSolver();

  LevelModel level({
    GridPosition start = const GridPosition(1, 1),
    GridPosition goal = const GridPosition(5, 5),
    List<TileData> tiles = const [],
    List<ActionCard> cards = const [
      ActionCard(type: ActionType.pass, power: 2),
    ],
    int width = 6,
    int height = 6,
  }) => LevelModel(
    id: 'test',
    title: 'Test',
    width: width,
    height: height,
    start: start,
    goal: goal,
    cards: cards,
    tiles: {for (final tile in tiles) tile.position: tile},
  );

  test('pass advances the requested number of cells', () {
    final board = level();
    final result = solver.solve(
      level: board,
      start: board.start,
      card: board.cards.single,
      direction: GridDirection.southEast,
    );

    expect(result.isValid, isTrue);
    expect(result.position, const GridPosition(3, 1));
    expect(result.steps, hasLength(2));
  });

  test('leaving the board invalidates the move and restores its start', () {
    final board = level(
      start: const GridPosition(5, 0),
      cards: const [ActionCard(type: ActionType.pass, power: 2)],
    );
    final result = solver.solve(
      level: board,
      start: board.start,
      card: board.cards.single,
      direction: GridDirection.southEast,
    );

    expect(result.isValid, isFalse);
    expect(result.position, board.start);
  });

  test('mud stops the ball and ice adds one sliding cell', () {
    final mudBoard = level(
      tiles: const [TileData(position: GridPosition(2, 1), kind: TileKind.mud)],
      cards: const [ActionCard(type: ActionType.pass, power: 4)],
    );
    final mudResult = solver.solve(
      level: mudBoard,
      start: mudBoard.start,
      card: mudBoard.cards.single,
      direction: GridDirection.southEast,
    );
    expect(mudResult.position, const GridPosition(2, 1));
    expect(mudResult.steps, hasLength(1));

    final iceBoard = level(
      tiles: const [TileData(position: GridPosition(2, 1), kind: TileKind.ice)],
      cards: const [ActionCard(type: ActionType.pass, power: 1)],
    );
    final iceResult = solver.solve(
      level: iceBoard,
      start: iceBoard.start,
      card: iceBoard.cards.single,
      direction: GridDirection.southEast,
    );
    expect(iceResult.position, const GridPosition(3, 1));
    expect(iceResult.steps, hasLength(2));
  });

  test('a ground collision reverses the remaining movement', () {
    final board = level(
      start: const GridPosition(3, 1),
      tiles: const [
        TileData(position: GridPosition(4, 1), kind: TileKind.defender),
      ],
      cards: const [ActionCard(type: ActionType.pass, power: 3)],
    );
    final result = solver.solve(
      level: board,
      start: board.start,
      card: board.cards.single,
      direction: GridDirection.southEast,
    );

    expect(result.isValid, isTrue);
    expect(result.blocked, isTrue);
    expect(result.position, const GridPosition(1, 1));
    expect(result.steps.first.bounced, isTrue);
  });

  test('lob crosses blockers and a curve changes direction halfway', () {
    final lobBoard = level(
      tiles: const [
        TileData(position: GridPosition(2, 1), kind: TileKind.obstacle),
        TileData(position: GridPosition(3, 1), kind: TileKind.defender),
      ],
      cards: const [ActionCard(type: ActionType.lob, power: 3)],
      goal: const GridPosition(4, 1),
    );
    final lobResult = solver.solve(
      level: lobBoard,
      start: lobBoard.start,
      card: lobBoard.cards.single,
      direction: GridDirection.southEast,
    );
    expect(lobResult.scored, isTrue);
    expect(lobResult.steps.any((step) => step.height > 0), isTrue);

    final curveBoard = level(
      start: const GridPosition(1, 2),
      goal: const GridPosition(2, 1),
      cards: const [ActionCard(type: ActionType.curve, power: 2)],
    );
    final curveResult = solver.solve(
      level: curveBoard,
      start: curveBoard.start,
      card: curveBoard.cards.single,
      direction: GridDirection.northEast,
    );
    expect(curveResult.scored, isTrue);
    expect(curveResult.steps.map((step) => step.direction), [
      GridDirection.northEast,
      GridDirection.southEast,
    ]);
  });

  test('a teammate redirects the ball using its pass direction', () {
    final board = level(
      tiles: const [
        TileData(
          position: GridPosition(2, 1),
          kind: TileKind.teammate,
          passDirection: GridDirection.northEast,
        ),
      ],
      cards: const [ActionCard(type: ActionType.pass, power: 1)],
    );
    final result = solver.solve(
      level: board,
      start: board.start,
      card: board.cards.single,
      direction: GridDirection.southEast,
    );

    expect(result.position, const GridPosition(2, 0));
    expect(result.steps.first.autoPass, isTrue);
  });

  test('all twenty generated levels have a Dart-side BFS solution', () async {
    final solver = const MovementSolver();
    for (var world = 1; world <= 2; world++) {
      for (var number = 1; number <= 10; number++) {
        final suffix = number.toString().padLeft(2, '0');
        final file = File('assets/levels/world_${world}_level_$suffix.json');
        final json =
            jsonDecode(await file.readAsString()) as Map<String, Object?>;
        final board = LevelModel.fromJson(json);
        expect(_hasSolution(board, solver), isTrue, reason: board.id);
      }
    }
  });
}

bool _hasSolution(LevelModel level, MovementSolver solver) {
  final queue = <_SearchState>[_SearchState(level.start, 0)];
  final visited = <String>{'${level.start.x},${level.start.y}:0'};
  for (var cursor = 0; cursor < queue.length; cursor++) {
    final current = queue[cursor];
    for (var cardIndex = 0; cardIndex < level.cards.length; cardIndex++) {
      final mask = 1 << cardIndex;
      if (current.usedMask & mask != 0) continue;
      for (final direction in GridDirection.values) {
        final result = solver.solve(
          level: level,
          start: current.position,
          card: level.cards[cardIndex],
          direction: direction,
        );
        if (!result.isValid) continue;
        if (result.scored || result.position == level.goal) return true;
        final nextMask = current.usedMask | mask;
        final key = '${result.position.x},${result.position.y}:$nextMask';
        if (visited.add(key)) {
          queue.add(_SearchState(result.position, nextMask));
        }
      }
    }
  }
  return false;
}

class _SearchState {
  const _SearchState(this.position, this.usedMask);

  final GridPosition position;
  final int usedMask;
}
