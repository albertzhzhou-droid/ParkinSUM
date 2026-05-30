import '../entities/label_section_code.dart';

/// Deterministic, conservative mapper from a CDSS/SPL label-section key (and
/// optional title) to a **LOINC document-section code**.
///
/// Educational/research prototype only. Mapping rules:
/// - Only well-known, stable FDA SPL section headings are mapped (codes verified
///   against loinc.org / FDA "Section Headings (LOINC)").
/// - An unrecognized or ambiguous key/title returns `unknown` (no LOINC code) —
///   codes are **never guessed**.
/// - The original section key is always preserved; the source section identity
///   is never overwritten.
/// - This is provenance/traceability only; a missing LOINC code does not
///   invalidate section provenance and is not clinical decision logic.
class LabelSectionCodeMapper {
  const LabelSectionCodeMapper();

  /// Source citation for the LOINC section-code terminology (see Bibliographies
  /// `src.fda.spl.standard`).
  static const String _loincSourceRef = 'src.fda.spl.standard';

  static const String _mappedLimitation =
      'LOINC section code mapped from a known, stable FDA SPL section heading. '
      'Provenance/traceability only; not clinical decision logic. The original '
      'section key is preserved.';

  static const String _unknownLimitation =
      'No stable LOINC mapping for this section key/title; recorded as unknown '
      '(not guessed). Missing LOINC does not invalidate section provenance.';

  /// Canonical normalized-key → (LOINC code, display) table. Keys are normalized
  /// via [_normalize]. Values are verified FDA SPL document-section codes.
  static const Map<String, List<String>> _codeTable = {
    'indications and usage': ['34067-9', 'Indications and usage'],
    'dosage and administration': ['34068-7', 'Dosage and administration'],
    'contraindications': ['34070-3', 'Contraindications'],
    'warnings and precautions': ['43685-7', 'Warnings and precautions'],
    'drug interactions': ['34073-7', 'Drug interactions'],
    'clinical pharmacology': ['34090-1', 'Clinical pharmacology'],
    'description': ['34089-3', 'Description'],
    'how supplied': ['34069-5', 'How supplied/storage and handling'],
    'how supplied storage and handling': [
      '34069-5',
      'How supplied/storage and handling'
    ],
    'adverse reactions': ['34084-4', 'Adverse reactions'],
  };

  /// A small set of common synonyms → canonical normalized key. Conservative on
  /// purpose: only unambiguous aliases are included.
  static const Map<String, String> _synonyms = {
    'indications': 'indications and usage',
    'indications usage': 'indications and usage',
    'dosage administration': 'dosage and administration',
    'dosage and admin': 'dosage and administration',
    'warnings precautions': 'warnings and precautions',
    'warnings and precaution': 'warnings and precautions',
    'drug interaction': 'drug interactions',
    'storage and handling': 'how supplied storage and handling',
    'how supplied storage': 'how supplied storage and handling',
    'adverse reaction': 'adverse reactions',
  };

  LabelSectionCode map({required String sectionKey, String? sectionTitle}) {
    final candidates = <String>[
      _normalize(sectionKey),
      if (sectionTitle != null) _normalize(sectionTitle),
    ].where((c) => c.isNotEmpty).toList(growable: false);

    for (final c in candidates) {
      final canonical = _codeTable.containsKey(c) ? c : _synonyms[c];
      final hit = canonical == null ? null : _codeTable[canonical];
      if (hit != null) {
        return LabelSectionCode(
          sourceSectionKey: sectionKey,
          sectionTitle: sectionTitle,
          loincCode: hit[0],
          loincDisplay: hit[1],
          mappingConfidence: SectionCodeMappingConfidence.mapped,
          sourceRefs: const [_loincSourceRef],
          limitationText: _mappedLimitation,
        );
      }
    }

    return LabelSectionCode(
      sourceSectionKey: sectionKey,
      sectionTitle: sectionTitle,
      loincCode: null,
      loincDisplay: null,
      mappingConfidence: SectionCodeMappingConfidence.unknown,
      sourceRefs: const [],
      limitationText: _unknownLimitation,
    );
  }

  /// Normalize a key/title: lowercase, replace separators with spaces, drop
  /// non-alphanumerics, collapse whitespace. Deterministic.
  static String _normalize(String raw) {
    final lowered = raw.toLowerCase().trim();
    final spaced = lowered.replaceAll(RegExp(r'[_\-/&,.]+'), ' ');
    final alnum = spaced.replaceAll(RegExp(r'[^a-z0-9 ]+'), ' ');
    return alnum.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
