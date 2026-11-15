import '../models/game_models.dart';

class MovementSolver {
  const MovementSolver();

  MoveResult solve({
    required LevelModel level,
    required GridPosition start,
    required ActionCard card,
    required GridDirection direction,
  }) {
    if (card.power <= 0) {
      return _invalid(start);
    }

    var position = start;
    var currentDirection = direction;
    final initialDirection = direction;
    final steps = <MoveStep>[];
    var remaining = card.power;
    var iceBonus = 0;
    var stepIndex = 0;
    var scored = false;
    var blocked = false;
    final autoPassedAt = <GridPosition>{};
    final maxSteps = level.width * level.height * 2 + card.power * 2;

    while ((remaining > 0 || iceBonus > 0) && stepIndex < maxSteps) {
      if (card.type == ActionType.curve &&
          stepIndex >= (card.power / 2).ceil()) {
        currentDirection = initialDirection.clockwise;
      }

      final next = position.step(currentDirection);
      final currentTile = level.tileAt(position);
      final nextTile = level.tileAt(next);
      if (nextTile.kind == TileKind.empty) {
        return _invalid(start);
      }

      final isRaised =
          nextTile.elevation > currentTile.elevation &&
          nextTile.rampDirection != currentDirection;
      final isSolidBlocker =
          nextTile.kind == TileKind.defender ||
          nextTile.kind == TileKind.obstacle;
      final canLobOver =
          card.type == ActionType.lob &&
          (isSolidBlocker || nextTile.elevation <= currentTile.elevation + 1);

      if ((isSolidBlocker || isRaised) && !canLobOver) {
        steps.add(
          MoveStep(
            from: position,
            to: position,
            direction: currentDirection,
            bounced: true,
          ),
        );
        currentDirection = currentDirection.opposite;
        blocked = true;
        if (remaining > 0) remaining--;
        if (iceBonus > 0) iceBonus--;
        stepIndex++;
        continue;
      }

      final from = position;
      position = next;
      final arcHeight = card.type == ActionType.lob
          ? 0.65 * (1 - ((stepIndex + 1) / (card.power + 1) - 0.5).abs() * 1.5)
          : card.type == ActionType.curve
          ? 0.12 * (stepIndex + 1)
          : 0.0;
      steps.add(
        MoveStep(
          from: from,
          to: position,
          direction: currentDirection,
          height: arcHeight.clamp(0, 0.65),
          autoPass: nextTile.kind == TileKind.teammate,
        ),
      );
      if (remaining > 0) {
        remaining--;
      } else {
        iceBonus--;
      }
      stepIndex++;

      if (nextTile.kind == TileKind.goal || position == level.goal) {
        scored = true;
        break;
      }
      if (nextTile.kind == TileKind.mud) {
        remaining = 0;
        iceBonus = 0;
        break;
      }
      if (nextTile.kind == TileKind.ice && iceBonus == 0) {
        iceBonus = 1;
      }
      if (nextTile.kind == TileKind.teammate) {
        if (!autoPassedAt.add(position)) {
          break;
        }
        currentDirection = nextTile.passDirection ?? currentDirection;
        if (remaining == 0 && iceBonus == 0) {
          remaining = card.power;
        }
      }
    }

    if (stepIndex >= maxSteps) {
      return _invalid(start);
    }
    return MoveResult(
      start: start,
      position: position,
      steps: List.unmodifiable(steps),
      isValid: steps.isNotEmpty,
      scored: scored,
      blocked: blocked,
    );
  }

  MoveResult _invalid(GridPosition start) => MoveResult(
    start: start,
    position: start,
    steps: const [],
    isValid: false,
    scored: false,
  );
}
