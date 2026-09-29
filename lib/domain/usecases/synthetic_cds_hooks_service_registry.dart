/// Hook names supported by the fixed, code-owned CDS Hooks preview.
enum SyntheticCdsHooksHook {
  patientView('patient-view'),
  orderSelect('order-select');

  const SyntheticCdsHooksHook(this.wireValue);

  final String wireValue;
}

/// One fixed prefetch key and FHIR query template; it is never executed here.
final class SyntheticCdsHooksPrefetchTemplate {
  const SyntheticCdsHooksPrefetchTemplate({
    required this.key,
    required this.queryTemplate,
  });

  final String key;
  final String queryTemplate;
}

final class SyntheticCdsHooksPrefetchAssignment {
  const SyntheticCdsHooksPrefetchAssignment({
    required this.serviceId,
    required this.prefetchKey,
  });

  final String serviceId;
  final String prefetchKey;
}

final class SyntheticCdsHooksPrefetchRequestPlan {
  SyntheticCdsHooksPrefetchRequestPlan({
    required this.queryTemplate,
    required List<SyntheticCdsHooksPrefetchAssignment> serviceAssignments,
  }) : serviceAssignments =
           List<SyntheticCdsHooksPrefetchAssignment>.unmodifiable(
             serviceAssignments,
           );

  final String queryTemplate;
  final List<SyntheticCdsHooksPrefetchAssignment> serviceAssignments;
}

final class SyntheticCdsHooksResolvedPrefetchPreview {
  SyntheticCdsHooksResolvedPrefetchPreview({
    required this.queryTemplate,
    required this.relativeFhirRequest,
    required List<SyntheticCdsHooksPrefetchAssignment> serviceAssignments,
  }) : serviceAssignments =
           List<SyntheticCdsHooksPrefetchAssignment>.unmodifiable(
             serviceAssignments,
           );

  final String queryTemplate;
  final String relativeFhirRequest;
  final List<SyntheticCdsHooksPrefetchAssignment> serviceAssignments;
}

final class SyntheticCdsHooksPrefetchBindingPreview {
  const SyntheticCdsHooksPrefetchBindingPreview({
    required this.prefetchKey,
    required this.queryTemplate,
    required this.relativeFhirRequest,
  });

  final String prefetchKey;
  final String queryTemplate;
  final String relativeFhirRequest;
}

final class SyntheticCdsHooksServicePrefetchBindingPlan {
  SyntheticCdsHooksServicePrefetchBindingPlan({
    required this.hook,
    required this.serviceId,
    required List<SyntheticCdsHooksPrefetchBindingPreview> bindings,
  }) : bindings = List<SyntheticCdsHooksPrefetchBindingPreview>.unmodifiable(
         bindings,
       );

  final SyntheticCdsHooksHook hook;
  final String serviceId;
  final List<SyntheticCdsHooksPrefetchBindingPreview> bindings;
}

/// Fixed, code-owned FHIR fixture values mapped only to one service's keys.
/// The plan is never sent or passed to the local rule engine.
final class SyntheticCdsHooksServicePrefetchPayloadPlan {
  SyntheticCdsHooksServicePrefetchPayloadPlan({
    required this.hook,
    required this.serviceId,
    required Map<String, Object?> prefetchPayload,
  }) : prefetchPayload = Map<String, Object?>.unmodifiable(prefetchPayload);

  final SyntheticCdsHooksHook hook;
  final String serviceId;
  final Map<String, Object?> prefetchPayload;
}

/// A local request-body example. Its identifiers are fixed demo placeholders.
final class SyntheticCdsHooksServiceRequestEnvelopePlan {
  SyntheticCdsHooksServiceRequestEnvelopePlan({
    required this.hook,
    required this.serviceId,
    required Map<String, Object?> requestBody,
  }) : requestBody = _freezeSyntheticJsonMap(requestBody);

  final SyntheticCdsHooksHook hook;
  final String serviceId;
  final Map<String, Object?> requestBody;
}

enum SyntheticCdsHooksServiceResponseState {
  informationOnly('information_only'),
  noGuidance('no_guidance');

  const SyntheticCdsHooksServiceResponseState(this.wireValue);

  final String wireValue;
}

/// One fixed synthetic response kept separate from every other service result.
final class SyntheticCdsHooksServiceResponsePreview {
  SyntheticCdsHooksServiceResponsePreview({
    required this.hook,
    required this.serviceId,
    required this.state,
    required Map<String, Object?> response,
  }) : response = _freezeSyntheticJsonMap(response);

  final SyntheticCdsHooksHook hook;
  final String serviceId;
  final SyntheticCdsHooksServiceResponseState state;
  final Map<String, Object?> response;

  int get cardCount => (response['cards'] as List).length;

  Map<String, Object?> toJson() => <String, Object?>{
    'hook': hook.wireValue,
    'serviceId': serviceId,
    'expectedState': state.wireValue,
    'response': response,
  };
}

Map<String, Object?> _freezeSyntheticJsonMap(Map<String, Object?> source) =>
    Map<String, Object?>.unmodifiable({
      for (final entry in source.entries)
        entry.key: _freezeSyntheticJsonValue(entry.value),
    });

Object? _freezeSyntheticJsonValue(Object? value) => switch (value) {
  Map<String, Object?> map => _freezeSyntheticJsonMap(map),
  List<dynamic> list => List<Object?>.unmodifiable(
    list.map(_freezeSyntheticJsonValue),
  ),
  _ => value,
};

enum SyntheticCdsHooksPrefetchOutcome {
  resource('resource'),
  emptySearchset('empty_searchset'),
  explicitNull('explicit_null'),
  notSatisfied('not_satisfied');

  const SyntheticCdsHooksPrefetchOutcome(this.wireValue);

  final String wireValue;
}

/// Shows whether a fixed service key is present in a synthetic prefetch map.
final class SyntheticCdsHooksServicePrefetchOutcomePlan {
  SyntheticCdsHooksServicePrefetchOutcomePlan({
    required this.hook,
    required this.serviceId,
    required Map<String, SyntheticCdsHooksPrefetchOutcome> keyOutcomes,
    required Map<String, Object?> prefetchPayload,
  }) : keyOutcomes = Map<String, SyntheticCdsHooksPrefetchOutcome>.unmodifiable(
         keyOutcomes,
       ),
       prefetchPayload = Map<String, Object?>.unmodifiable(prefetchPayload);

  final SyntheticCdsHooksHook hook;
  final String serviceId;
  final Map<String, SyntheticCdsHooksPrefetchOutcome> keyOutcomes;
  final Map<String, Object?> prefetchPayload;
}

/// One code-owned synthetic service definition. It has no endpoint or payload.
final class SyntheticCdsHooksServiceDefinition {
  const SyntheticCdsHooksServiceDefinition({
    required this.id,
    required this.hook,
    required this.title,
    required this.description,
    required this.titleZh,
    this.prefetchTemplates = const <SyntheticCdsHooksPrefetchTemplate>[],
  });

  final String id;
  final SyntheticCdsHooksHook hook;
  final String title;
  final String description;
  final String titleZh;
  final List<SyntheticCdsHooksPrefetchTemplate> prefetchTemplates;

  Map<String, Object?> toJson() => <String, Object?>{
    'hook': hook.wireValue,
    'title': title,
    'description': description,
    'id': id,
    if (prefetchTemplates.isNotEmpty)
      'prefetch': <String, String>{
        for (final template in prefetchTemplates)
          template.key: template.queryTemplate,
      },
  };
}

/// Fixed metadata used to preview hook-scoped matching in the local sandbox.
/// This registry does not describe executable services or network endpoints.
abstract final class SyntheticCdsHooksServiceRegistry {
  static const String fixedSyntheticPatientId = 'synthetic-patient-001';
  static const String _patientIdToken = '{{context.patientId}}';
  static const String _patientQueryTemplate = 'Patient/{{context.patientId}}';
  static const String _conditionQueryTemplate =
      'Condition?patient={{context.patientId}}&_count=2';
  static final RegExp _fhirR4IdPattern = RegExp(r'^[A-Za-z0-9.-]{1,64}$');
  static const Map<String, Object?> _syntheticPatientResult = <String, Object?>{
    'resourceType': 'Patient',
    'id': fixedSyntheticPatientId,
  };
  static const Map<String, Object?> _emptySyntheticConditionSearchResult =
      <String, Object?>{
        'resourceType': 'Bundle',
        'type': 'searchset',
        'total': 0,
        'entry': <Object?>[],
      };
  static const Map<String, SyntheticCdsHooksPrefetchOutcome>
  _prefetchOutcomeByKey = <String, SyntheticCdsHooksPrefetchOutcome>{
    'patient': SyntheticCdsHooksPrefetchOutcome.resource,
    'conditions': SyntheticCdsHooksPrefetchOutcome.emptySearchset,
    'subject': SyntheticCdsHooksPrefetchOutcome.explicitNull,
    'problem-list': SyntheticCdsHooksPrefetchOutcome.notSatisfied,
  };
  static const String _fixedSyntheticUserId =
      'Practitioner/synthetic-practitioner-001';
  static const String _fixedSyntheticOrderId = 'synthetic-order-001';
  static const Map<String, String> _hookInstancePreviewByServiceId =
      <String, String>{
        'parkinsum-synthetic-patient-review-a':
            '83c30ec4-d8ae-4c9a-a7ee-3c845872c1e4',
        'parkinsum-synthetic-patient-review-b':
            'e6583b52-6d9f-4301-9ae1-f3f0ad8e1b46',
        'parkinsum-synthetic-order-selection-a':
            '42f304b0-89c4-42f3-a5b9-7901754ea341',
        'parkinsum-synthetic-order-selection-b':
            'c2d82059-9fe8-4c17-8c7c-b39aa3fb4380',
      };
  static const Map<String, SyntheticCdsHooksServiceResponseState>
  _serviceResponseStateById = <String, SyntheticCdsHooksServiceResponseState>{
    'parkinsum-synthetic-patient-review-a':
        SyntheticCdsHooksServiceResponseState.informationOnly,
    'parkinsum-synthetic-patient-review-b':
        SyntheticCdsHooksServiceResponseState.noGuidance,
    'parkinsum-synthetic-order-selection-a':
        SyntheticCdsHooksServiceResponseState.noGuidance,
    'parkinsum-synthetic-order-selection-b':
        SyntheticCdsHooksServiceResponseState.informationOnly,
  };
  static const Map<String, Object?> _syntheticInformationOnlyResponse =
      <String, Object?>{
        'cards': <Map<String, Object?>>[
          <String, Object?>{
            'summary': 'Synthetic information-only response preview.',
            'indicator': 'info',
            'source': <String, Object?>{'label': 'Synthetic service fixture'},
          },
        ],
      };
  static const Map<String, Object?> _syntheticNoGuidanceResponse =
      <String, Object?>{'cards': <Object?>[]};
  static const Map<String, Object?> _syntheticDraftServiceRequest =
      <String, Object?>{
        'resourceType': 'ServiceRequest',
        'id': _fixedSyntheticOrderId,
        'status': 'draft',
        'intent': 'order',
        'subject': <String, Object?>{
          'reference': 'Patient/$fixedSyntheticPatientId',
        },
      };
  static const Map<String, Object?> _syntheticDraftOrdersBundle =
      <String, Object?>{
        'resourceType': 'Bundle',
        'type': 'collection',
        'entry': <Object?>[
          <String, Object?>{
            'fullUrl': 'urn:uuid:5f9f2f8b-76aa-4ed5-aac6-3a98d19e73db',
            'resource': _syntheticDraftServiceRequest,
          },
        ],
      };

  static const List<SyntheticCdsHooksServiceDefinition>
  _services = <SyntheticCdsHooksServiceDefinition>[
    SyntheticCdsHooksServiceDefinition(
      id: 'parkinsum-synthetic-patient-review-a',
      hook: SyntheticCdsHooksHook.patientView,
      title: 'Synthetic patient review A',
      description:
          'Test-only service metadata; no clinical content or endpoint exists.',
      titleZh: '合成患者查看服务 A',
      prefetchTemplates: <SyntheticCdsHooksPrefetchTemplate>[
        SyntheticCdsHooksPrefetchTemplate(
          key: 'patient',
          queryTemplate: _patientQueryTemplate,
        ),
        SyntheticCdsHooksPrefetchTemplate(
          key: 'conditions',
          queryTemplate: _conditionQueryTemplate,
        ),
      ],
    ),
    SyntheticCdsHooksServiceDefinition(
      id: 'parkinsum-synthetic-patient-review-b',
      hook: SyntheticCdsHooksHook.patientView,
      title: 'Synthetic patient review B',
      description:
          'Test-only service metadata; no clinical content or endpoint exists.',
      titleZh: '合成患者查看服务 B',
      prefetchTemplates: <SyntheticCdsHooksPrefetchTemplate>[
        SyntheticCdsHooksPrefetchTemplate(
          key: 'subject',
          queryTemplate: _patientQueryTemplate,
        ),
        SyntheticCdsHooksPrefetchTemplate(
          key: 'problem-list',
          queryTemplate: _conditionQueryTemplate,
        ),
      ],
    ),
    SyntheticCdsHooksServiceDefinition(
      id: 'parkinsum-synthetic-order-selection-a',
      hook: SyntheticCdsHooksHook.orderSelect,
      title: 'Synthetic order selection A',
      description:
          'Test-only service metadata; no clinical content or endpoint exists.',
      titleZh: '合成医嘱选择服务 A',
      prefetchTemplates: <SyntheticCdsHooksPrefetchTemplate>[
        SyntheticCdsHooksPrefetchTemplate(
          key: 'patient',
          queryTemplate: _patientQueryTemplate,
        ),
        SyntheticCdsHooksPrefetchTemplate(
          key: 'conditions',
          queryTemplate: _conditionQueryTemplate,
        ),
      ],
    ),
    SyntheticCdsHooksServiceDefinition(
      id: 'parkinsum-synthetic-order-selection-b',
      hook: SyntheticCdsHooksHook.orderSelect,
      title: 'Synthetic order selection B',
      description:
          'Test-only service metadata; no clinical content or endpoint exists.',
      titleZh: '合成医嘱选择服务 B',
      prefetchTemplates: <SyntheticCdsHooksPrefetchTemplate>[
        SyntheticCdsHooksPrefetchTemplate(
          key: 'subject',
          queryTemplate: _patientQueryTemplate,
        ),
        SyntheticCdsHooksPrefetchTemplate(
          key: 'problem-list',
          queryTemplate: _conditionQueryTemplate,
        ),
      ],
    ),
  ];

  static List<SyntheticCdsHooksServiceDefinition> get services =>
      List<SyntheticCdsHooksServiceDefinition>.unmodifiable(_services);

  /// Returns matching definitions in registry order as a read-only plan.
  static List<SyntheticCdsHooksServiceDefinition> servicesForHook(
    SyntheticCdsHooksHook hook,
  ) => List<SyntheticCdsHooksServiceDefinition>.unmodifiable(
    _services.where((service) => service.hook == hook),
  );

  /// Coalesces only exact templates within a hook; assignments stay scoped.
  static List<SyntheticCdsHooksPrefetchRequestPlan> prefetchPlanForHook(
    SyntheticCdsHooksHook hook,
  ) {
    final queryGroups = <String, List<SyntheticCdsHooksPrefetchAssignment>>{};
    for (final service in servicesForHook(hook)) {
      for (final template in service.prefetchTemplates) {
        queryGroups
            .putIfAbsent(
              template.queryTemplate,
              () => <SyntheticCdsHooksPrefetchAssignment>[],
            )
            .add(
              SyntheticCdsHooksPrefetchAssignment(
                serviceId: service.id,
                prefetchKey: template.key,
              ),
            );
      }
    }
    return List<SyntheticCdsHooksPrefetchRequestPlan>.unmodifiable(
      queryGroups.entries.map(
        (entry) => SyntheticCdsHooksPrefetchRequestPlan(
          queryTemplate: entry.key,
          serviceAssignments: entry.value,
        ),
      ),
    );
  }

  /// Validates the R4 id primitive shape without normalizing or repairing it.
  static bool isValidFhirR4Id(String value) =>
      _fhirR4IdPattern.matchAsPrefix(value)?.end == value.length;

  /// Resolves the hook's templates with one code-owned synthetic id only.
  /// The returned relative paths are displayable plans, never requests.
  static List<SyntheticCdsHooksResolvedPrefetchPreview>
  resolvedPrefetchPreviewForHook(SyntheticCdsHooksHook hook) {
    final patientId = fixedSyntheticPatientId;
    if (!isValidFhirR4Id(patientId)) {
      throw StateError('The fixed synthetic Patient id is invalid.');
    }
    return List<SyntheticCdsHooksResolvedPrefetchPreview>.unmodifiable(
      prefetchPlanForHook(hook).map((plan) {
        if (!plan.queryTemplate.contains(_patientIdToken) ||
            plan.queryTemplate.indexOf(_patientIdToken) !=
                plan.queryTemplate.lastIndexOf(_patientIdToken)) {
          throw StateError('A fixed prefetch template has an invalid token.');
        }
        return SyntheticCdsHooksResolvedPrefetchPreview(
          queryTemplate: plan.queryTemplate,
          relativeFhirRequest: plan.queryTemplate.replaceAll(
            _patientIdToken,
            Uri.encodeComponent(patientId),
          ),
          serviceAssignments: plan.serviceAssignments,
        );
      }),
    );
  }

  /// Projects resolved paths back into each service's own prefetch keys.
  /// This is metadata only; no FHIR resource value is fetched or constructed.
  static List<SyntheticCdsHooksServicePrefetchBindingPlan>
  serviceScopedPrefetchBindingsForHook(SyntheticCdsHooksHook hook) {
    final pathByTemplate = <String, String>{
      for (final preview in resolvedPrefetchPreviewForHook(hook))
        preview.queryTemplate: preview.relativeFhirRequest,
    };
    return List<SyntheticCdsHooksServicePrefetchBindingPlan>.unmodifiable(
      servicesForHook(hook).map((service) {
        final bindings = service.prefetchTemplates.map((template) {
          final relativePath = pathByTemplate[template.queryTemplate];
          if (relativePath == null) {
            throw StateError('A service template has no resolved path.');
          }
          return SyntheticCdsHooksPrefetchBindingPreview(
            prefetchKey: template.key,
            queryTemplate: template.queryTemplate,
            relativeFhirRequest: relativePath,
          );
        });
        return SyntheticCdsHooksServicePrefetchBindingPlan(
          hook: hook,
          serviceId: service.id,
          bindings: bindings.toList(),
        );
      }),
    );
  }

  /// Builds only the two versioned synthetic FHIR prefetch values.
  /// Nothing is fetched, posted, persisted, or passed to the rule engine.
  static List<SyntheticCdsHooksServicePrefetchPayloadPlan>
  serviceScopedPrefetchPayloadsForHook(SyntheticCdsHooksHook hook) {
    return List<SyntheticCdsHooksServicePrefetchPayloadPlan>.unmodifiable(
      serviceScopedPrefetchBindingsForHook(hook).map((servicePlan) {
        final payload = <String, Object?>{};
        for (final binding in servicePlan.bindings) {
          final value = switch (binding.queryTemplate) {
            _patientQueryTemplate => _syntheticPatientResult,
            _conditionQueryTemplate => _emptySyntheticConditionSearchResult,
            _ => throw StateError(
              'A fixed prefetch key has no synthetic result fixture.',
            ),
          };
          payload[binding.prefetchKey] = value;
        }
        return SyntheticCdsHooksServicePrefetchPayloadPlan(
          hook: hook,
          serviceId: servicePlan.serviceId,
          prefetchPayload: payload,
        );
      }),
    );
  }

  /// Contrasts populated, known-empty, explicit-null, and omitted key states.
  /// Omitted keys are metadata only and never appear in prefetchPayload.
  static List<SyntheticCdsHooksServicePrefetchOutcomePlan>
  serviceScopedPrefetchOutcomePreviewsForHook(SyntheticCdsHooksHook hook) {
    return List<SyntheticCdsHooksServicePrefetchOutcomePlan>.unmodifiable(
      serviceScopedPrefetchBindingsForHook(hook).map((servicePlan) {
        final keyOutcomes = <String, SyntheticCdsHooksPrefetchOutcome>{};
        final prefetchPayload = <String, Object?>{};
        for (final binding in servicePlan.bindings) {
          final outcome = _prefetchOutcomeByKey[binding.prefetchKey];
          if (outcome == null) {
            throw StateError('A service key has no fixed outcome state.');
          }
          keyOutcomes[binding.prefetchKey] = outcome;
          switch (outcome) {
            case SyntheticCdsHooksPrefetchOutcome.resource:
              if (binding.queryTemplate != _patientQueryTemplate) {
                throw StateError('A resource outcome requires a Patient read.');
              }
              prefetchPayload[binding.prefetchKey] = _syntheticPatientResult;
            case SyntheticCdsHooksPrefetchOutcome.emptySearchset:
              if (binding.queryTemplate != _conditionQueryTemplate) {
                throw StateError(
                  'An empty searchset outcome requires a Condition search.',
                );
              }
              prefetchPayload[binding.prefetchKey] =
                  _emptySyntheticConditionSearchResult;
            case SyntheticCdsHooksPrefetchOutcome.explicitNull:
              if (binding.queryTemplate != _patientQueryTemplate) {
                throw StateError('A null outcome requires a Patient read.');
              }
              prefetchPayload[binding.prefetchKey] = null;
            case SyntheticCdsHooksPrefetchOutcome.notSatisfied:
              break;
          }
        }
        return SyntheticCdsHooksServicePrefetchOutcomePlan(
          hook: hook,
          serviceId: servicePlan.serviceId,
          keyOutcomes: keyOutcomes,
          prefetchPayload: prefetchPayload,
        );
      }),
    );
  }

  /// Builds fixed, hook-specific request-body examples without transport.
  /// The hookInstance values are display placeholders, not runtime UUIDs.
  static List<SyntheticCdsHooksServiceRequestEnvelopePlan>
  serviceRequestEnvelopePreviewsForHook(SyntheticCdsHooksHook hook) {
    return List<SyntheticCdsHooksServiceRequestEnvelopePlan>.unmodifiable(
      serviceScopedPrefetchPayloadsForHook(hook).map((servicePlan) {
        final hookInstance =
            _hookInstancePreviewByServiceId[servicePlan.serviceId];
        if (hookInstance == null) {
          throw StateError('A service has no fixed hook-instance preview.');
        }
        final context = <String, Object?>{
          'userId': _fixedSyntheticUserId,
          'patientId': fixedSyntheticPatientId,
          if (hook == SyntheticCdsHooksHook.orderSelect) ...<String, Object?>{
            'selections': <String>['ServiceRequest/$_fixedSyntheticOrderId'],
            'draftOrders': _syntheticDraftOrdersBundle,
          },
        };
        final requestBody = <String, Object?>{
          'hook': hook.wireValue,
          'hookInstance': hookInstance,
          'context': Map<String, Object?>.unmodifiable(context),
          'prefetch': servicePlan.prefetchPayload,
        };
        return SyntheticCdsHooksServiceRequestEnvelopePlan(
          hook: hook,
          serviceId: servicePlan.serviceId,
          requestBody: requestBody,
        );
      }),
    );
  }

  /// Returns one fixed response preview per service without merging results.
  static List<SyntheticCdsHooksServiceResponsePreview>
  serviceResponsePreviewsForHook(SyntheticCdsHooksHook hook) =>
      List<SyntheticCdsHooksServiceResponsePreview>.unmodifiable(
        servicesForHook(hook).map((service) {
          final state = _serviceResponseStateById[service.id];
          if (state == null) {
            throw StateError('A registered service has no response fixture.');
          }
          return SyntheticCdsHooksServiceResponsePreview(
            hook: hook,
            serviceId: service.id,
            state: state,
            response: switch (state) {
              SyntheticCdsHooksServiceResponseState.informationOnly =>
                _syntheticInformationOnlyResponse,
              SyntheticCdsHooksServiceResponseState.noGuidance =>
                _syntheticNoGuidanceResponse,
            },
          );
        }),
      );
}
