import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/i18n/fhir_r4_encounter_copy.dart';
import '../../core/theme/paper_theme.dart';
import '../../domain/entities/fhir_r4_encounter_import_preview.dart';
import '../../domain/usecases/fhir_r4_encounter_import_mapper.dart';

/// Local source preview. Input remains in this page's memory.
class FhirR4EncounterImportPage extends StatefulWidget {
  const FhirR4EncounterImportPage({super.key, required this.localeTag});

  final String localeTag;

  @override
  State<FhirR4EncounterImportPage> createState() =>
      _FhirR4EncounterImportPageState();
}

class _FhirR4EncounterImportPageState extends State<FhirR4EncounterImportPage> {
  final _version = TextEditingController(text: '4.0.1');
  final _jurisdiction = TextEditingController();
  final _patient = TextEditingController();
  final _json = TextEditingController();
  FhirR4EncounterImportPreview? _preview;
  String? _error;

  String _text(String key, [Map<String, String> params = const {}]) =>
      fhirR4EncounterCopy(key, localeTag: widget.localeTag, params: params);

  @override
  void dispose() {
    _version.dispose();
    _jurisdiction.dispose();
    _patient.dispose();
    _json.dispose();
    super.dispose();
  }

  void _invalidate(String _) {
    if (_preview == null && _error == null) return;
    setState(() {
      _preview = null;
      _error = null;
    });
  }

  void _loadExample() {
    _version.text = '4.0.1';
    _jurisdiction.text = 'CA';
    _patient.text = 'Patient/synthetic-1';
    _json.text = const JsonEncoder.withIndent('  ').convert({
      'resourceType': 'Encounter',
      'id': 'synthetic-encounter-1',
      'status': 'finished',
      'class': {
        'system': 'https://example.org/synthetic-encounter-class',
        'code': 'demo',
        'display': 'Synthetic setting',
      },
      'subject': {'reference': 'Patient/synthetic-1'},
      'period': {'start': '2026-09-20T10:00:00-04:00', 'end': '2026-09-20'},
    });
    setState(() {
      _preview = null;
      _error = null;
    });
  }

  void _clear() {
    _version.text = '4.0.1';
    _jurisdiction.clear();
    _patient.clear();
    _json.clear();
    setState(() {
      _preview = null;
      _error = null;
    });
  }

  void _runPreview() {
    final input = _json.text;
    if (input.trim().isEmpty) {
      setState(() {
        _preview = null;
        _error = _text('error.empty');
      });
      return;
    }
    try {
      final preview = const FhirR4EncounterImportMapper().previewJson(
        input: input,
        context: FhirR4EncounterImportContext(
          fhirVersion: _version.text.trim(),
          jurisdiction: _jurisdiction.text.trim().toUpperCase(),
          expectedPatientReference: _patient.text.trim(),
        ),
      );
      setState(() {
        _preview = preview;
        _error = null;
      });
      debugPrint(
        '[FhirR4EncounterImport] preview_complete '
        'entries=${preview.entries.length} held=${preview.heldEntryCount} '
        'reasons=${preview.reasonCodes.length}',
      );
    } on FormatException {
      setState(() {
        _preview = null;
        _error = _text('error.invalidJson');
      });
      debugPrint('[FhirR4EncounterImport] preview_rejected format');
    } on Object {
      setState(() {
        _preview = null;
        _error = _text('error.generic');
      });
      debugPrint('[FhirR4EncounterImport] preview_rejected unexpected');
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface.withAlpha(255),
      appBar: PaperAppBar(title: Text(_text('title'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          PaperCard(
            padding: const EdgeInsets.all(16),
            child: Text(_text('boundary')),
          ),
          const SizedBox(height: 12),
          PaperCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _field(
                  key: const Key('fhir-encounter-version'),
                  controller: _version,
                  label: _text('field.fhirRelease'),
                  onChanged: _invalidate,
                ),
                _field(
                  key: const Key('fhir-encounter-jurisdiction'),
                  controller: _jurisdiction,
                  label: _text('field.jurisdiction'),
                  onChanged: _invalidate,
                ),
                _field(
                  key: const Key('fhir-encounter-patient'),
                  controller: _patient,
                  label: _text('field.patient'),
                  onChanged: _invalidate,
                ),
                _field(
                  key: const Key('fhir-encounter-json'),
                  controller: _json,
                  label: _text('field.json'),
                  maxLength: FhirR4EncounterImportPreview.maximumInputBytes,
                  minLines: 8,
                  maxLines: 20,
                  onChanged: _invalidate,
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      key: const Key('fhir-encounter-import-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      key: const Key('fhir-encounter-load-example'),
                      onPressed: _loadExample,
                      icon: const Icon(Icons.science_outlined),
                      label: Text(_text('action.loadExample')),
                    ),
                    FilledButton.icon(
                      key: const Key('fhir-encounter-run-preview'),
                      onPressed: _runPreview,
                      icon: const Icon(Icons.preview_outlined),
                      label: Text(_text('action.preview')),
                    ),
                    OutlinedButton(
                      key: const Key('fhir-encounter-clear'),
                      onPressed: _clear,
                      child: Text(_text('action.clear')),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (preview != null) ...[
            const SizedBox(height: 12),
            PaperCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _text('result.title'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _text('result.count', {
                      'container': preview.containerType,
                      'entries': '${preview.entries.length}',
                      'held': '${preview.heldEntryCount}',
                    }),
                  ),
                  const SizedBox(height: 12),
                  for (var index = 0; index < preview.entries.length; index++)
                    _EncounterEntryCard(
                      localeTag: widget.localeTag,
                      index: index,
                      entry: preview.entries[index],
                    ),
                  if (preview.reasonCodes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(_text('result.reasons')),
                    for (final reason in preview.reasonCodes)
                      Text(
                        '• $reason',
                        key: Key('fhir-encounter-reason-$reason'),
                      ),
                  ],
                  if (preview.unmappedPaths.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(_text('result.unprojectedPaths')),
                    for (final path in preview.unmappedPaths) Text('• $path'),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _field({
    required Key key,
    required TextEditingController controller,
    required String label,
    required ValueChanged<String> onChanged,
    int? maxLength,
    int minLines = 1,
    int maxLines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      key: key,
      controller: controller,
      onChanged: onChanged,
      maxLength: maxLength,
      minLines: minLines,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        alignLabelWithHint: maxLines > 1,
      ),
    ),
  );
}

class _EncounterEntryCard extends StatelessWidget {
  const _EncounterEntryCard({
    required this.localeTag,
    required this.index,
    required this.entry,
  });

  final String localeTag;
  final int index;
  final FhirR4EncounterEntryPreview entry;

  String _text(String key, [Map<String, String> params = const {}]) =>
      fhirR4EncounterCopy(key, localeTag: localeTag, params: params);

  @override
  Widget build(BuildContext context) {
    final coding = entry.encounterClass;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PaperCard(
        key: Key('fhir-encounter-entry-$index'),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _text('entry.title', {
                'index': '${index + 1}',
                'state': _text(
                  entry.previewable ? 'entry.previewable' : 'entry.held',
                ),
              }),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text('${_text('entry.sourceStatus')}: ${entry.status ?? '—'}'),
            Text(
              '${_text('entry.classSourceCode')}: '
              '${coding?.code ?? '—'} · ${coding?.system ?? '—'}',
            ),
            if (coding?.display != null)
              Text('${_text('entry.sourceDisplay')}: ${coding!.display}'),
            Text(
              '${_text('entry.patientMatch')}: '
              '${_text(entry.patientReferenceMatched ? 'entry.yes' : 'entry.no')}',
            ),
            if (entry.periodStart != null)
              Text(
                '${_text('entry.periodStart')}: ${entry.periodStart!.lexical}',
              ),
            if (entry.periodEnd != null)
              Text('${_text('entry.periodEnd')}: ${entry.periodEnd!.lexical}'),
            if (entry.reasonCodes.isNotEmpty) ...[
              const SizedBox(height: 6),
              for (final reason in entry.reasonCodes) Text('• $reason'),
            ],
          ],
        ),
      ),
    );
  }
}
