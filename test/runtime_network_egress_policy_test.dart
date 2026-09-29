import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/services/smart_sandbox_discovery_client.dart';
import 'package:parkinsum_companion/core/services/runtime_network_egress_policy.dart';

void main() {
  group('runtime application egress policy', () {
    test('checked-in policy manifest matches the compiled source rules', () {
      final manifest =
          jsonDecode(
                File(
                  'config/runtime_network_egress_policy.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(manifest['schemaVersion'], 1);
      expect(
        manifest['policyVersion'],
        RuntimeNetworkEgressPolicy.currentVersion,
      );
      expect(manifest['status'], 'application_layer_gate_partial');

      final compiledRules =
          RuntimeNetworkEgressPolicy.publicCatalogImport.rules;
      final manifestRules = (manifest['rules'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final sourceRules = manifestRules
          .where((rule) => rule['purpose'] == 'public_catalog_import')
          .toList(growable: false);
      expect(sourceRules.length, compiledRules.length);
      for (final rule in compiledRules) {
        final entry = sourceRules.singleWhere(
          (value) => value['id'] == rule.id,
        );
        expect(entry['scheme'], rule.schemes.toList()..sort());
        expect(entry['hostPattern'], rule.hosts.single);
        expect(entry['port'], rule.ports.toList()..sort());
        expect(entry['pathPattern'], rule.pathPrefixes.toList()..sort());
        expect(entry['method'], rule.methods.toList()..sort());
        expect(
          entry['permittedDataClasses'],
          rule.dataClasses.map((value) => value.name).toList()..sort(),
        );
      }

      final localAiRule = manifestRules.singleWhere(
        (rule) => rule['id'] == 'user-configured-loopback-model',
      );
      final declaredLoopbackHosts =
          (localAiRule['hostPattern'] as List<dynamic>).cast<String>()..sort();
      final compiledLoopbackHosts =
          RuntimeNetworkEgressPolicy.localAiLoopback.rules.single.hosts.toList()
            ..sort();
      expect(declaredLoopbackHosts, compiledLoopbackHosts);
      expect(localAiRule['maxRequestBodyBytes'], 2 * 1024 * 1024);
      final sandboxRule = manifestRules.singleWhere(
        (rule) => rule['id'] == 'smart-health-it-r4-discovery',
      );
      final compiledSandboxRule =
          RuntimeNetworkEgressPolicy.smartSandboxDiscovery.rules.single;
      expect(sandboxRule['hostPattern'], compiledSandboxRule.hosts.single);
      expect(
        sandboxRule['pathPattern'],
        compiledSandboxRule.exactPaths.toList(),
      );
      expect(sandboxRule['method'], ['GET']);
      expect(sandboxRule['redirects'], 'deny');
      expect(sandboxRule['query'], 'deny');
      expect(
        sandboxRule['maxResponseBodyBytes'],
        SmartSandboxDiscoveryClient.maxResponseBytes,
      );
      final labelRule = RuntimeNetworkEgressPolicy
          .userInitiatedOpenFdaLabelLookup
          .rules
          .single;
      final manifestLabelRule = manifestRules.singleWhere(
        (rule) => rule['id'] == labelRule.id,
      );
      expect(manifestLabelRule['hostPattern'], labelRule.hosts.single);
      expect(manifestLabelRule['pathPattern'], labelRule.exactPaths.toList());
      expect(manifestLabelRule['method'], ['GET']);
      expect(manifestLabelRule['redirects'], 'deny');
      expect(manifestLabelRule['allowedQueryParameters'], ['search', 'limit']);
      expect(manifestLabelRule['requiredQueryParameters'], ['search', 'limit']);
      expect(manifestLabelRule['permittedDataClasses'], [
        'userEnteredDrugName',
      ]);
      expect(manifestLabelRule['maxRequestBodyBytes'], 0);
      expect(manifestLabelRule['maxResponseBodyBytes'], 2 * 1024 * 1024);
      final selectedCandidatePolicy = RuntimeNetworkEgressPolicy
          .userInitiatedOpenFdaRxNormCandidateLabelLookup;
      final selectedCandidateRule = selectedCandidatePolicy.rules.single;
      final manifestSelectedCandidateRule = manifestRules.singleWhere(
        (rule) => rule['id'] == selectedCandidateRule.id,
      );
      expect(manifestSelectedCandidateRule['hostPattern'], 'api.fda.gov');
      expect(manifestSelectedCandidateRule['pathPattern'], [
        '/drug/label.json',
      ]);
      expect(manifestSelectedCandidateRule['method'], ['GET']);
      expect(manifestSelectedCandidateRule['redirects'], 'deny');
      expect(manifestSelectedCandidateRule['allowedQueryParameters'], [
        'search',
        'limit',
      ]);
      expect(manifestSelectedCandidateRule['requiredQueryParameters'], [
        'search',
        'limit',
      ]);
      expect(
        manifestSelectedCandidateRule['purpose'],
        'user_initiated_openfda_rxnorm_candidate_label_lookup',
      );
      expect(manifestSelectedCandidateRule['permittedDataClasses'], [
        'userSelectedRxNormCandidateDisplayName',
      ]);
      expect(manifestSelectedCandidateRule['maxRequestBodyBytes'], 0);
      expect(
        manifestSelectedCandidateRule['maxResponseBodyBytes'],
        2 * 1024 * 1024,
      );
      final candidateDecision = selectedCandidatePolicy.evaluate(
        uri: Uri.https('api.fda.gov', '/drug/label.json', const {
          'search': 'openfda.generic_name:"alpha compound"',
          'limit': '5',
        }),
        method: 'GET',
        purpose: RuntimeNetworkEgressPurpose
            .userInitiatedOpenFdaRxNormCandidateLabelLookup,
        dataClasses: const {
          RuntimeNetworkDataClass.userSelectedRxNormCandidateDisplayName,
        },
        headers: const {'Accept': 'application/json'},
        requestBodyBytes: 0,
        followsRedirects: false,
      );
      expect(candidateDecision.allowed, isTrue);
      expect(
        candidateDecision.ruleId,
        'openfda-rxnorm-candidate-label-user-lookup',
      );
      expect(
        selectedCandidatePolicy
            .evaluate(
              uri: Uri.https('api.fda.gov', '/drug/label.json', const {
                'search': 'openfda.generic_name:"alpha compound"',
                'limit': '5',
              }),
              method: 'GET',
              purpose: RuntimeNetworkEgressPurpose
                  .userInitiatedOpenFdaRxNormCandidateLabelLookup,
              dataClasses: const {RuntimeNetworkDataClass.userEnteredDrugName},
              headers: const {'Accept': 'application/json'},
              requestBodyBytes: 0,
              followsRedirects: false,
            )
            .reasonCode,
        'data_class_not_allowed',
      );
      final rxNormRule = RuntimeNetworkEgressPolicy
          .userInitiatedRxNormNameCandidateLookup
          .rules
          .single;
      final manifestRxNormRule = manifestRules.singleWhere(
        (rule) => rule['id'] == rxNormRule.id,
      );
      expect(manifestRxNormRule['hostPattern'], rxNormRule.hosts.single);
      expect(manifestRxNormRule['pathPattern'], rxNormRule.exactPaths.toList());
      expect(manifestRxNormRule['method'], ['GET']);
      expect(manifestRxNormRule['redirects'], 'deny');
      expect(manifestRxNormRule['allowedQueryParameters'], [
        'term',
        'maxEntries',
        'option',
      ]);
      expect(manifestRxNormRule['requiredQueryParameters'], [
        'term',
        'maxEntries',
        'option',
      ]);
      expect(
        manifestRxNormRule['purpose'],
        'user_initiated_rxnorm_name_candidate_lookup',
      );
      expect(manifestRxNormRule['permittedDataClasses'], [
        'userEnteredDrugName',
      ]);
      expect(manifestRxNormRule['maxRequestBodyBytes'], 0);
      expect(manifestRxNormRule['maxResponseBodyBytes'], 256 * 1024);
      final rxNormPropertiesPolicy =
          RuntimeNetworkEgressPolicy.userInitiatedRxNormConceptPropertiesLookup(
            '12345',
          );
      final rxNormPropertiesRule = rxNormPropertiesPolicy.rules.single;
      final manifestPropertiesRule = manifestRules.singleWhere(
        (rule) => rule['id'] == rxNormPropertiesRule.id,
      );
      expect(manifestPropertiesRule['hostPattern'], 'rxnav.nlm.nih.gov');
      expect(manifestPropertiesRule['pathPattern'], [
        '/REST/rxcui/{numericRxCui}/properties.json',
      ]);
      expect(manifestPropertiesRule['method'], ['GET']);
      expect(manifestPropertiesRule['query'], 'deny');
      expect(
        manifestPropertiesRule['purpose'],
        'user_initiated_rxnorm_concept_properties_lookup',
      );
      expect(manifestPropertiesRule['permittedDataClasses'], [
        'userSelectedRxCui',
      ]);
      expect(manifestPropertiesRule['maxRequestBodyBytes'], 0);
      expect(manifestPropertiesRule['maxResponseBodyBytes'], 16 * 1024);
      final rxNormHistoryPolicy =
          RuntimeNetworkEgressPolicy.userInitiatedRxNormConceptHistoryLookup(
            '12345',
          );
      final rxNormHistoryRule = rxNormHistoryPolicy.rules.single;
      final manifestHistoryRule = manifestRules.singleWhere(
        (rule) => rule['id'] == rxNormHistoryRule.id,
      );
      expect(manifestHistoryRule['hostPattern'], 'rxnav.nlm.nih.gov');
      expect(manifestHistoryRule['pathPattern'], [
        '/REST/rxcui/{numericRxCui}/historystatus.json',
      ]);
      expect(manifestHistoryRule['method'], ['GET']);
      expect(manifestHistoryRule['query'], 'deny');
      expect(
        manifestHistoryRule['purpose'],
        'user_initiated_rxnorm_concept_history_lookup',
      );
      expect(manifestHistoryRule['permittedDataClasses'], [
        'userSelectedRxCui',
      ]);
      expect(manifestHistoryRule['maxRequestBodyBytes'], 0);
      expect(manifestHistoryRule['maxResponseBodyBytes'], 64 * 1024);
      expect(
        (manifest['notCovered'] as Map<String, dynamic>)['sdkManagedTraffic'],
        isNotEmpty,
      );
    });

    test('allows a declared public source request with a header API key', () {
      final decision = RuntimeNetworkEgressPolicy.publicCatalogImport.evaluate(
        uri: Uri.parse('https://api.nal.usda.gov/fdc/v1/food/12345'),
        method: 'GET',
        purpose: RuntimeNetworkEgressPurpose.publicCatalogImport,
        dataClasses: const {
          RuntimeNetworkDataClass.publicCatalogIdentifier,
          RuntimeNetworkDataClass.operatorSuppliedSourceCredential,
        },
        headers: const {'X-Api-Key': 'synthetic-test-key'},
        requestBodyBytes: 0,
        followsRedirects: false,
      );

      expect(decision.allowed, isTrue);
      expect(decision.ruleId, 'usda-food-data-central');
    });

    test('user-entered drug names have a separate exact OpenFDA rule', () {
      final policy = RuntimeNetworkEgressPolicy.userInitiatedOpenFdaLabelLookup;
      RuntimeNetworkEgressDecision evaluate(
        Uri uri, {
        Set<RuntimeNetworkDataClass> dataClasses = const {
          RuntimeNetworkDataClass.userEnteredDrugName,
        },
        Map<String, String> headers = const {'Accept': 'application/json'},
        int bodyBytes = 0,
        bool redirects = false,
      }) => policy.evaluate(
        uri: uri,
        method: 'GET',
        purpose: RuntimeNetworkEgressPurpose.userInitiatedOpenFdaLabelLookup,
        dataClasses: dataClasses,
        headers: headers,
        requestBodyBytes: bodyBytes,
        followsRedirects: redirects,
      );

      final allowed = evaluate(
        Uri.https('api.fda.gov', '/drug/label.json', const {
          'search': 'openfda.generic_name:"alpha compound"',
          'limit': '5',
        }),
      );
      expect(allowed.allowed, isTrue);
      expect(allowed.ruleId, 'openfda-drug-label-user-lookup');
      expect(
        evaluate(
          Uri.parse(
            'https://api.fda.gov/drug/label.json?search=name&limit=5&api_key=x',
          ),
        ).reasonCode,
        'query_parameter_not_allowed',
      );
      expect(
        evaluate(
          Uri.parse('https://api.fda.gov/drug/label.json?search=name'),
        ).reasonCode,
        'query_parameter_required',
      );
      expect(
        evaluate(
          Uri.parse(
            'https://api.fda.gov/drug/label.json?search=a&search=b&limit=5',
          ),
        ).reasonCode,
        'duplicate_query_parameter_rejected',
      );
      expect(
        evaluate(
          Uri.parse('https://api.fda.gov/drug/label.json?search=name&limit=5'),
          dataClasses: const {RuntimeNetworkDataClass.publicCatalogIdentifier},
        ).reasonCode,
        'data_class_not_allowed',
      );
      expect(
        evaluate(
          Uri.parse('https://api.fda.gov/drug/label.json?search=name&limit=5'),
          dataClasses: const {
            RuntimeNetworkDataClass.userSelectedRxNormCandidateDisplayName,
          },
        ).reasonCode,
        'data_class_not_allowed',
        reason: 'manual input lookup cannot accept selected RxNorm data',
      );
      expect(
        evaluate(
          Uri.parse('https://api.fda.gov/drug/label.json?search=name&limit=5'),
          bodyBytes: 1,
        ).reasonCode,
        'request_body_not_allowed',
      );
    });

    test('user-entered terms have a separate exact RxNav candidate rule', () {
      final policy =
          RuntimeNetworkEgressPolicy.userInitiatedRxNormNameCandidateLookup;
      RuntimeNetworkEgressDecision evaluate(
        Uri uri, {
        Set<RuntimeNetworkDataClass> dataClasses = const {
          RuntimeNetworkDataClass.userEnteredDrugName,
        },
        Map<String, String> headers = const {'Accept': 'application/json'},
        int bodyBytes = 0,
        bool redirects = false,
      }) => policy.evaluate(
        uri: uri,
        method: 'GET',
        purpose:
            RuntimeNetworkEgressPurpose.userInitiatedRxNormNameCandidateLookup,
        dataClasses: dataClasses,
        headers: headers,
        requestBodyBytes: bodyBytes,
        followsRedirects: redirects,
      );

      final allowed = evaluate(
        Uri.https('rxnav.nlm.nih.gov', '/REST/approximateTerm.json', const {
          'term': 'alpha compound',
          'maxEntries': '10',
          'option': '1',
        }),
      );
      expect(allowed.allowed, isTrue);
      expect(allowed.ruleId, 'rxnav-approximate-term-user-lookup');
      expect(
        evaluate(
          Uri.https('rxnav.nlm.nih.gov', '/REST/approximateTerm.json', const {
            'term': 'alpha compound',
            'maxEntries': '10',
            'option': '1',
            'api_key': 'synthetic',
          }),
        ).reasonCode,
        'query_parameter_not_allowed',
      );
      expect(
        evaluate(
          Uri.https('rxnav.nlm.nih.gov', '/REST/approximateTerm.json', const {
            'term': 'alpha compound',
            'maxEntries': '10',
          }),
        ).reasonCode,
        'query_parameter_required',
      );
      expect(
        evaluate(
          Uri.parse(
            'https://rxnav.nlm.nih.gov/REST/approximateTerm.json?term=a&term=b&maxEntries=10&option=1',
          ),
        ).reasonCode,
        'duplicate_query_parameter_rejected',
      );
      expect(
        evaluate(
          Uri.https(
            'rxnav.nlm.nih.gov.attacker.test',
            '/REST/approximateTerm.json',
            const {'term': 'alpha compound', 'maxEntries': '10', 'option': '1'},
          ),
        ).reasonCode,
        'destination_not_declared',
      );
      expect(
        evaluate(
          Uri.https('rxnav.nlm.nih.gov', '/REST/other.json', const {
            'term': 'alpha compound',
            'maxEntries': '10',
            'option': '1',
          }),
        ).reasonCode,
        'path_not_allowed',
      );
      expect(
        evaluate(
          Uri.https('rxnav.nlm.nih.gov', '/REST/approximateTerm.json', const {
            'term': 'alpha compound',
            'maxEntries': '10',
            'option': '1',
          }),
          dataClasses: const {RuntimeNetworkDataClass.publicCatalogIdentifier},
        ).reasonCode,
        'data_class_not_allowed',
      );
      expect(
        evaluate(
          Uri.https('rxnav.nlm.nih.gov', '/REST/approximateTerm.json', const {
            'term': 'alpha compound',
            'maxEntries': '10',
            'option': '1',
          }),
          headers: const {'Authorization': 'Bearer synthetic'},
        ).reasonCode,
        'header_not_allowed',
      );
      expect(
        evaluate(
          Uri.https('rxnav.nlm.nih.gov', '/REST/approximateTerm.json', const {
            'term': 'alpha compound',
            'maxEntries': '10',
            'option': '1',
          }),
          redirects: true,
        ).reasonCode,
        'redirects_not_allowed',
      );
    });

    test('selected RxCUI properties use a separately scoped exact path', () {
      final rxCui = '12345';
      final policy =
          RuntimeNetworkEgressPolicy.userInitiatedRxNormConceptPropertiesLookup(
            rxCui,
          );
      RuntimeNetworkEgressDecision evaluate(
        Uri uri, {
        Set<RuntimeNetworkDataClass> dataClasses = const {
          RuntimeNetworkDataClass.userSelectedRxCui,
        },
        Map<String, String> headers = const {'Accept': 'application/json'},
        int bodyBytes = 0,
        bool redirects = false,
      }) => policy.evaluate(
        uri: uri,
        method: 'GET',
        purpose: RuntimeNetworkEgressPurpose
            .userInitiatedRxNormConceptPropertiesLookup,
        dataClasses: dataClasses,
        headers: headers,
        requestBodyBytes: bodyBytes,
        followsRedirects: redirects,
      );

      final allowed = evaluate(
        Uri.https('rxnav.nlm.nih.gov', '/REST/rxcui/12345/properties.json'),
      );
      expect(allowed.allowed, isTrue);
      expect(allowed.ruleId, 'rxnav-concept-properties-user-lookup');
      expect(
        evaluate(
          Uri.https('rxnav.nlm.nih.gov', '/REST/rxcui/54321/properties.json'),
        ).reasonCode,
        'path_not_allowed',
      );
      expect(
        evaluate(
          Uri.https(
            'rxnav.nlm.nih.gov',
            '/REST/rxcui/12345/properties.json',
            const {'prop': 'ALL'},
          ),
        ).reasonCode,
        'query_not_allowed',
      );
      expect(
        evaluate(
          Uri.https('rxnav.nlm.nih.gov', '/REST/rxcui/12345/properties.json'),
          dataClasses: const {RuntimeNetworkDataClass.userEnteredDrugName},
        ).reasonCode,
        'data_class_not_allowed',
      );
      expect(
        evaluate(
          Uri.https('rxnav.nlm.nih.gov', '/REST/rxcui/12345/properties.json'),
          headers: const {'Authorization': 'Bearer synthetic'},
        ).reasonCode,
        'header_not_allowed',
      );
      expect(
        evaluate(
          Uri.https('rxnav.nlm.nih.gov', '/REST/rxcui/12345/properties.json'),
          redirects: true,
        ).reasonCode,
        'redirects_not_allowed',
      );
      expect(
        () =>
            RuntimeNetworkEgressPolicy.userInitiatedRxNormConceptPropertiesLookup(
              '123/45',
            ),
        throwsArgumentError,
      );
    });

    test('selected RxCUI history uses a separately scoped exact path', () {
      const rxCui = '12345';
      final policy =
          RuntimeNetworkEgressPolicy.userInitiatedRxNormConceptHistoryLookup(
            rxCui,
          );
      final decision = policy.evaluate(
        uri: Uri.https(
          'rxnav.nlm.nih.gov',
          '/REST/rxcui/$rxCui/historystatus.json',
        ),
        method: 'GET',
        purpose:
            RuntimeNetworkEgressPurpose.userInitiatedRxNormConceptHistoryLookup,
        dataClasses: const {RuntimeNetworkDataClass.userSelectedRxCui},
        headers: const {'Accept': 'application/json'},
        requestBodyBytes: 0,
        followsRedirects: false,
      );
      expect(decision.allowed, isTrue);
      expect(decision.ruleId, 'rxnav-concept-history-user-lookup');
      expect(
        policy
            .evaluate(
              uri: Uri.https(
                'rxnav.nlm.nih.gov',
                '/REST/rxcui/54321/historystatus.json',
              ),
              method: 'GET',
              purpose: RuntimeNetworkEgressPurpose
                  .userInitiatedRxNormConceptHistoryLookup,
              dataClasses: const {RuntimeNetworkDataClass.userSelectedRxCui},
              headers: const {'Accept': 'application/json'},
              requestBodyBytes: 0,
              followsRedirects: false,
            )
            .reasonCode,
        'path_not_allowed',
      );
      expect(
        () =>
            RuntimeNetworkEgressPolicy.userInitiatedRxNormConceptHistoryLookup(
              '123/45',
            ),
        throwsArgumentError,
      );
    });

    test('denies unknown hosts, host suffix tricks, and undeclared paths', () {
      for (final url in [
        'https://unknown.example.test/data',
        'https://api.nal.usda.gov.attacker.test/fdc/v1/food/12345',
        'https://api.nal.usda.gov/private/metadata',
      ]) {
        final decision = _evaluatePublic(url);
        expect(decision.allowed, isFalse, reason: url);
        expect(
          decision.reasonCode,
          anyOf('destination_not_declared', 'path_not_allowed'),
          reason: url,
        );
      }
    });

    test(
      'denies unsafe URL components, ports, query credentials, and methods',
      () {
        final cases = <({String url, String method, String? expected})>[
          (
            url: 'https://user:password@api.nal.usda.gov/fdc/v1/food/12345',
            method: 'GET',
            expected: 'userinfo_rejected',
          ),
          (
            url: 'https://api.nal.usda.gov:8443/fdc/v1/food/12345',
            method: 'GET',
            expected: 'port_not_allowed',
          ),
          (
            url: 'https://api.nal.usda.gov/fdc/v1/food/12345#frag',
            method: 'GET',
            expected: 'fragment_rejected',
          ),
          (
            url: 'https://api.nal.usda.gov/fdc/v1/food/12345?api_key=secret',
            method: 'GET',
            expected: 'credential_query_parameter_rejected',
          ),
          (
            url: 'https://api.nal.usda.gov/fdc/v1/food/12345',
            method: 'POST',
            expected: 'method_not_allowed',
          ),
        ];

        for (final item in cases) {
          final decision = _evaluatePublic(item.url, method: item.method);
          expect(decision.allowed, isFalse, reason: item.url);
          expect(decision.reasonCode, item.expected, reason: item.url);
        }
      },
    );

    test(
      'rejects data classes, headers, bodies, and redirects outside policy',
      () {
        final base = Uri.parse(
          'https://dailymed.nlm.nih.gov/dailymed/services/v2/spls.json',
        );
        RuntimeNetworkEgressDecision evaluate({
          Set<RuntimeNetworkDataClass>? dataClasses,
          Map<String, String> headers = const {},
          int bodyBytes = 0,
          bool redirects = false,
        }) => RuntimeNetworkEgressPolicy.publicCatalogImport.evaluate(
          uri: base,
          method: 'GET',
          purpose: RuntimeNetworkEgressPurpose.publicCatalogImport,
          dataClasses:
              dataClasses ??
              const {RuntimeNetworkDataClass.publicCatalogIdentifier},
          headers: headers,
          requestBodyBytes: bodyBytes,
          followsRedirects: redirects,
        );

        expect(
          evaluate(
            dataClasses: const {
              RuntimeNetworkDataClass.userSelectedHealthContext,
            },
          ).reasonCode,
          'data_class_not_allowed',
        );
        expect(
          evaluate(headers: const {'Cookie': 'session=secret'}).reasonCode,
          'header_not_allowed',
        );
        expect(evaluate(bodyBytes: 1).reasonCode, 'request_body_not_allowed');
        expect(evaluate(redirects: true).reasonCode, 'redirects_not_allowed');
      },
    );

    test('local AI rules keep health context confined to loopback', () {
      final allowed = RuntimeNetworkEgressPolicy.localAiLoopback.evaluate(
        uri: Uri.parse('http://127.0.0.1:11434/api/chat'),
        method: 'POST',
        purpose: RuntimeNetworkEgressPurpose.localAiRecommendation,
        dataClasses: const {RuntimeNetworkDataClass.userSelectedHealthContext},
        headers: const {'Content-Type': 'application/json'},
        requestBodyBytes: 128,
        followsRedirects: false,
      );
      final denied = RuntimeNetworkEgressPolicy.localAiLoopback.evaluate(
        uri: Uri.parse('https://model.example.test/api/chat'),
        method: 'POST',
        purpose: RuntimeNetworkEgressPurpose.localAiRecommendation,
        dataClasses: const {RuntimeNetworkDataClass.userSelectedHealthContext},
        headers: const {'Content-Type': 'application/json'},
        requestBodyBytes: 128,
        followsRedirects: false,
      );

      expect(allowed.allowed, isTrue);
      expect(allowed.ruleId, 'user-configured-loopback-model');
      expect(denied.allowed, isFalse);
      expect(denied.reasonCode, 'destination_not_declared');
    });

    test('capability distribution rule binds the configured host and path', () {
      final endpoint = Uri.parse(
        'https://updates.example.test/manifests/capabilities.json',
      );
      final policy = RuntimeNetworkEgressPolicy.capabilityManifestEndpoint(
        endpoint: endpoint,
        allowedHosts: const {'updates.example.test'},
      );
      RuntimeNetworkEgressDecision evaluate(Uri uri) => policy.evaluate(
        uri: uri,
        method: 'GET',
        purpose: RuntimeNetworkEgressPurpose.signedCapabilityManifestFetch,
        dataClasses: const {RuntimeNetworkDataClass.publicCapabilityValidator},
        headers: const {'Accept': 'application/json'},
        requestBodyBytes: 0,
        followsRedirects: false,
      );

      expect(evaluate(endpoint).allowed, isTrue);
      expect(
        evaluate(
          Uri.parse('https://updates.example.test/other.json'),
        ).reasonCode,
        'path_not_allowed',
      );
      expect(
        evaluate(Uri.parse('${endpoint.toString()}?token=secret')).reasonCode,
        'query_not_allowed',
      );
    });

    test('SMART sandbox policy allows only the fixed discovery GET', () {
      RuntimeNetworkEgressDecision evaluate({
        String url =
            'https://launch.smarthealthit.org/v/r4/fhir/.well-known/smart-configuration',
        String method = 'GET',
        Set<RuntimeNetworkDataClass> dataClasses = const {
          RuntimeNetworkDataClass.publicSandboxMetadata,
        },
        Map<String, String> headers = const {'Accept': 'application/json'},
        int bodyBytes = 0,
        bool redirects = false,
      }) => RuntimeNetworkEgressPolicy.smartSandboxDiscovery.evaluate(
        uri: Uri.parse(url),
        method: method,
        purpose: RuntimeNetworkEgressPurpose.smartSandboxDiscovery,
        dataClasses: dataClasses,
        headers: headers,
        requestBodyBytes: bodyBytes,
        followsRedirects: redirects,
      );

      final allowed = evaluate();
      expect(allowed.allowed, isTrue);
      expect(allowed.ruleId, 'smart-health-it-r4-discovery');
      expect(
        evaluate(
          url: 'https://launch.smarthealthit.org/v/r4/fhir/Patient',
        ).allowed,
        isFalse,
      );
      expect(
        evaluate(
          url:
              'https://launch.smarthealthit.org.attacker.test/v/r4/fhir/.well-known/smart-configuration',
        ).allowed,
        isFalse,
      );
      expect(evaluate(method: 'POST').allowed, isFalse);
      expect(
        evaluate(
          url: '${SmartSandboxDiscoveryClient.discoveryUrl}?x=1',
        ).allowed,
        isFalse,
      );
      expect(evaluate(bodyBytes: 1).allowed, isFalse);
      expect(evaluate(redirects: true).allowed, isFalse);
      expect(
        evaluate(
          dataClasses: const {
            RuntimeNetworkDataClass.publicSandboxMetadata,
            RuntimeNetworkDataClass.userSelectedHealthContext,
          },
        ).allowed,
        isFalse,
      );
      expect(
        evaluate(
          headers: const {'Accept': 'application/json', 'Cookie': 'x'},
        ).allowed,
        isFalse,
      );
    });
  });
}

RuntimeNetworkEgressDecision _evaluatePublic(
  String url, {
  String method = 'GET',
}) => RuntimeNetworkEgressPolicy.publicCatalogImport.evaluate(
  uri: Uri.parse(url),
  method: method,
  purpose: RuntimeNetworkEgressPurpose.publicCatalogImport,
  dataClasses: const {RuntimeNetworkDataClass.publicCatalogIdentifier},
  headers: const {},
  requestBodyBytes: 0,
  followsRedirects: false,
);
