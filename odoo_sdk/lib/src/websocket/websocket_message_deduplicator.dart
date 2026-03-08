/// Internal message deduplication for OdooWebSocketService.
///
/// Tracks processed message hashes to prevent duplicate processing.
library;

/// Deduplicates WebSocket messages using a bounded hash set.
class WebSocketMessageDeduplicator {
  final Set<String> _processedMessages = {};
  final int _maxCache;

  WebSocketMessageDeduplicator({int maxCache = 100}) : _maxCache = maxCache;

  /// Returns true if this message was already processed.
  ///
  /// If the message is new, it is added to the cache.
  /// Old entries are evicted when the cache exceeds [_maxCache].
  bool isDuplicate(dynamic message) {
    final messageStr = message.toString();
    final messageHash = messageStr.hashCode.toString();

    if (_processedMessages.contains(messageHash)) {
      return true;
    }

    _processedMessages.add(messageHash);

    if (_processedMessages.length > _maxCache) {
      final messagesToRemove = _processedMessages.take(
        _processedMessages.length - _maxCache,
      );
      _processedMessages.removeAll(messagesToRemove);
    }

    return false;
  }
}
