import 'dart:math' as math;

/// Servicio de búsqueda fuzzy utilizando distancia de Levenshtein
///
/// Permite encontrar coincidencias aproximadas tolerando errores tipográficos,
/// caracteres faltantes o adicionales.
///
/// Uso:
/// ```dart
/// final results = FuzzySearch.search(
///   query: 'terma',  // Intención: "termo"
///   items: products,
///   getSearchableStrings: (p) => [p.name, p.code ?? '', p.barcode ?? ''],
/// );
/// ```
class FuzzySearch {
  /// Busca items con coincidencia fuzzy
  ///
  /// [query] - Término de búsqueda
  /// [items] - Lista de items a buscar
  /// [getSearchableStrings] - Función que extrae strings buscables del item
  /// [threshold] - Umbral de similitud (0.0-1.0), default 0.3 (30% similitud mínima)
  /// [limit] - Máximo de resultados a retornar
  static List<FuzzySearchResult<T>> search<T>({
    required String query,
    required List<T> items,
    required List<String> Function(T item) getSearchableStrings,
    double threshold = 0.3,
    int limit = 50,
  }) {
    if (query.isEmpty || items.isEmpty) return [];

    final queryLower = query.toLowerCase().trim();
    final results = <FuzzySearchResult<T>>[];

    for (final item in items) {
      final searchableStrings = getSearchableStrings(item);
      double bestScore = 0.0;
      String? matchedField;
      MatchType matchType = MatchType.fuzzy;

      for (final str in searchableStrings) {
        if (str.isEmpty) continue;

        final strLower = str.toLowerCase();

        // Coincidencia exacta (máxima prioridad)
        if (strLower == queryLower) {
          bestScore = 1.0;
          matchedField = str;
          matchType = MatchType.exact;
          break;
        }

        // Coincidencia por inicio (alta prioridad)
        if (strLower.startsWith(queryLower)) {
          final score = 0.9 + (queryLower.length / strLower.length) * 0.1;
          if (score > bestScore) {
            bestScore = score;
            matchedField = str;
            matchType = MatchType.startsWith;
          }
          continue;
        }

        // Coincidencia parcial (media prioridad)
        if (strLower.contains(queryLower)) {
          final score = 0.7 + (queryLower.length / strLower.length) * 0.2;
          if (score > bestScore) {
            bestScore = score;
            matchedField = str;
            matchType = MatchType.contains;
          }
          continue;
        }

        // Búsqueda fuzzy con Levenshtein
        final similarity = calculateSimilarity(queryLower, strLower);
        if (similarity > bestScore) {
          bestScore = similarity;
          matchedField = str;
          matchType = MatchType.fuzzy;
        }

        // También buscar por palabras individuales
        final words = strLower.split(RegExp(r'\s+'));
        for (final word in words) {
          if (word.startsWith(queryLower)) {
            final wordScore = 0.8 + (queryLower.length / word.length) * 0.1;
            if (wordScore > bestScore) {
              bestScore = wordScore;
              matchedField = str;
              matchType = MatchType.wordStartsWith;
            }
          }
        }
      }

      if (bestScore >= threshold) {
        results.add(FuzzySearchResult(
          item: item,
          score: bestScore,
          matchedField: matchedField,
          matchType: matchType,
        ));
      }
    }

    // Ordenar por score descendente
    results.sort((a, b) => b.score.compareTo(a.score));

    return results.take(limit).toList();
  }

  /// Calcula la similitud entre dos strings (0.0 a 1.0)
  static double calculateSimilarity(String s1, String s2) {
    if (s1.isEmpty && s2.isEmpty) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final distance = levenshteinDistance(s1, s2);
    final maxLength = math.max(s1.length, s2.length);

    return 1.0 - (distance / maxLength);
  }

  /// Calcula la distancia de Levenshtein entre dos strings
  ///
  /// Representa el número mínimo de operaciones (inserción, eliminación,
  /// sustitución) necesarias para transformar s1 en s2.
  static int levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    // Usar solo dos filas para optimizar memoria
    var previousRow = List<int>.generate(s2.length + 1, (i) => i);
    var currentRow = List<int>.filled(s2.length + 1, 0);

    for (var i = 0; i < s1.length; i++) {
      currentRow[0] = i + 1;

      for (var j = 0; j < s2.length; j++) {
        final cost = s1[i] == s2[j] ? 0 : 1;

        currentRow[j + 1] = [
          currentRow[j] + 1, // Inserción
          previousRow[j + 1] + 1, // Eliminación
          previousRow[j] + cost, // Sustitución
        ].reduce(math.min);
      }

      // Intercambiar filas
      final temp = previousRow;
      previousRow = currentRow;
      currentRow = temp;
    }

    return previousRow[s2.length];
  }

  /// Calcula similitud usando Jaro-Winkler (mejor para nombres cortos)
  static double jaroWinklerSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final jaroSim = _jaroSimilarity(s1, s2);

    // Prefijo común (máximo 4 caracteres)
    int prefixLength = 0;
    final maxPrefix = math.min(4, math.min(s1.length, s2.length));
    for (var i = 0; i < maxPrefix; i++) {
      if (s1[i] == s2[i]) {
        prefixLength++;
      } else {
        break;
      }
    }

    // Jaro-Winkler con factor de escala 0.1
    return jaroSim + (prefixLength * 0.1 * (1 - jaroSim));
  }

  static double _jaroSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;

    final len1 = s1.length;
    final len2 = s2.length;

    final matchDistance = (math.max(len1, len2) / 2 - 1).floor();
    final s1Matches = List<bool>.filled(len1, false);
    final s2Matches = List<bool>.filled(len2, false);

    int matches = 0;
    int transpositions = 0;

    for (var i = 0; i < len1; i++) {
      final start = math.max(0, i - matchDistance);
      final end = math.min(i + matchDistance + 1, len2);

      for (var j = start; j < end; j++) {
        if (s2Matches[j] || s1[i] != s2[j]) continue;
        s1Matches[i] = true;
        s2Matches[j] = true;
        matches++;
        break;
      }
    }

    if (matches == 0) return 0.0;

    var k = 0;
    for (var i = 0; i < len1; i++) {
      if (!s1Matches[i]) continue;
      while (!s2Matches[k]) {
        k++;
      }
      if (s1[i] != s2[k]) transpositions++;
      k++;
    }

    return (matches / len1 +
            matches / len2 +
            (matches - transpositions / 2) / matches) /
        3;
  }
}

/// Tipo de coincidencia encontrada
enum MatchType {
  /// Coincidencia exacta
  exact,

  /// El campo comienza con el query
  startsWith,

  /// Una palabra del campo comienza con el query
  wordStartsWith,

  /// El campo contiene el query
  contains,

  /// Coincidencia aproximada por distancia de edición
  fuzzy,
}

/// Resultado de búsqueda fuzzy
class FuzzySearchResult<T> {
  /// Item encontrado
  final T item;

  /// Score de similitud (0.0 a 1.0)
  final double score;

  /// Campo donde se encontró la coincidencia
  final String? matchedField;

  /// Tipo de coincidencia
  final MatchType matchType;

  const FuzzySearchResult({
    required this.item,
    required this.score,
    this.matchedField,
    this.matchType = MatchType.fuzzy,
  });

  /// Score como porcentaje (0-100)
  int get scorePercent => (score * 100).round();

  @override
  String toString() =>
      'FuzzySearchResult(score: $scorePercent%, type: $matchType, field: $matchedField)';
}

/// Extension para facilitar búsqueda en listas
extension FuzzySearchExtension<T> on List<T> {
  /// Busca con fuzzy matching
  List<FuzzySearchResult<T>> fuzzySearch({
    required String query,
    required List<String> Function(T item) getSearchableStrings,
    double threshold = 0.3,
    int limit = 50,
  }) {
    return FuzzySearch.search(
      query: query,
      items: this,
      getSearchableStrings: getSearchableStrings,
      threshold: threshold,
      limit: limit,
    );
  }

  /// Busca y retorna solo los items (sin score)
  List<T> fuzzySearchItems({
    required String query,
    required List<String> Function(T item) getSearchableStrings,
    double threshold = 0.3,
    int limit = 50,
  }) {
    return fuzzySearch(
      query: query,
      getSearchableStrings: getSearchableStrings,
      threshold: threshold,
      limit: limit,
    ).map((r) => r.item).toList();
  }
}
