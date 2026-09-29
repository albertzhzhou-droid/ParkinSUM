import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/i18n/app_i18n.dart';
import '../../domain/entities/personal_observation.dart';

/// Collects observations only. The owner supplies persistence and its outcome.
class ObservationEditor extends StatefulWidget {
  const ObservationEditor({
    super.key,
    required this.recorderId,
    required this.onSave,
    this.initialObservation,
    this.localeTag,
    this.now,
    this.idFactory,
  });

  final String recorderId;
  final Future<bool> Function(PersonalObservation) onSave;
  final PersonalObservation? initialObservation;
  final String? localeTag;
  final DateTime Function()? now;
  final String Function()? idFactory;

  @override
  State<ObservationEditor> createState() => _ObservationEditorState();
}

class _ObservationEditorState extends State<ObservationEditor> {
  final _form = GlobalKey<FormState>();
  final _label = TextEditingController();
  final _severity = TextEditingController();
  final _notes = TextEditingController();
  final _systolic = TextEditingController();
  final _diastolic = TextEditingController();
  late final TextEditingController _occurred;
  late final TextEditingController _timezone;
  late final String _id;
  late PersonalObservationKind _kind;
  late PersonalObservationSource _source;
  late PersonalObservationStatus _status;
  SelfReportedMotorState? _motorState;
  BloodPressurePosture _posture = BloodPressurePosture.unknown;
  bool _saving = false;
  String? _error;

  DateTime _now() => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    final initial = widget.initialObservation;
    final now = _now();
    _id =
        initial?.id ??
        widget.idFactory?.call() ??
        'observation_${now.microsecondsSinceEpoch}_${Random.secure().nextInt(0x100000000).toRadixString(16)}';
    _kind = initial?.kind ?? PersonalObservationKind.symptom;
    _source = initial?.source ?? PersonalObservationSource.selfReported;
    _status = initial?.status ?? PersonalObservationStatus.recorded;
    _label.text = initial?.symptomLabel ?? '';
    _severity.text = initial?.severity?.toString() ?? '';
    _notes.text = initial?.notes ?? '';
    _systolic.text = initial?.systolic?.toString() ?? '';
    _diastolic.text = initial?.diastolic?.toString() ?? '';
    _motorState = initial?.motorState;
    _posture = initial?.posture ?? BloodPressurePosture.unknown;
    _occurred = TextEditingController(
      text: initial?.occurredAt.toIso8601String() ?? _withOffset(now),
    );
    _timezone = TextEditingController(
      text: initial?.originalTimezone ?? 'UTC${_offset(now)}',
    );
  }

  static String _offset(DateTime value) {
    final minutes = value.timeZoneOffset.inMinutes;
    final absolute = minutes.abs();
    return '${minutes < 0 ? '-' : '+'}${(absolute ~/ 60).toString().padLeft(2, '0')}:${(absolute % 60).toString().padLeft(2, '0')}';
  }

  static String _withOffset(DateTime value) => value.isUtc
      ? value.toIso8601String()
      : '${value.toIso8601String()}${_offset(value)}';

  @override
  void dispose() {
    for (final controller in [
      _label,
      _severity,
      _notes,
      _systolic,
      _diastolic,
      _occurred,
      _timezone,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save(_ObservationCopy copy) async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final measured = _status == PersonalObservationStatus.recorded;
      final observation = PersonalObservation.create(
        id: _id,
        kind: _kind,
        occurredAt: PersonalObservation.parseExplicitTimestamp(
          _occurred.text.trim(),
        ),
        recordedAt: widget.initialObservation?.recordedAt ?? _now(),
        originalTimezone: _timezone.text.trim(),
        source: _source,
        recorderId: widget.initialObservation?.recorderId ?? widget.recorderId,
        status: _status,
        symptomLabel: _kind == PersonalObservationKind.symptom
            ? _label.text.trim()
            : null,
        severity:
            measured &&
                _kind == PersonalObservationKind.symptom &&
                _severity.text.trim().isNotEmpty
            ? int.parse(_severity.text.trim())
            : null,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        motorState:
            measured && _kind == PersonalObservationKind.selfReportedMotorState
            ? _motorState
            : null,
        systolic: measured && _kind == PersonalObservationKind.bloodPressure
            ? double.parse(_systolic.text.trim())
            : null,
        diastolic: measured && _kind == PersonalObservationKind.bloodPressure
            ? double.parse(_diastolic.text.trim())
            : null,
        unit: _kind == PersonalObservationKind.bloodPressure
            ? PersonalObservation.bloodPressureUnit
            : null,
        posture: _kind == PersonalObservationKind.bloodPressure
            ? _posture
            : null,
      );
      debugPrint('[ObservationEditor] save requested');
      final saved = await widget.onSave(observation);
      if (!mounted) return;
      if (saved) {
        debugPrint('[ObservationEditor] save committed');
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(copy.text('Saved', '已保存'))));
        }
      } else {
        setState(() => _error = copy.saveFailure);
      }
    } catch (_) {
      if (mounted) setState(() => _error = copy.saveFailure);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.fromLocaleTag(
      widget.localeTag ?? Localizations.localeOf(context).toLanguageTag(),
    );
    final copy = _ObservationCopy(i18n.languageFamily == 'zh');
    final measured = _status == PersonalObservationStatus.recorded;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface.withAlpha(255),
      appBar: AppBar(
        title: Text(
          widget.initialObservation == null
              ? copy.text('Add observation', '添加观察记录')
              : copy.text('Edit observation', '编辑观察记录'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Form(
              key: _form,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      copy.text(
                        'Record what you noticed or measured. Self-reported ON/OFF states are personal descriptions, not a diagnosis. These records do not change medication or meal recommendations.',
                        '记录你观察到或测量的情况。自报 ON/OFF 状态仅为个人描述，不是诊断。这些记录不会改变用药或饮食建议。',
                      ),
                    ),
                    const SizedBox(height: 16),
                    _dropdown<PersonalObservationKind>(
                      name: 'observation-kind',
                      label: copy.text('Observation type', '观察类型'),
                      value: _kind,
                      values: PersonalObservationKind.values,
                      display: copy.kind,
                      onChanged: (value) => setState(() {
                        _kind = value!;
                        _error = null;
                      }),
                    ),
                    _dropdown<PersonalObservationStatus>(
                      name: 'observation-status',
                      label: copy.text('Record status', '记录状态'),
                      value: _status,
                      values: PersonalObservationStatus.values,
                      display: copy.status,
                      onChanged: (value) => setState(() => _status = value!),
                    ),
                    if (_kind == PersonalObservationKind.symptom) ...[
                      _field(
                        'observation-label',
                        _label,
                        copy.text('Symptom or observation', '症状或观察内容'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? copy.required
                            : null,
                        maxLength: 200,
                      ),
                      if (measured)
                        _field(
                          'observation-severity',
                          _severity,
                          copy.text(
                            'Subjective severity 0–10 (optional)',
                            '主观严重度 0–10（可留空）',
                          ),
                          keyboard: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return null;
                            }
                            final parsed = int.tryParse(value.trim());
                            return parsed == null || parsed < 0 || parsed > 10
                                ? copy.text(
                                    'Enter a whole number from 0 to 10, or leave blank.',
                                    '请填写 0 到 10 的整数，或留空。',
                                  )
                                : null;
                          },
                        ),
                    ],
                    if (_kind ==
                            PersonalObservationKind.selfReportedMotorState &&
                        measured)
                      _dropdown<SelfReportedMotorState>(
                        name: 'observation-motor-state',
                        label: copy.text('Self-reported state', '自报状态'),
                        value: _motorState,
                        values: SelfReportedMotorState.values,
                        display: copy.motor,
                        onChanged: (value) =>
                            setState(() => _motorState = value),
                        validator: (value) =>
                            value == null ? copy.required : null,
                      ),
                    if (_kind == PersonalObservationKind.bloodPressure) ...[
                      if (measured) ...[
                        _field(
                          'observation-systolic',
                          _systolic,
                          copy.text(
                            'Systolic blood pressure (mmHg)',
                            '收缩压（mmHg）',
                          ),
                          keyboard: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (value) => _pressureError(value, copy),
                        ),
                        _field(
                          'observation-diastolic',
                          _diastolic,
                          copy.text(
                            'Diastolic blood pressure (mmHg)',
                            '舒张压（mmHg）',
                          ),
                          keyboard: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (value) => _pressureError(value, copy),
                        ),
                      ],
                      _dropdown<BloodPressurePosture>(
                        name: 'observation-posture',
                        label: copy.text('Posture when measured', '测量时体位'),
                        value: _posture,
                        values: BloodPressurePosture.values,
                        display: copy.posture,
                        onChanged: (value) => setState(() => _posture = value!),
                      ),
                    ],
                    _field(
                      'observation-occurred-at',
                      _occurred,
                      copy.text(
                        'When it happened (include UTC offset)',
                        '发生时间（含 UTC 时差）',
                      ),
                      helper: copy.text(
                        'Example: 2026-09-22T09:30:00-04:00. Keep the original local offset when editing.',
                        '示例：2026-09-22T09:30:00-04:00。编辑时请保留发生地的时差。',
                      ),
                      validator: (value) {
                        try {
                          PersonalObservation.parseExplicitTimestamp(
                            value?.trim() ?? '',
                          );
                          return null;
                        } catch (_) {
                          return copy.text(
                            'Enter a valid date and time with Z or ±HH:MM.',
                            '请填写有效日期时间，末尾包含 Z 或 ±HH:MM。',
                          );
                        }
                      },
                    ),
                    _field(
                      'observation-timezone',
                      _timezone,
                      copy.text(
                        'Original timezone or UTC offset',
                        '发生地时区或 UTC 时差',
                      ),
                      validator: (value) =>
                          PersonalObservation.isExplicitTimezone(
                            value?.trim() ?? '',
                          )
                          ? null
                          : copy.text(
                              'Use UTC-04:00 or a name such as America/Toronto.',
                              '请填写 UTC-04:00 或 America/Toronto 等时区名称。',
                            ),
                    ),
                    _dropdown<PersonalObservationSource>(
                      name: 'observation-source',
                      label: copy.text('Information source', '信息来源'),
                      value: _source,
                      values: PersonalObservationSource.values,
                      display: copy.source,
                      onChanged: (value) => setState(() => _source = value!),
                    ),
                    _field(
                      'observation-notes',
                      _notes,
                      copy.text('Notes (optional)', '备注（可留空）'),
                      maxLines: 3,
                      maxLength: 4000,
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            key: const Key('observation-save-error'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ),
                    FilledButton.icon(
                      key: const Key('observation-save'),
                      onPressed: _saving ? null : () => _save(copy),
                      icon: const Icon(Icons.save_outlined),
                      label: Text(
                        _saving
                            ? copy.text('Saving…', '保存中…')
                            : copy.text('Save observation', '保存观察记录'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _pressureError(String? value, _ObservationCopy copy) {
    final number = double.tryParse(value?.trim() ?? '');
    return number == null || !number.isFinite || number <= 0
        ? copy.text(
            'Enter a positive measured value, or select Not measured / Unknown.',
            '请填写正数测量值，或选择“未测量 / 未知”。',
          )
        : null;
  }

  Widget _field(
    String name,
    TextEditingController controller,
    String label, {
    String? Function(String?)? validator,
    TextInputType? keyboard,
    String? helper,
    int maxLines = 1,
    int? maxLength,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      key: Key(name),
      controller: controller,
      enabled: !_saving,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        helperMaxLines: 4,
        border: const OutlineInputBorder(),
      ),
      keyboardType: keyboard,
      validator: validator,
      maxLines: maxLines,
      maxLength: maxLength,
    ),
  );

  Widget _dropdown<T>({
    required String name,
    required String label,
    required T? value,
    required List<T> values,
    required String Function(T) display,
    required ValueChanged<T?> onChanged,
    String? Function(T?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DropdownButtonFormField<T>(
      key: Key(name),
      initialValue: value,
      isExpanded: true,
      dropdownColor: Theme.of(context).colorScheme.surface.withAlpha(255),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final item in values)
          DropdownMenuItem(value: item, child: Text(display(item))),
      ],
      onChanged: _saving ? null : onChanged,
      validator: validator,
    ),
  );
}

class _ObservationCopy {
  const _ObservationCopy(this.chinese);
  final bool chinese;
  String text(String en, String zh) => chinese ? zh : en;
  String get required => text('Please fill in this field.', '请填写此项。');
  String get saveFailure => text(
    'The observation was not saved. Check your entries and try again.',
    '观察记录未保存，请检查填写内容后重试。',
  );
  String kind(PersonalObservationKind value) => switch (value) {
    PersonalObservationKind.symptom => text('Symptom / observation', '症状 / 观察'),
    PersonalObservationKind.selfReportedMotorState => text(
      'Self-reported ON/OFF state',
      '自报 ON/OFF 状态',
    ),
    PersonalObservationKind.bloodPressure => text('Blood pressure', '血压'),
  };
  String status(PersonalObservationStatus value) => switch (value) {
    PersonalObservationStatus.recorded => text('Recorded', '已记录'),
    PersonalObservationStatus.notMeasured => text('Not measured', '未测量'),
    PersonalObservationStatus.unknown => text('Unknown', '未知'),
  };
  String motor(SelfReportedMotorState value) => switch (value) {
    SelfReportedMotorState.on => text('ON (self-reported)', 'ON（自报）'),
    SelfReportedMotorState.off => text('OFF (self-reported)', 'OFF（自报）'),
    SelfReportedMotorState.uncertain => text('Uncertain', '不确定'),
  };
  String posture(BloodPressurePosture value) => switch (value) {
    BloodPressurePosture.sitting => text('Sitting', '坐位'),
    BloodPressurePosture.standing => text('Standing', '站立'),
    BloodPressurePosture.lying => text('Lying down', '卧位'),
    BloodPressurePosture.unknown => text('Unknown', '未知'),
  };
  String source(PersonalObservationSource value) => switch (value) {
    PersonalObservationSource.selfReported => text('Self-reported', '本人自报'),
    PersonalObservationSource.deviceManual => text(
      'Device reading entered manually',
      '手动抄录设备读数',
    ),
    PersonalObservationSource.caregiverReported => text(
      'Reported by a caregiver',
      '照护者报告',
    ),
  };
}
