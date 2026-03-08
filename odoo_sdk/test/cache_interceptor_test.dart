import 'package:test/test.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

void main() {
  group('CacheRule', () {
    test('matches exact path', () {
      const rule = CacheRule(pattern: '/res.partner/search_read');
      expect(rule.matches('/res.partner/search_read'), true);
      expect(rule.matches('/res.partner/write'), false);
      expect(rule.matches('/sale.order/search_read'), false);
    });

    test('matches single wildcard', () {
      const rule = CacheRule(pattern: '/res.partner/*');
      expect(rule.matches('/res.partner/search_read'), true);
      expect(rule.matches('/res.partner/write'), true);
      expect(rule.matches('/res.partner/create'), true);
      expect(rule.matches('/sale.order/search_read'), false);
    });

    test('matches double wildcard', () {
      const rule = CacheRule(pattern: '/**/search_read');
      expect(rule.matches('/res.partner/search_read'), true);
      expect(rule.matches('/sale.order/search_read'), true);
      expect(rule.matches('/product.product/search_read'), true);
      expect(rule.matches('/res.partner/write'), false);
    });

    test('matches any path with double wildcard', () {
      const rule = CacheRule(pattern: '/**');
      expect(rule.matches('/res.partner/search_read'), true);
      expect(rule.matches('/anything'), true);
      expect(rule.matches('/a/b/c/d'), true);
    });

    test('default TTL is 5 minutes', () {
      const rule = CacheRule(pattern: '/test');
      expect(rule.ttl, const Duration(minutes: 5));
    });

    test('default methods include GET and POST', () {
      const rule = CacheRule(pattern: '/test');
      expect(rule.methods, contains('GET'));
      expect(rule.methods, contains('POST'));
    });

    test('cacheErrors defaults to false', () {
      const rule = CacheRule(pattern: '/test');
      expect(rule.cacheErrors, false);
    });

    test('custom TTL can be set', () {
      const rule = CacheRule(
        pattern: '/test',
        ttl: Duration(hours: 1),
      );
      expect(rule.ttl, const Duration(hours: 1));
    });
  });

  group('HttpCacheEntry', () {
    test('isExpired returns false for fresh entry', () {
      final now = DateTime.now();
      final entry = HttpCacheEntry(
        data: {'test': 'data'},
        headers: {},
        statusCode: 200,
        createdAt: now,
        expiresAt: now.add(const Duration(minutes: 5)),
      );
      expect(entry.isExpired, false);
    });

    test('isExpired returns true for expired entry', () {
      final now = DateTime.now();
      final entry = HttpCacheEntry(
        data: {'test': 'data'},
        headers: {},
        statusCode: 200,
        createdAt: now.subtract(const Duration(minutes: 10)),
        expiresAt: now.subtract(const Duration(minutes: 5)),
      );
      expect(entry.isExpired, true);
    });

    test('timeToLive returns positive duration for fresh entry', () {
      final now = DateTime.now();
      final entry = HttpCacheEntry(
        data: {'test': 'data'},
        headers: {},
        statusCode: 200,
        createdAt: now,
        expiresAt: now.add(const Duration(minutes: 5)),
      );
      expect(entry.timeToLive.inMinutes, greaterThanOrEqualTo(4));
    });

    test('age returns positive duration', () {
      final now = DateTime.now();
      final entry = HttpCacheEntry(
        data: {'test': 'data'},
        headers: {},
        statusCode: 200,
        createdAt: now.subtract(const Duration(minutes: 2)),
        expiresAt: now.add(const Duration(minutes: 3)),
      );
      expect(entry.age.inMinutes, greaterThanOrEqualTo(2));
    });

    test('stores ETag and Last-Modified', () {
      final entry = HttpCacheEntry(
        data: {},
        headers: {},
        statusCode: 200,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        etag: '"abc123"',
        lastModified: 'Wed, 21 Oct 2024 07:28:00 GMT',
      );
      expect(entry.etag, '"abc123"');
      expect(entry.lastModified, 'Wed, 21 Oct 2024 07:28:00 GMT');
    });
  });

  group('ResponseCache', () {
    late ResponseCache cache;

    setUp(() {
      cache = ResponseCache(maxEntries: 5);
    });

    test('get returns null for missing key', () {
      expect(cache.get('missing'), null);
    });

    test('put and get returns entry', () {
      final entry = HttpCacheEntry(
        data: {'test': 'data'},
        headers: {},
        statusCode: 200,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );
      cache.put('key1', entry);
      expect(cache.get('key1'), isNotNull);
      expect(cache.get('key1')!.data, {'test': 'data'});
    });

    test('get returns null for expired entry', () {
      final entry = HttpCacheEntry(
        data: {'test': 'data'},
        headers: {},
        statusCode: 200,
        createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
        expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      cache.put('expired', entry);
      expect(cache.get('expired'), null);
    });

    test('evicts oldest entries when at capacity', () {
      // Fill cache to capacity
      for (var i = 0; i < 5; i++) {
        final entry = HttpCacheEntry(
          data: i,
          headers: {},
          statusCode: 200,
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        );
        cache.put('key$i', entry);
      }

      // Add one more, should evict oldest
      final newEntry = HttpCacheEntry(
        data: 'new',
        headers: {},
        statusCode: 200,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );
      cache.put('newKey', newEntry);

      // First entry should be evicted
      expect(cache.get('key0'), null);
      // New entry should exist
      expect(cache.get('newKey'), isNotNull);
    });

    test('invalidate removes specific key', () {
      final entry = HttpCacheEntry(
        data: 'test',
        headers: {},
        statusCode: 200,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );
      cache.put('key1', entry);
      cache.put('key2', entry);

      cache.invalidate('key1');

      expect(cache.get('key1'), null);
      expect(cache.get('key2'), isNotNull);
    });

    test('invalidatePattern removes matching keys', () {
      final entry = HttpCacheEntry(
        data: 'test',
        headers: {},
        statusCode: 200,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );
      cache.put('POST:/res.partner/search_read:abc', entry);
      cache.put('POST:/res.partner/write:def', entry);
      cache.put('POST:/sale.order/search_read:ghi', entry);

      cache.invalidatePattern(r'/res\.partner/');

      expect(cache.get('POST:/res.partner/search_read:abc'), null);
      expect(cache.get('POST:/res.partner/write:def'), null);
      expect(cache.get('POST:/sale.order/search_read:ghi'), isNotNull);
    });

    test('clear removes all entries', () {
      final entry = HttpCacheEntry(
        data: 'test',
        headers: {},
        statusCode: 200,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );
      cache.put('key1', entry);
      cache.put('key2', entry);

      cache.clear();

      expect(cache.get('key1'), null);
      expect(cache.get('key2'), null);
      expect(cache.stats.entries, 0);
    });

    test('stats tracks hits and misses', () {
      final entry = HttpCacheEntry(
        data: 'test',
        headers: {},
        statusCode: 200,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );
      cache.put('key1', entry);

      // 2 hits
      cache.get('key1');
      cache.get('key1');
      // 3 misses
      cache.get('missing1');
      cache.get('missing2');
      cache.get('missing3');

      expect(cache.stats.hits, 2);
      expect(cache.stats.misses, 3);
      expect(cache.stats.hitRate, closeTo(40.0, 0.1));
    });

    test('resetStats clears counters but keeps entries', () {
      final entry = HttpCacheEntry(
        data: 'test',
        headers: {},
        statusCode: 200,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );
      cache.put('key1', entry);
      cache.get('key1');
      cache.get('missing');

      cache.resetStats();

      expect(cache.stats.hits, 0);
      expect(cache.stats.misses, 0);
      expect(cache.get('key1'), isNotNull); // Entry still exists
    });
  });

  group('CacheStats', () {
    test('hitRate calculates correctly', () {
      const stats = CacheStats(
        hits: 80,
        misses: 20,
        entries: 10,
        estimatedSizeBytes: 1024,
        evictions: 0,
        expirations: 0,
      );
      expect(stats.hitRate, 80.0);
    });

    test('hitRate is 0 when no requests', () {
      const stats = CacheStats(
        hits: 0,
        misses: 0,
        entries: 0,
        estimatedSizeBytes: 0,
        evictions: 0,
        expirations: 0,
      );
      expect(stats.hitRate, 0.0);
    });

    test('toString includes key metrics', () {
      const stats = CacheStats(
        hits: 100,
        misses: 50,
        entries: 25,
        estimatedSizeBytes: 10240,
        evictions: 5,
        expirations: 3,
      );
      final str = stats.toString();
      expect(str, contains('hits: 100'));
      expect(str, contains('misses: 50'));
      expect(str, contains('entries: 25'));
    });
  });

  group('CacheConfig', () {
    test('odooDefault preset has search_read rules', () {
      const config = CacheConfig.odooDefault;
      expect(config.rules.any((r) => r.pattern.contains('search_read')), true);
    });

    test('odooDefault preset caches fields_get for 1 hour', () {
      const config = CacheConfig.odooDefault;
      final fieldsGetRule = config.rules.firstWhere(
        (r) => r.pattern.contains('fields_get'),
      );
      expect(fieldsGetRule.ttl, const Duration(hours: 1));
    });

    test('aggressive preset has longer TTL', () {
      const config = CacheConfig.aggressive;
      expect(config.maxEntries, 500);
      expect(config.rules.any((r) => r.ttl >= const Duration(minutes: 30)), true);
    });

    test('minimal preset has fewer entries', () {
      const config = CacheConfig.minimal;
      expect(config.maxEntries, 50);
    });

    test('useConditionalRequests defaults to true', () {
      const config = CacheConfig();
      expect(config.useConditionalRequests, true);
    });
  });
}
