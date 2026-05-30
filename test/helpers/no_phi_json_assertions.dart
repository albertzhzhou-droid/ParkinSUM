/// Shared, recursive **key-level** no-PHI / no-clinical-care assertions for the
/// local FHIR-inspired views and the local evidence-trace bundle.
///
/// Educational/research prototype only. These helpers assert that serialized
/// JSON never emits patient-linkage or clinical-workflow *keys*. They are
/// deliberately key-level: a safety-policy *value* such as `subject_omitted_no_phi`
/// or `no_patient_no_administration_no_phi` names what is omitted and must be
/// allowed — a naive substring ban over the whole JSON would wrongly fail on it.
library;

import 'package:flutter_test/flutter_test.dart';

/// Patient-linkage / clinical-care / workflow keys that must never appear as a
/// JSON key (compared lowercased). Covers FHIR patient-centric and
/// medication-workflow semantics across all local views/bundles.
const Set<String> kForbiddenPhiKeys = {
  'patient',
  'patient_id',
  'patientidentifier',
  'patient_identifier',
  'subject',
  'encounter',
  'practitioner',
  'careteam',
  'care_team',
  'diagnosis',
  'treatment',
  'medicationrequest',
  'medication_request',
  'medicationadministration',
  'medication_administration',
  'dosageinstruction',
  'dosage_instruction',
  'timing',
  'recommendation',
  'prescription',
};

/// Keys whose string values are allowed to carry safety/policy/provenance
/// wording without being scanned for banned medical-advice phrases.
const Set<String> kSafetyCopyKeys = {
  'phi_policy',
  'safety_boundary',
  'not_advice_text',
  'conformance_status',
  'view_type',
  'bundle_type',
  'limitation_text',
  'provenance_summary',
};

/// Recursively assert no forbidden patient-linkage / clinical-care key appears
/// anywhere in [node]. Pass [extraForbiddenKeys] to add artifact-specific bans
/// (e.g. `resourceType` / `bundle` for the non-FHIR evidence bundle).
void scanNoPhiKeys(Object? node, {Set<String> extraForbiddenKeys = const {}}) {
  final forbidden = {
    ...kForbiddenPhiKeys,
    ...extraForbiddenKeys.map((e) => e.toLowerCase()),
  };
  void walk(Object? n) {
    if (n is Map) {
      for (final entry in n.entries) {
        final key = entry.key.toString().toLowerCase();
        expect(forbidden.contains(key), isFalse,
            reason: 'forbidden patient-linkage/clinical-care key present: '
                '${entry.key}');
        walk(entry.value);
      }
    } else if (n is List) {
      for (final e in n) {
        walk(e);
      }
    }
  }

  walk(node);
}

/// Collect free-text string values for a banned-medical-advice-phrase scan,
/// skipping known safety/policy fields (plus any [skipKeys]).
List<String> collectFreeTextValues(Object? node,
    {Set<String> skipKeys = const {}}) {
  final skip = {...kSafetyCopyKeys, ...skipKeys};
  final out = <String>[];
  void walk(Object? n) {
    if (n is Map) {
      for (final e in n.entries) {
        if (skip.contains(e.key.toString())) continue;
        walk(e.value);
      }
    } else if (n is List) {
      for (final e in n) {
        walk(e);
      }
    } else if (n is String) {
      out.add(n);
    }
  }

  walk(node);
  return out;
}
