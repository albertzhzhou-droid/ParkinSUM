import 'dart:collection';

/// Immutable n-gram index for catalog type-ahead search.
///
/// Candidate lookup uses an inverted index; the final `contains` check keeps
/// results exact while avoiding a full catalog scan on every keystroke.
class CatalogSearchIndex<T> {
  final List<T> _items;
  final List<String> _normalizedText;
  final Map<String, Set<int>> _postings;

  CatalogSearchIndex({
    required Iterable<T> items,
    required String Function(T item) searchableText,
  }) : _items = List<T>.unmodifiable(items),
       _normalizedText = <String>[],
       _postings = <String, Set<int>>{} {
    for (var index = 0; index < _items.length; index++) {
      final text = normalizeCatalogSearchText(searchableText(_items[index]));
      _normalizedText.add(text);
      for (final gram in _grams(text)) {
        (_postings[gram] ??= <int>{}).add(index);
      }
    }
  }

  List<T> search(String query, {int? limit}) {
    final normalized = normalizeCatalogSearchText(query);
    if (normalized.isEmpty) {
      return List<T>.unmodifiable(limit == null ? _items : _items.take(limit));
    }

    final queryGrams = _grams(normalized).toList(growable: false)
      ..sort((a, b) {
        final size = (_postings[a]?.length ?? 0).compareTo(
          _postings[b]?.length ?? 0,
        );
        return size != 0 ? size : a.compareTo(b);
      });
    if (queryGrams.isEmpty) return List<T>.empty(growable: false);

    Set<int>? candidates;
    for (final gram in queryGrams) {
      final posting = _postings[gram];
      if (posting == null) return List<T>.empty(growable: false);
      candidates = candidates == null
          ? Set<int>.from(posting)
          : candidates.intersection(posting);
      if (candidates.isEmpty) return List<T>.empty(growable: false);
    }

    final ordered = SplayTreeSet<int>.from(candidates!);
    final results = <T>[];
    for (final index in ordered) {
      if (_normalizedText[index].contains(normalized)) {
        results.add(_items[index]);
        if (limit != null && results.length >= limit) break;
      }
    }
    return List<T>.unmodifiable(results);
  }
}

String normalizeCatalogSearchText(String value) {
  final lowered = value.toLowerCase();
  final buffer = StringBuffer();
  var previousWasSpace = true;
  for (final rune in lowered.runes) {
    final replacement = _foldedRune[rune] ?? String.fromCharCode(rune);
    for (final foldedRune in replacement.runes) {
      final isWord =
          (foldedRune >= 48 && foldedRune <= 57) ||
          (foldedRune >= 97 && foldedRune <= 122) ||
          foldedRune > 127;
      if (isWord) {
        buffer.writeCharCode(foldedRune);
        previousWasSpace = false;
      } else if (!previousWasSpace) {
        buffer.write(' ');
        previousWasSpace = true;
      }
    }
  }
  return buffer.toString().trim();
}

Iterable<String> _grams(String value) sync* {
  if (value.isEmpty) return;
  final runes = value.runes.toList(growable: false);
  final width = runes.length < 3 ? runes.length : 3;
  final emitted = <String>{};
  for (var index = 0; index <= runes.length - width; index++) {
    final gram = String.fromCharCodes(runes.sublist(index, index + width));
    if (emitted.add(gram)) yield gram;
  }
}

const Map<int, String> _foldedRune = <int, String>{
  0x00E0: 'a',
  0x00E1: 'a',
  0x00E2: 'a',
  0x00E3: 'a',
  0x00E4: 'a',
  0x00E5: 'a',
  0x00E6: 'ae',
  0x00E7: 'c',
  0x00E8: 'e',
  0x00E9: 'e',
  0x00EA: 'e',
  0x00EB: 'e',
  0x00EC: 'i',
  0x00ED: 'i',
  0x00EE: 'i',
  0x00EF: 'i',
  0x00F1: 'n',
  0x00F2: 'o',
  0x00F3: 'o',
  0x00F4: 'o',
  0x00F5: 'o',
  0x00F6: 'o',
  0x00F8: 'o',
  0x00F9: 'u',
  0x00FA: 'u',
  0x00FB: 'u',
  0x00FC: 'u',
  0x00FD: 'y',
  0x00FF: 'y',
  0x0153: 'oe',
  0x00DF: 'ss',
};
