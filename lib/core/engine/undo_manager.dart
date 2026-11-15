class UndoManager<T> {
  final List<T> _history = <T>[];

  bool get canUndo => _history.isNotEmpty;
  int get length => _history.length;

  void push(T snapshot) => _history.add(snapshot);

  T? undo() => _history.isEmpty ? null : _history.removeLast();

  void clear() => _history.clear();
}
