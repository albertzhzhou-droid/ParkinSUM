import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/usecases/synthetic_cds_hooks_service_registry.dart';

void main() {
  test(
    'registry metadata stays aligned with the dispatch contract fixture',
    () {
      final fixture =
          jsonDecode(
                File(
                  'test/fixtures/cds_hooks_multi_service.synthetic.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;

      expect(
        SyntheticCdsHooksServiceRegistry.services
            .map((service) => service.toJson())
            .toList(),
        fixture['services'],
      );
    },
  );

  test('each supported hook returns its own services in registry order', () {
    final patientPlan = SyntheticCdsHooksServiceRegistry.servicesForHook(
      SyntheticCdsHooksHook.patientView,
    );
    final orderPlan = SyntheticCdsHooksServiceRegistry.servicesForHook(
      SyntheticCdsHooksHook.orderSelect,
    );

    expect(patientPlan, hasLength(2));
    expect(patientPlan.map((service) => service.id), <String>[
      'parkinsum-synthetic-patient-review-a',
      'parkinsum-synthetic-patient-review-b',
    ]);
    expect(orderPlan, hasLength(2));
    expect(orderPlan.map((service) => service.id), <String>[
      'parkinsum-synthetic-order-selection-a',
      'parkinsum-synthetic-order-selection-b',
    ]);
    expect(
      SyntheticCdsHooksServiceRegistry.services
          .map((service) => service.id)
          .toSet(),
      hasLength(4),
    );
    expect(() => patientPlan.add(orderPlan.first), throwsUnsupportedError);
  });

  test(
    'prefetch plans coalesce exact queries without merging service keys',
    () {
      final patientPlan = SyntheticCdsHooksServiceRegistry.prefetchPlanForHook(
        SyntheticCdsHooksHook.patientView,
      );
      final orderPlan = SyntheticCdsHooksServiceRegistry.prefetchPlanForHook(
        SyntheticCdsHooksHook.orderSelect,
      );

      expect(patientPlan, hasLength(2));
      expect(patientPlan.map((group) => group.queryTemplate), <String>[
        'Patient/{{context.patientId}}',
        'Condition?patient={{context.patientId}}&_count=2',
      ]);
      expect(
        patientPlan.first.serviceAssignments.map(
          (assignment) => '${assignment.serviceId}.${assignment.prefetchKey}',
        ),
        <String>[
          'parkinsum-synthetic-patient-review-a.patient',
          'parkinsum-synthetic-patient-review-b.subject',
        ],
      );
      expect(
        patientPlan.last.serviceAssignments.map(
          (assignment) => '${assignment.serviceId}.${assignment.prefetchKey}',
        ),
        <String>[
          'parkinsum-synthetic-patient-review-a.conditions',
          'parkinsum-synthetic-patient-review-b.problem-list',
        ],
      );

      expect(orderPlan, hasLength(2));
      expect(
        orderPlan.first.serviceAssignments.map(
          (assignment) => '${assignment.serviceId}.${assignment.prefetchKey}',
        ),
        <String>[
          'parkinsum-synthetic-order-selection-a.patient',
          'parkinsum-synthetic-order-selection-b.subject',
        ],
      );
      expect(orderPlan.first, isNot(same(patientPlan.first)));
      expect(
        () => patientPlan.first.serviceAssignments.add(
          const SyntheticCdsHooksPrefetchAssignment(
            serviceId: 'unregistered',
            prefetchKey: 'patient',
          ),
        ),
        throwsUnsupportedError,
      );
    },
  );

  test('resolved request previews bind only the fixed FHIR id shape', () {
    expect(
      SyntheticCdsHooksServiceRegistry.isValidFhirR4Id('synthetic-patient-001'),
      isTrue,
    );
    expect(SyntheticCdsHooksServiceRegistry.isValidFhirR4Id('A-z.1'), isTrue);
    expect(
      SyntheticCdsHooksServiceRegistry.isValidFhirR4Id(
        List<String>.filled(64, 'a').join(),
      ),
      isTrue,
    );
    for (final invalidId in <String>[
      '',
      List<String>.filled(65, 'a').join(),
      'patient/../1',
      'patient_id',
      'patient-1\n',
      'patient-1\r',
      '患者',
    ]) {
      expect(
        SyntheticCdsHooksServiceRegistry.isValidFhirR4Id(invalidId),
        isFalse,
        reason: invalidId,
      );
    }

    final preview =
        SyntheticCdsHooksServiceRegistry.resolvedPrefetchPreviewForHook(
          SyntheticCdsHooksHook.patientView,
        );
    expect(preview, hasLength(2));
    expect(preview.map((group) => group.relativeFhirRequest), <String>[
      'Patient/synthetic-patient-001',
      'Condition?patient=synthetic-patient-001&_count=2',
    ]);
    expect(preview.first.queryTemplate, 'Patient/{{context.patientId}}');
    expect(
      preview.first.serviceAssignments.map(
        (assignment) => '${assignment.serviceId}.${assignment.prefetchKey}',
      ),
      <String>[
        'parkinsum-synthetic-patient-review-a.patient',
        'parkinsum-synthetic-patient-review-b.subject',
      ],
    );
    expect(() => preview.clear(), throwsUnsupportedError);
  });

  test('service-scoped previews preserve only each hook service own keys', () {
    final patientPlans =
        SyntheticCdsHooksServiceRegistry.serviceScopedPrefetchBindingsForHook(
          SyntheticCdsHooksHook.patientView,
        );
    expect(patientPlans, hasLength(2));
    expect(patientPlans.map((plan) => plan.serviceId), <String>[
      'parkinsum-synthetic-patient-review-a',
      'parkinsum-synthetic-patient-review-b',
    ]);
    expect(
      patientPlans.map(
        (plan) => plan.bindings
            .map(
              (binding) =>
                  '${binding.prefetchKey}=${binding.relativeFhirRequest}',
            )
            .join('|'),
      ),
      <String>[
        'patient=Patient/synthetic-patient-001|conditions=Condition?patient=synthetic-patient-001&_count=2',
        'subject=Patient/synthetic-patient-001|problem-list=Condition?patient=synthetic-patient-001&_count=2',
      ],
    );
    expect(() => patientPlans.first.bindings.clear(), throwsUnsupportedError);

    final orderPlans =
        SyntheticCdsHooksServiceRegistry.serviceScopedPrefetchBindingsForHook(
          SyntheticCdsHooksHook.orderSelect,
        );
    expect(orderPlans, hasLength(2));
    expect(orderPlans.map((plan) => plan.serviceId), <String>[
      'parkinsum-synthetic-order-selection-a',
      'parkinsum-synthetic-order-selection-b',
    ]);
    expect(
      orderPlans.every(
        (plan) => plan.hook == SyntheticCdsHooksHook.orderSelect,
      ),
      isTrue,
    );
  });

  test('synthetic prefetch payloads match the strict empty-result fixture', () {
    final responseFixture =
        jsonDecode(
              File(
                'test/fixtures/cds_hooks_multi_service_prefetch.synthetic.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final queryResults =
        responseFixture['queryResults'] as Map<String, dynamic>;
    final templatesByService = <String, Map<String, String>>{
      'parkinsum-synthetic-patient-review-a': <String, String>{
        'patient': 'Patient/{{context.patientId}}',
        'conditions': 'Condition?patient={{context.patientId}}&_count=2',
      },
      'parkinsum-synthetic-patient-review-b': <String, String>{
        'subject': 'Patient/{{context.patientId}}',
        'problem-list': 'Condition?patient={{context.patientId}}&_count=2',
      },
      'parkinsum-synthetic-order-selection-a': <String, String>{
        'patient': 'Patient/{{context.patientId}}',
        'conditions': 'Condition?patient={{context.patientId}}&_count=2',
      },
      'parkinsum-synthetic-order-selection-b': <String, String>{
        'subject': 'Patient/{{context.patientId}}',
        'problem-list': 'Condition?patient={{context.patientId}}&_count=2',
      },
    };

    for (final hook in SyntheticCdsHooksHook.values) {
      final plans =
          SyntheticCdsHooksServiceRegistry.serviceScopedPrefetchPayloadsForHook(
            hook,
          );
      expect(plans, hasLength(2));
      for (final plan in plans) {
        expect(plan.hook, hook);
        final expectedBindings = templatesByService[plan.serviceId]!;
        final expectedPayload = <String, Object?>{
          for (final entry in expectedBindings.entries)
            entry.key: queryResults[entry.value],
        };
        expect(plan.prefetchPayload, expectedPayload);
      }
      expect(() => plans.first.prefetchPayload.clear(), throwsUnsupportedError);
    }

    final patientPlan =
        SyntheticCdsHooksServiceRegistry.serviceScopedPrefetchPayloadsForHook(
          SyntheticCdsHooksHook.patientView,
        ).first;
    final patientResource = patientPlan.prefetchPayload['patient'] as Map;
    expect(patientResource.keys.toSet(), <String>{'resourceType', 'id'});
    expect(patientResource['id'], 'synthetic-patient-001');
    expect(
      () => patientResource['id'] = 'another-patient',
      throwsUnsupportedError,
    );
    final emptySearch = patientPlan.prefetchPayload['conditions'] as Map;
    expect(emptySearch.keys.toSet(), <String>{
      'resourceType',
      'type',
      'total',
      'entry',
    });
    expect(emptySearch['type'], 'searchset');
    expect(emptySearch['total'], 0);
    expect(emptySearch['entry'], isEmpty);
    expect(
      () => (emptySearch['entry'] as List).add(<String, Object?>{}),
      throwsUnsupportedError,
    );
  });

  test('request envelope previews use fixed hook-specific synthetic context', () {
    final hookInstances = <String>{};
    for (final hook in SyntheticCdsHooksHook.values) {
      final plans =
          SyntheticCdsHooksServiceRegistry.serviceRequestEnvelopePreviewsForHook(
            hook,
          );
      expect(plans, hasLength(2));
      final payloadPlans =
          SyntheticCdsHooksServiceRegistry.serviceScopedPrefetchPayloadsForHook(
            hook,
          );
      for (var index = 0; index < plans.length; index++) {
        final plan = plans[index];
        final request = plan.requestBody;
        expect(plan.hook, hook);
        expect(plan.serviceId, payloadPlans[index].serviceId);
        expect(request.keys.toSet(), <String>{
          'hook',
          'hookInstance',
          'context',
          'prefetch',
        });
        expect(request['hook'], hook.wireValue);
        final hookInstance = request['hookInstance'] as String;
        expect(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ).hasMatch(hookInstance),
          isTrue,
        );
        hookInstances.add(hookInstance);
        expect(request['prefetch'], payloadPlans[index].prefetchPayload);
        expect(request['fhirServer'], isNull);
        expect(request['fhirAuthorization'], isNull);
        expect(() => request.clear(), throwsUnsupportedError);

        final context = request['context'] as Map;
        expect(context['userId'], 'Practitioner/synthetic-practitioner-001');
        expect(context['patientId'], 'synthetic-patient-001');
        if (hook == SyntheticCdsHooksHook.patientView) {
          expect(context.keys.toSet(), <String>{'userId', 'patientId'});
        } else {
          expect(context.keys.toSet(), <String>{
            'userId',
            'patientId',
            'selections',
            'draftOrders',
          });
          final selections = context['selections'] as List;
          expect(selections, <String>['ServiceRequest/synthetic-order-001']);
          expect(
            () => selections.add('ServiceRequest/other'),
            throwsUnsupportedError,
          );
          final draftOrders = context['draftOrders'] as Map;
          expect(draftOrders.keys.toSet(), <String>{
            'resourceType',
            'type',
            'entry',
          });
          expect(draftOrders['resourceType'], 'Bundle');
          expect(draftOrders['type'], 'collection');
          final entries = draftOrders['entry'] as List;
          expect(entries, hasLength(1));
          expect(
            () => entries.add(<String, Object?>{}),
            throwsUnsupportedError,
          );
          final entry = entries.single as Map;
          expect(entry['fullUrl'], startsWith('urn:uuid:'));
          final serviceRequest = entry['resource'] as Map;
          expect(serviceRequest.keys.toSet(), <String>{
            'resourceType',
            'id',
            'status',
            'intent',
            'subject',
          });
          expect(serviceRequest['resourceType'], 'ServiceRequest');
          expect(serviceRequest['id'], 'synthetic-order-001');
          expect(serviceRequest['status'], 'draft');
          expect(serviceRequest['intent'], 'order');
          expect(
            (serviceRequest['subject'] as Map)['reference'],
            'Patient/synthetic-patient-001',
          );
        }
      }
    }
    expect(hookInstances, hasLength(4));
  });

  test('prefetch outcomes keep explicit null distinct from an omitted key', () {
    final responseFixture =
        jsonDecode(
              File(
                'test/fixtures/cds_hooks_multi_service_prefetch.synthetic.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final queryResults =
        responseFixture['queryResults'] as Map<String, dynamic>;

    for (final hook in SyntheticCdsHooksHook.values) {
      final plans =
          SyntheticCdsHooksServiceRegistry.serviceScopedPrefetchOutcomePreviewsForHook(
            hook,
          );
      expect(plans, hasLength(2));
      final first = plans.first;
      expect(first.keyOutcomes, <String, SyntheticCdsHooksPrefetchOutcome>{
        'patient': SyntheticCdsHooksPrefetchOutcome.resource,
        'conditions': SyntheticCdsHooksPrefetchOutcome.emptySearchset,
      });
      expect(first.prefetchPayload, <String, Object?>{
        'patient': queryResults['Patient/{{context.patientId}}'],
        'conditions':
            queryResults['Condition?patient={{context.patientId}}&_count=2'],
      });
      final second = plans.last;
      expect(second.keyOutcomes, <String, SyntheticCdsHooksPrefetchOutcome>{
        'subject': SyntheticCdsHooksPrefetchOutcome.explicitNull,
        'problem-list': SyntheticCdsHooksPrefetchOutcome.notSatisfied,
      });
      expect(second.prefetchPayload, <String, Object?>{'subject': null});
      expect(second.prefetchPayload.containsKey('subject'), isTrue);
      expect(second.prefetchPayload.containsKey('problem-list'), isFalse);
      expect(() => second.keyOutcomes.clear(), throwsUnsupportedError);
      expect(
        () => second.prefetchPayload['subject'] = 'not-null',
        throwsUnsupportedError,
      );
    }
  });

  test('synthetic response fixtures remain service-scoped and immutable', () {
    final fixture =
        jsonDecode(
              File(
                'test/fixtures/cds_hooks_multi_service_responses.synthetic.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final fixtureResponses = fixture['responses'] as List<dynamic>;
    for (final hook in SyntheticCdsHooksHook.values) {
      final previews =
          SyntheticCdsHooksServiceRegistry.serviceResponsePreviewsForHook(hook);
      final expected = fixtureResponses
          .where((entry) => entry['hook'] == hook.wireValue)
          .toList();
      expect(previews, hasLength(2));
      expect(previews.map((preview) => preview.toJson()).toList(), expected);
      expect(
        previews.map((preview) => preview.cardCount).toList(),
        expected
            .map((entry) => (entry['response']['cards'] as List).length)
            .toList(),
      );
      expect(() => previews.clear(), throwsUnsupportedError);
      final informationOnly = previews.firstWhere(
        (preview) =>
            preview.state ==
            SyntheticCdsHooksServiceResponseState.informationOnly,
      );
      final cards = informationOnly.response['cards'] as List;
      expect(() => cards.clear(), throwsUnsupportedError);
      expect(() => informationOnly.response.clear(), throwsUnsupportedError);
      expect(informationOnly.response['fhirAuthorization'], isNull);
      expect(informationOnly.response['context'], isNull);
    }
  });
}
