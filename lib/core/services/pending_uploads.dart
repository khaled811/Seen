/// The uploads that are running right now (a document being sent for a
/// request), so that signing out can warn that it would cut them short
/// (Figma AUTH-14). In memory only; an upload registers itself for as long as it
/// runs, even when the screen that started it has been left.
class PendingUploads {
  final _active = <Object, ({String requestId, String referenceId})>{};

  /// Registers an upload; call the returned function when it ends (success or not).
  void Function() begin({required String requestId, required String referenceId}) {
    final token = Object();
    _active[token] = (requestId: requestId, referenceId: referenceId);
    return () => _active.remove(token);
  }

  /// The references of the requests being uploaded to, oldest first.
  List<String> get references => [for (final u in _active.values) u.referenceId];

  bool get isEmpty => _active.isEmpty;
}
