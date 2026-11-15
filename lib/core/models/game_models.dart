enum TileKind { grass, mud, ice, goal, defender, teammate, obstacle, empty }

enum ActionType { pass, shoot, lob, curve }

enum GridDirection {
  northEast(0, -1),
  northWest(-1, 0),
  southEast(1, 0),
  southWest(0, 1);

  const GridDirection(this.dx, this.dy);

  final int dx;
  final int dy;

  GridDirection get opposite => switch (this) {
    northEast => southWest,
    southWest => northEast,
    northWest => southEast,
    southEast => northWest,
  };

  GridDirection get clockwise => switch (this) {
    northEast => southEast,
    southEast => southWest,
    southWest => northWest,
    northWest => northEast,
  };

  static GridDirection? tryParse(Object? value) {
    if (value is! String) return null;
    for (final direction in GridDirection.values) {
      if (direction.name == value) return direction;
    }
    return null;
  }
}

class GridPosition {
  const GridPosition(this.x, this.y);

  final int x;
  final int y;

  GridPosition step(GridDirection direction) =>
      GridPosition(x + direction.dx, y + direction.dy);

  @override
  bool operator ==(Object other) =>
      other is GridPosition && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '($x,$y)';
}

class TileData {
  const TileData({
    required this.position,
    this.kind = TileKind.grass,
    this.elevation = 0,
    this.rampDirection,
    this.passDirection,
  });

  final GridPosition position;
  final TileKind kind;
  final int elevation;
  final GridDirection? rampDirection;
  final GridDirection? passDirection;

  factory TileData.fromJson(Map<String, Object?> json) => TileData(
    position: GridPosition(json['x']! as int, json['y']! as int),
    kind: TileKind.values.firstWhere(
      (kind) => kind.name == json['kind'],
      orElse: () => TileKind.grass,
    ),
    elevation: (json['elevation'] as int?) ?? 0,
    rampDirection: GridDirection.tryParse(json['rampDirection']),
    passDirection: GridDirection.tryParse(json['passDirection']),
  );
}

class ActionCard {
  const ActionCard({required this.type, required this.power});

  final ActionType type;
  final int power;

  factory ActionCard.fromJson(Map<String, Object?> json) => ActionCard(
    type: ActionType.values.firstWhere((type) => type.name == json['type']),
    power: json['power']! as int,
  );
}

class MoveStep {
  const MoveStep({
    required this.from,
    required this.to,
    required this.direction,
    this.height = 0,
    this.bounced = false,
    this.autoPass = false,
  });

  final GridPosition from;
  final GridPosition to;
  final GridDirection direction;
  final double height;
  final bool bounced;
  final bool autoPass;
}

class MoveResult {
  const MoveResult({
    required this.start,
    required this.position,
    required this.steps,
    required this.isValid,
    required this.scored,
    this.blocked = false,
  });

  final GridPosition start;
  final GridPosition position;
  final List<MoveStep> steps;
  final bool isValid;
  final bool scored;
  final bool blocked;
}

class LevelModel {
  LevelModel({
    required this.id,
    required this.title,
    required this.width,
    required this.height,
    required this.start,
    required this.goal,
    required this.cards,
    required this.tiles,
    this.world = 1,
    this.threeStarMoves = 1,
    this.twoStarMoves = 2,
  });

  final String id;
  final String title;
  final int width;
  final int height;
  final GridPosition start;
  final GridPosition goal;
  final int world;
  final int threeStarMoves;
  final int twoStarMoves;
  final List<ActionCard> cards;
  final Map<GridPosition, TileData> tiles;

  TileData tileAt(GridPosition position) {
    if (position.x < 0 ||
        position.y < 0 ||
        position.x >= width ||
        position.y >= height) {
      return TileData(position: position, kind: TileKind.empty);
    }
    return tiles[position] ?? TileData(position: position);
  }

  factory LevelModel.fromJson(Map<String, Object?> json) {
    final tiles = <GridPosition, TileData>{};
    for (final rawTile in json['tiles']! as List<Object?>) {
      final tile = TileData.fromJson(rawTile! as Map<String, Object?>);
      tiles[tile.position] = tile;
    }
    final startJson = json['start']! as Map<String, Object?>;
    final goalJson = json['goal']! as Map<String, Object?>;
    return LevelModel(
      id: json['id']! as String,
      title: json['title']! as String,
      width: json['width']! as int,
      height: json['height']! as int,
      start: GridPosition(startJson['x']! as int, startJson['y']! as int),
      goal: GridPosition(goalJson['x']! as int, goalJson['y']! as int),
      world: (json['world'] as int?) ?? 1,
      threeStarMoves: (json['threeStarMoves'] as int?) ?? 1,
      twoStarMoves: (json['twoStarMoves'] as int?) ?? 2,
      cards: (json['cards']! as List<Object?>)
          .map((card) => ActionCard.fromJson(card! as Map<String, Object?>))
          .toList(growable: false),
      tiles: tiles,
    );
  }
}
