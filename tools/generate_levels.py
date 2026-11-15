import json
from collections import deque
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LEVEL_DIR = ROOT / "assets" / "levels"
DIRECTIONS = {
    "northEast": (0, -1),
    "northWest": (-1, 0),
    "southEast": (1, 0),
    "southWest": (0, 1),
}

SPECS = [
    ((1, 3), (3, 3), [("pass", 2)], []),
    ((4, 4), (2, 4), [("shoot", 2)], []),
    ((1, 1), (4, 1), [("pass", 3)], [("obstacle", 1, 4)]),
    ((4, 4), (4, 1), [("shoot", 3)], [("mud", 2, 3)]),
    ((1, 3), (4, 3), [("shoot", 3), ("curve", 2)], [("obstacle", 2, 1)]),
    ((4, 2), (4, 4), [("pass", 2)], [("ice", 2, 2)]),
    ((4, 5), (1, 5), [("pass", 3), ("lob", 2)], [("defender", 4, 3)]),
    ((2, 4), (2, 1), [("lob", 3)], [("obstacle", 2, 3), ("defender", 2, 2)]),
    ((0, 2), (1, 1), [("curve", 2)], [("obstacle", 3, 2)]),
    ((1, 1), (5, 1), [("shoot", 4)], [("mud", 1, 3), ("obstacle", 4, 3)]),
    ((0, 1), (2, 3), [("pass", 2), ("pass", 2)], []),
    ((5, 4), (3, 2), [("shoot", 2), ("pass", 2)], [("ice", 4, 4)]),
    ((0, 5), (2, 3), [("lob", 2), ("pass", 2)], [("obstacle", 1, 5), ("defender", 2, 4)]),
    ((1, 2), (4, 1), [("curve", 2), ("shoot", 2)], [("obstacle", 0, 2)]),
    ((1, 3), (3, 3), [("pass", 1)], [("ice", 2, 3)]),
    ((0, 0), (2, 2), [("shoot", 2), ("lob", 2)], [("defender", 1, 1)]),
    ((3, 3), (1, 3), [("shoot", 3)], [("obstacle", 4, 3)]),
    ((1, 2), (2, 3), [("pass", 2)], [("teammate", 2, 2, "southWest")]),
    ((1, 4), (3, 4), [("pass", 4)], [("mud", 3, 4)]),
    ((4, 4), (3, 5), [("curve", 2), ("shoot", 2)], [("defender", 5, 4)]),
]


def action(card):
    kind, power = card
    return {"type": kind, "power": power}


def tile_rows(spec, goal):
    result = []
    for entry in spec:
        kind, x, y, *extra = entry
        tile = {"kind": kind, "x": x, "y": y}
        if kind == "teammate":
            tile["passDirection"] = extra[0]
        if (x, y) == goal and kind != "goal":
            # A goal may share mud or ice; terrain behavior still applies.
            tile["goalOverlay"] = True
        result.append(tile)
    if not any((tile["x"], tile["y"]) == goal for tile in result):
        result.append({"kind": "goal", "x": goal[0], "y": goal[1]})
    return result


def simulate(level, start, card, direction):
    position = start
    current_direction = direction
    initial_direction = direction
    remaining = card["power"]
    ice_bonus = 0
    step_index = 0
    auto_passed = set()
    max_steps = level["width"] * level["height"] * 2 + card["power"] * 2
    special = {(t["x"], t["y"]): t for t in level["tiles"]}

    def tile(pos):
        x, y = pos
        if x < 0 or y < 0 or x >= level["width"] or y >= level["height"]:
            return {"kind": "empty", "elevation": 0}
        return special.get(pos, {"kind": "grass", "elevation": 0})

    for _ in range(max_steps):
        if remaining <= 0 and ice_bonus <= 0:
            return position, True
        if card["type"] == "curve" and step_index >= (card["power"] + 1) // 2:
            current_direction = clockwise(initial_direction)
        dx, dy = DIRECTIONS[current_direction]
        next_position = (position[0] + dx, position[1] + dy)
        current_tile, next_tile = tile(position), tile(next_position)
        if next_tile["kind"] == "empty":
            return start, False
        raised = next_tile.get("elevation", 0) > current_tile.get("elevation", 0)
        if raised and next_tile.get("rampDirection") != current_direction:
            raised = True
        else:
            raised = False
        blocker = next_tile["kind"] in ("defender", "obstacle")
        can_lob_over = card["type"] == "lob" and (
            blocker or next_tile.get("elevation", 0) <= current_tile.get("elevation", 0) + 1
        )
        if (blocker or raised) and not can_lob_over:
            current_direction = opposite(current_direction)
            if remaining:
                remaining -= 1
            elif ice_bonus:
                ice_bonus -= 1
            step_index += 1
            continue
        position = next_position
        if remaining:
            remaining -= 1
        elif ice_bonus:
            ice_bonus -= 1
        step_index += 1
        if position == tuple(level["goal"]) or next_tile["kind"] == "goal":
            return position, True
        if next_tile["kind"] == "mud":
            return position, True
        if next_tile["kind"] == "ice" and ice_bonus == 0:
            ice_bonus = 1
        if next_tile["kind"] == "teammate":
            if position in auto_passed:
                return position, True
            auto_passed.add(position)
            current_direction = next_tile.get("passDirection", current_direction)
            if remaining == 0 and ice_bonus == 0:
                remaining = card["power"]
    return position, False


def clockwise(direction):
    return {
        "northEast": "southEast",
        "southEast": "southWest",
        "southWest": "northWest",
        "northWest": "northEast",
    }[direction]


def opposite(direction):
    return {
        "northEast": "southWest",
        "southWest": "northEast",
        "northWest": "southEast",
        "southEast": "northWest",
    }[direction]


def bfs(level):
    cards = level["cards"]
    start = (level["start"]["x"], level["start"]["y"])
    goal = (level["goal"]["x"], level["goal"]["y"])
    queue = deque([(start, 0, [])])
    visited = {(start, 0)}
    while queue:
        position, used_mask, path = queue.popleft()
        if position == goal:
            return path
        for index, card in enumerate(cards):
            if used_mask & (1 << index):
                continue
            for direction in DIRECTIONS:
                destination, valid = simulate(level, position, card, direction)
                if not valid:
                    continue
                next_mask = used_mask | (1 << index)
                next_path = path + [{
                    "cardIndex": index,
                    "direction": direction,
                    "from": list(position),
                    "to": list(destination),
                }]
                if destination == goal:
                    return next_path
                state = (destination, next_mask)
                if state not in visited:
                    visited.add(state)
                    queue.append((destination, next_mask, next_path))
    return None


def build_level(index, spec):
    start, goal, card_specs, tile_specs = spec
    world = 1 if index < 10 else 2
    local_index = index + 1 if world == 1 else index - 9
    cards = [action(c) for c in card_specs]
    level = {
        "id": f"{world}-{local_index}",
        "title": f"{'Antrenman' if world == 1 else 'Amatör'} {local_index}",
        "world": world,
        "width": 6,
        "height": 6,
        "start": {"x": start[0], "y": start[1]},
        "goal": {"x": goal[0], "y": goal[1]},
        "threeStarMoves": len(cards),
        "twoStarMoves": len(cards) + 1,
        "cards": cards,
        "tiles": tile_rows(tile_specs, goal),
    }
    return level


def main():
    LEVEL_DIR.mkdir(parents=True, exist_ok=True)
    levels = [build_level(i, spec) for i, spec in enumerate(SPECS)]
    for i, level in enumerate(levels):
        solution = bfs(level)
        if solution is None:
            raise SystemExit(f"Level {level['id']} is not solvable")
        level["verifiedSolutionLength"] = len(solution)
        level["threeStarMoves"] = len(solution)
        level["twoStarMoves"] = len(solution) + 1
        filename = f"world_{level['world']}_level_{(i % 10) + 1:02}.json"
        (LEVEL_DIR / filename).write_text(
            json.dumps(level, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
        print(f"Verified {level['id']} ({filename}): {solution}")
    print(f"Generated and BFS-validated {len(levels)} levels.")


if __name__ == "__main__":
    main()
