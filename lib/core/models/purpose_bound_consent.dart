import 'dart:convert';

import 'package:crypto/crypto.dart';

const purposeBoundConsentReceiptSchemaVersion = 1;
const localAiRerankingFeatureId = 'local_ai_reranking';
const localAiRerankingPurposeId =
    'localhost_safe_candidate_reranking_and_copy_polish';
const localAiConsentNoticeVersion = 1;

enum PurposeBoundConsentDecision { grant, revoke }

enum PurposeBoundConsentStatus {
  granted,
  denied,
  staleNotice,
  blockedIntegrity,
}

/// The exact notice contract whose digest is bound into each Local AI receipt.
///
/// This is an engineering consent record, not a legal conclusion. The feature
/// stays optional and local-only: it may contact only a loopback model service,
/// may only reorder an already-safe candidate whitelist or polish wording, and
/// may never change medication, safety, score, or evidence decisions.
final class LocalAiConsentNotice {
  static const controller = 'ParkinSUM local application';
  static const purpose =
      'Optionally use a user-operated model on this device to reorder an '
      'already-safe candidate whitelist and polish wording.';
  static const processing = <String>[
    'Send bounded candidate identifiers and already-produced explanation copy '
        'to a loopback-only model endpoint.',
    'Validate structured output against the original safe whitelist and '
        'protected facts before displaying it.',
  ];
  static const exclusions = <String>[
    'No cloud endpoint or automatic redirect is permitted.',
    'The model cannot change medication, safety, score, rule, or evidence '
        'decisions.',
    'Withdrawing consent disables new Local AI requests.',
  ];

  static Map<String, Object> get canonicalPayload => <String, Object>{
    'controller': controller,
    'exclusions': exclusions,
    'featureId': localAiRerankingFeatureId,
    'noticeVersion': localAiConsentNoticeVersion,
    'processing': processing,
    'purpose': purpose,
    'purposeId': localAiRerankingPurposeId,
  };

  static String get sha256Digest =>
      sha256.convert(utf8.encode(jsonEncode(canonicalPayload))).toString();
}

final class PurposeBoundConsentReceipt {
  final int schemaVersion;
  final String receiptId;
  final String featureId;
  final String purposeId;
  final int noticeVersion;
  final String noticeSha256;
  final PurposeBoundConsentDecision decision;
  final int sequence;
  final DateTime recordedAtUtc;
  final String source;

  PurposeBoundConsentReceipt._({
    required this.schemaVersion,
    required this.receiptId,
    required this.featureId,
    required this.purposeId,
    required this.noticeVersion,
    required this.noticeSha256,
    required this.decision,
    required this.sequence,
    required this.recordedAtUtc,
    required this.source,
  });

  factory PurposeBoundConsentReceipt.localAi({
    required PurposeBoundConsentDecision decision,
    required int sequence,
    required DateTime recordedAt,
    required String source,
  }) {
    final recordedAtUtc = recordedAt.toUtc();
    final fields = <String, Object>{
      'schemaVersion': purposeBoundConsentReceiptSchemaVersion,
      'featureId': localAiRerankingFeatureId,
      'purposeId': localAiRerankingPurposeId,
      'noticeVersion': localAiConsentNoticeVersion,
      'noticeSha256': LocalAiConsentNotice.sha256Digest,
      'decision': decision.name,
      'sequence': sequence,
      'recordedAtUtc': recordedAtUtc.toIso8601String(),
      'source': source,
    };
    final receiptId = _receiptDigest(fields);
    final receipt = PurposeBoundConsentReceipt._(
      schemaVersion: purposeBoundConsentReceiptSchemaVersion,
      receiptId: receiptId,
      featureId: localAiRerankingFeatureId,
      purposeId: localAiRerankingPurposeId,
      noticeVersion: localAiConsentNoticeVersion,
      noticeSha256: LocalAiConsentNotice.sha256Digest,
      decision: decision,
      sequence: sequence,
      recordedAtUtc: recordedAtUtc,
      source: source,
    );
    if (!receipt.isStructurallyValid) {
      throw const FormatException('consent_receipt_invalid');
    }
    return receipt;
  }

  factory PurposeBoundConsentReceipt.fromJson(Map<String, dynamic> json) {
    final decisionName = json['decision'];
    final recordedAtText = json['recordedAtUtc'];
    final receipt = PurposeBoundConsentReceipt._(
      schemaVersion: json['schemaVersion'] is int
          ? json['schemaVersion'] as int
          : -1,
      receiptId: json['receiptId'] is String ? json['receiptId'] as String : '',
      featureId: json['featureId'] is String ? json['featureId'] as String : '',
      purposeId: json['purposeId'] is String ? json['purposeId'] as String : '',
      noticeVersion: json['noticeVersion'] is int
          ? json['noticeVersion'] as int
          : -1,
      noticeSha256: json['noticeSha256'] is String
          ? json['noticeSha256'] as String
          : '',
      decision: decisionName == PurposeBoundConsentDecision.grant.name
          ? PurposeBoundConsentDecision.grant
          : PurposeBoundConsentDecision.revoke,
      sequence: json['sequence'] is int ? json['sequence'] as int : -1,
      recordedAtUtc: recordedAtText is String
          ? DateTime.tryParse(recordedAtText)?.toUtc() ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
          : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      source: json['source'] is String ? json['source'] as String : '',
    );
    if (decisionName != PurposeBoundConsentDecision.grant.name &&
        decisionName != PurposeBoundConsentDecision.revoke.name) {
      throw const FormatException('consent_receipt_decision_invalid');
    }
    if (recordedAtText is! String || !recordedAtText.endsWith('Z')) {
      throw const FormatException('consent_receipt_timestamp_invalid');
    }
    if (!receipt.isStructurallyValid) {
      throw const FormatException('consent_receipt_invalid');
    }
    return receipt;
  }

  bool get isStructurallyValid {
    if (schemaVersion != purposeBoundConsentReceiptSchemaVersion ||
        !_safeId.hasMatch(featureId) ||
        !_safeId.hasMatch(purposeId) ||
        !_safeId.hasMatch(source) ||
        !_sha256Pattern.hasMatch(noticeSha256) ||
        !_sha256Pattern.hasMatch(receiptId) ||
        noticeVersion <= 0 ||
        sequence <= 0 ||
        recordedAtUtc.year < 2020 ||
        !recordedAtUtc.isUtc) {
      return false;
    }
    return receiptId == _receiptDigest(_identityFields);
  }

  bool get matchesCurrentLocalAiNotice =>
      featureId == localAiRerankingFeatureId &&
      purposeId == localAiRerankingPurposeId &&
      noticeVersion == localAiConsentNoticeVersion &&
      noticeSha256 == LocalAiConsentNotice.sha256Digest;

  Map<String, Object> get _identityFields => <String, Object>{
    'schemaVersion': schemaVersion,
    'featureId': featureId,
    'purposeId': purposeId,
    'noticeVersion': noticeVersion,
    'noticeSha256': noticeSha256,
    'decision': decision.name,
    'sequence': sequence,
    'recordedAtUtc': recordedAtUtc.toIso8601String(),
    'source': source,
  };

  Map<String, Object> toJson() => <String, Object>{
    ..._identityFields,
    'receiptId': receiptId,
  };

  static final RegExp _safeId = RegExp(r'^[a-z0-9][a-z0-9._-]{0,95}$');
  static final RegExp _sha256Pattern = RegExp(r'^[a-f0-9]{64}$');

  static String _receiptDigest(Map<String, Object> fields) => sha256
      .convert(
        utf8.encode(
          'parkinsum-purpose-consent-receipt-v1|${jsonEncode(fields)}',
        ),
      )
      .toString();
}

final class PurposeBoundConsentEvaluation {
  final PurposeBoundConsentStatus status;
  final PurposeBoundConsentReceipt? latestReceipt;
  final String reason;

  const PurposeBoundConsentEvaluation({
    required this.status,
    required this.latestReceipt,
    required this.reason,
  });

  bool get granted => status == PurposeBoundConsentStatus.granted;
}

final class PurposeBoundConsentLease {
  PurposeBoundConsentLease._({
    required this.subject,
    required this.receiptId,
    required this.epoch,
  });

  final String subject;
  final String receiptId;
  final int epoch;

  bool get isCurrent => PurposeBoundConsentRuntimeGate._isCurrent(this);
}

final class PurposeBoundConsentRuntimeGate {
  static final Map<String, _RuntimeConsentState> _states =
      <String, _RuntimeConsentState>{};

  static void synchronize({
    required String subject,
    required PurposeBoundConsentEvaluation evaluation,
  }) {
    final previous = _states[subject];
    final latest = evaluation.latestReceipt;
    _states[subject] = _RuntimeConsentState(
      epoch: (previous?.epoch ?? 0) + 1,
      receiptId: evaluation.granted ? latest?.receiptId : null,
    );
  }

  static void revokeImmediately(String subject) {
    final previous = _states[subject];
    _states[subject] = _RuntimeConsentState(
      epoch: (previous?.epoch ?? 0) + 1,
      receiptId: null,
    );
  }

  static PurposeBoundConsentLease? acquire({
    required String subject,
    required PurposeBoundConsentEvaluation evaluation,
  }) {
    if (!evaluation.granted) return null;
    final receiptId = evaluation.latestReceipt?.receiptId;
    if (receiptId == null) return null;
    var state = _states[subject];
    if (state == null) {
      state = _RuntimeConsentState(epoch: 1, receiptId: receiptId);
      _states[subject] = state;
    }
    if (state.receiptId != receiptId) return null;
    return PurposeBoundConsentLease._(
      subject: subject,
      receiptId: receiptId,
      epoch: state.epoch,
    );
  }

  static bool _isCurrent(PurposeBoundConsentLease lease) {
    final state = _states[lease.subject];
    return state != null &&
        state.epoch == lease.epoch &&
        state.receiptId == lease.receiptId;
  }
}

final class _RuntimeConsentState {
  const _RuntimeConsentState({required this.epoch, required this.receiptId});

  final int epoch;
  final String? receiptId;
}

PurposeBoundConsentEvaluation evaluateLocalAiConsent(
  List<PurposeBoundConsentReceipt> receipts, {
  bool ledgerBlocked = false,
}) {
  if (ledgerBlocked) {
    return const PurposeBoundConsentEvaluation(
      status: PurposeBoundConsentStatus.blockedIntegrity,
      latestReceipt: null,
      reason: 'consent_ledger_integrity_blocked',
    );
  }
  final local =
      receipts
          .where((receipt) => receipt.featureId == localAiRerankingFeatureId)
          .toList(growable: false)
        ..sort((left, right) => left.sequence.compareTo(right.sequence));
  if (local.isEmpty) {
    return const PurposeBoundConsentEvaluation(
      status: PurposeBoundConsentStatus.denied,
      latestReceipt: null,
      reason: 'consent_receipt_missing',
    );
  }
  if (local.length > 128) {
    return const PurposeBoundConsentEvaluation(
      status: PurposeBoundConsentStatus.blockedIntegrity,
      latestReceipt: null,
      reason: 'consent_receipt_budget_exceeded',
    );
  }
  final receiptIds = <String>{};
  for (var index = 0; index < local.length; index += 1) {
    final receipt = local[index];
    if (!receipt.isStructurallyValid ||
        receipt.sequence != index + 1 ||
        !receiptIds.add(receipt.receiptId)) {
      return const PurposeBoundConsentEvaluation(
        status: PurposeBoundConsentStatus.blockedIntegrity,
        latestReceipt: null,
        reason: 'consent_receipt_sequence_or_identity_invalid',
      );
    }
  }
  final latest = local.last;
  if (!latest.matchesCurrentLocalAiNotice) {
    return PurposeBoundConsentEvaluation(
      status: PurposeBoundConsentStatus.staleNotice,
      latestReceipt: latest,
      reason: 'consent_notice_stale',
    );
  }
  return PurposeBoundConsentEvaluation(
    status: latest.decision == PurposeBoundConsentDecision.grant
        ? PurposeBoundConsentStatus.granted
        : PurposeBoundConsentStatus.denied,
    latestReceipt: latest,
    reason: latest.decision == PurposeBoundConsentDecision.grant
        ? 'consent_granted'
        : 'consent_revoked',
  );
}
