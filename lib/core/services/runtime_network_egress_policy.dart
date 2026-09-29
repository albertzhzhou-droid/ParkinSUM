/// Application-owned HTTP egress policy.
///
/// This is an application-layer gate: it checks the declared purpose and data
/// classes, URI shape, method, headers, request-body size, and redirect mode
/// before an HTTP request is handed to its transport. It does not observe DNS,
/// proxy selection, socket addresses, SDK-managed traffic, or packaged release
/// behavior; those remain separate attestation work.
enum RuntimeNetworkEgressPurpose {
  publicCatalogImport,
  userInitiatedOpenFdaLabelLookup,
  userInitiatedOpenFdaRxNormCandidateLabelLookup,
  userInitiatedRxNormNameCandidateLookup,
  userInitiatedRxNormConceptPropertiesLookup,
  userInitiatedRxNormConceptHistoryLookup,
  localAiRecommendation,
  signedCapabilityManifestFetch,
  smartSandboxDiscovery,
}

enum RuntimeNetworkDataClass {
  publicCatalogIdentifier,
  userEnteredDrugName,
  userSelectedRxNormCandidateDisplayName,
  operatorSuppliedSourceCredential,
  localModelAvailabilityProbe,
  userSelectedHealthContext,
  publicCapabilityValidator,
  publicSandboxMetadata,
  userSelectedRxCui,
}

final class RuntimeNetworkEgressDecision {
  const RuntimeNetworkEgressDecision._({
    required this.allowed,
    required this.reasonCode,
    this.ruleId,
  });

  final bool allowed;
  final String reasonCode;
  final String? ruleId;

  static const allow = RuntimeNetworkEgressDecision._(
    allowed: true,
    reasonCode: 'allowed',
  );

  static RuntimeNetworkEgressDecision deny(String reasonCode) =>
      RuntimeNetworkEgressDecision._(allowed: false, reasonCode: reasonCode);

  static RuntimeNetworkEgressDecision allowByRule(String ruleId) =>
      RuntimeNetworkEgressDecision._(
        allowed: true,
        reasonCode: 'allowed',
        ruleId: ruleId,
      );
}

/// One destination declaration used by every application-owned HTTP client.
/// Exact hosts are intentional. `allowAnyPort` is reserved for user-configured
/// loopback services and still requires a valid, nonzero port.
final class RuntimeNetworkEgressRule {
  RuntimeNetworkEgressRule({
    required this.id,
    required this.purpose,
    required Set<String> schemes,
    required Set<String> hosts,
    required Set<int> ports,
    this.allowAnyPort = false,
    required Set<String> exactPaths,
    required Set<String> pathPrefixes,
    required Set<String> methods,
    required Set<RuntimeNetworkDataClass> dataClasses,
    required Set<String> allowedHeaders,
    required this.allowQuery,
    Set<String>? allowedQueryParameters,
    Set<String>? requiredQueryParameters,
    required this.maxRequestBodyBytes,
    this.allowRedirects = false,
  }) : schemes = Set<String>.unmodifiable(
         schemes.map((value) => value.toLowerCase()),
       ),
       hosts = Set<String>.unmodifiable(
         hosts.map((value) => value.toLowerCase()),
       ),
       ports = Set<int>.unmodifiable(ports),
       exactPaths = Set<String>.unmodifiable(exactPaths),
       pathPrefixes = Set<String>.unmodifiable(pathPrefixes),
       methods = Set<String>.unmodifiable(
         methods.map((value) => value.toUpperCase()),
       ),
       dataClasses = Set<RuntimeNetworkDataClass>.unmodifiable(dataClasses),
       allowedHeaders = Set<String>.unmodifiable(
         allowedHeaders.map((value) => value.toLowerCase()),
       ),
       allowedQueryParameters = allowedQueryParameters == null
           ? null
           : Set<String>.unmodifiable(
               allowedQueryParameters.map((value) => value.toLowerCase()),
             ),
       requiredQueryParameters = requiredQueryParameters == null
           ? null
           : Set<String>.unmodifiable(
               requiredQueryParameters.map((value) => value.toLowerCase()),
             );

  final String id;
  final RuntimeNetworkEgressPurpose purpose;
  final Set<String> schemes;
  final Set<String> hosts;
  final Set<int> ports;
  final bool allowAnyPort;
  final Set<String> exactPaths;
  final Set<String> pathPrefixes;
  final Set<String> methods;
  final Set<RuntimeNetworkDataClass> dataClasses;
  final Set<String> allowedHeaders;
  final bool allowQuery;
  final Set<String>? allowedQueryParameters;
  final Set<String>? requiredQueryParameters;
  final int maxRequestBodyBytes;
  final bool allowRedirects;

  bool matchesHost(String host) => hosts.contains(host.toLowerCase());

  bool matchesPath(String path) =>
      exactPaths.contains(path) ||
      pathPrefixes.any((prefix) => path.startsWith(prefix));
}

/// Versioned, fail-closed evaluator shared by all `package:http` clients.
final class RuntimeNetworkEgressPolicy {
  RuntimeNetworkEgressPolicy({
    required this.version,
    required Iterable<RuntimeNetworkEgressRule> rules,
  }) : rules = List<RuntimeNetworkEgressRule>.unmodifiable(rules);

  static const currentVersion = '2026.09.25-v6';

  static final publicCatalogImport = RuntimeNetworkEgressPolicy(
    version: currentVersion,
    rules: <RuntimeNetworkEgressRule>[
      _publicSourceRule(
        'ciqual-public-datafile',
        'entrepot.recherche.data.gouv.fr',
        const {'/api/access/datafile/'},
      ),
      _publicSourceRule('usda-food-data-central', 'api.nal.usda.gov', const {
        '/fdc/v1/',
      }, allowApiKey: true),
      _publicSourceRule('openfda-ndc', 'api.fda.gov', const {'/drug/ndc.json'}),
      _publicSourceRule('dailymed-spl-service', 'dailymed.nlm.nih.gov', const {
        '/dailymed/services/v2/spls.json',
        '/dailymed/services/v2/spls/',
      }),
      _publicSourceRule(
        'health-canada-dpd-api',
        'health-products.canada.ca',
        const {'/api/drug/', '/dpd-bdpp/info'},
      ),
      _publicSourceRule('ema-medicine-downloads', 'www.ema.europa.eu', const {
        '/en/documents/report/',
      }),
      _publicSourceRule('pmda-english-insert-index', 'www.pmda.go.jp', const {
        '/english/safety/info-services/drugs/package-inserts/',
      }),
      _publicSourceRule(
        'pmda-japanese-search-landing',
        'www.pmda.go.jp',
        const {'/PmdaSearch/iyakuSearch/'},
      ),
      _publicSourceRule('fao-diet-guideline-pages', 'www.fao.org', const {
        '/nutrition/education/food-dietary-guidelines/regions/countries/',
      }),
      _publicSourceRule(
        'china-nutrition-reference-pages',
        'nlc.chinanutri.cn',
        const {'/fq/foodinfo/'},
      ),
    ],
  );

  /// Allows two exact, user-entered generic-name label searches. The query
  /// names are confined to `search` and `limit`; no profile or saved
  /// medication record is available to this policy.
  static final userInitiatedOpenFdaLabelLookup = RuntimeNetworkEgressPolicy(
    version: currentVersion,
    rules: <RuntimeNetworkEgressRule>[
      RuntimeNetworkEgressRule(
        id: 'openfda-drug-label-user-lookup',
        purpose: RuntimeNetworkEgressPurpose.userInitiatedOpenFdaLabelLookup,
        schemes: const {'https'},
        hosts: const {'api.fda.gov'},
        ports: const {443},
        exactPaths: const {'/drug/label.json'},
        pathPrefixes: const <String>{},
        methods: const {'GET'},
        dataClasses: const {RuntimeNetworkDataClass.userEnteredDrugName},
        allowedHeaders: const {'accept'},
        allowQuery: true,
        allowedQueryParameters: const {'search', 'limit'},
        requiredQueryParameters: const {'search', 'limit'},
        maxRequestBodyBytes: 0,
      ),
    ],
  );

  /// Allows a separately consented label search over two individually
  /// selected RxNorm display strings. The input class remains distinct from
  /// manually entered names and the request has no saved medication context.
  static final userInitiatedOpenFdaRxNormCandidateLabelLookup =
      RuntimeNetworkEgressPolicy(
        version: currentVersion,
        rules: <RuntimeNetworkEgressRule>[
          RuntimeNetworkEgressRule(
            id: 'openfda-rxnorm-candidate-label-user-lookup',
            purpose: RuntimeNetworkEgressPurpose
                .userInitiatedOpenFdaRxNormCandidateLabelLookup,
            schemes: const {'https'},
            hosts: const {'api.fda.gov'},
            ports: const {443},
            exactPaths: const {'/drug/label.json'},
            pathPrefixes: const <String>{},
            methods: const {'GET'},
            dataClasses: const {
              RuntimeNetworkDataClass.userSelectedRxNormCandidateDisplayName,
            },
            allowedHeaders: const {'accept'},
            allowQuery: true,
            allowedQueryParameters: const {'search', 'limit'},
            requiredQueryParameters: const {'search', 'limit'},
            maxRequestBodyBytes: 0,
          ),
        ],
      );

  /// Allows two manually entered terms to be looked up as active RxNorm
  /// lexical candidates. No saved medication state or UMLS credential is
  /// available to this request.
  static final userInitiatedRxNormNameCandidateLookup =
      RuntimeNetworkEgressPolicy(
        version: currentVersion,
        rules: <RuntimeNetworkEgressRule>[
          RuntimeNetworkEgressRule(
            id: 'rxnav-approximate-term-user-lookup',
            purpose: RuntimeNetworkEgressPurpose
                .userInitiatedRxNormNameCandidateLookup,
            schemes: const {'https'},
            hosts: const {'rxnav.nlm.nih.gov'},
            ports: const {443},
            exactPaths: const {'/REST/approximateTerm.json'},
            pathPrefixes: const <String>{},
            methods: const {'GET'},
            dataClasses: const {RuntimeNetworkDataClass.userEnteredDrugName},
            allowedHeaders: const {'accept'},
            allowQuery: true,
            allowedQueryParameters: const {'term', 'maxEntries', 'option'},
            requiredQueryParameters: const {'term', 'maxEntries', 'option'},
            maxRequestBodyBytes: 0,
          ),
        ],
      );

  /// Binds a read-only properties request to one previously selected numeric
  /// RxCUI. The concrete path is exact; arbitrary RxNav paths are not allowed.
  static RuntimeNetworkEgressPolicy userInitiatedRxNormConceptPropertiesLookup(
    String rxCui,
  ) {
    if (!RegExp(r'^[0-9]{1,20}$').hasMatch(rxCui)) {
      throw ArgumentError.value(rxCui, 'rxCui', 'Must be numeric.');
    }
    return RuntimeNetworkEgressPolicy(
      version: currentVersion,
      rules: <RuntimeNetworkEgressRule>[
        RuntimeNetworkEgressRule(
          id: 'rxnav-concept-properties-user-lookup',
          purpose: RuntimeNetworkEgressPurpose
              .userInitiatedRxNormConceptPropertiesLookup,
          schemes: const {'https'},
          hosts: const {'rxnav.nlm.nih.gov'},
          ports: const {443},
          exactPaths: {'/REST/rxcui/$rxCui/properties.json'},
          pathPrefixes: const <String>{},
          methods: const {'GET'},
          dataClasses: const {RuntimeNetworkDataClass.userSelectedRxCui},
          allowedHeaders: const {'accept'},
          allowQuery: false,
          maxRequestBodyBytes: 0,
        ),
      ],
    );
  }

  /// Binds a separately consented history/status request to one recent numeric
  /// RxCUI; it cannot follow replacement CUIs or access arbitrary RxNav paths.
  static RuntimeNetworkEgressPolicy userInitiatedRxNormConceptHistoryLookup(
    String rxCui,
  ) {
    if (!RegExp(r'^[0-9]{1,20}$').hasMatch(rxCui)) {
      throw ArgumentError.value(rxCui, 'rxCui', 'Must be numeric.');
    }
    return RuntimeNetworkEgressPolicy(
      version: currentVersion,
      rules: <RuntimeNetworkEgressRule>[
        RuntimeNetworkEgressRule(
          id: 'rxnav-concept-history-user-lookup',
          purpose: RuntimeNetworkEgressPurpose
              .userInitiatedRxNormConceptHistoryLookup,
          schemes: const {'https'},
          hosts: const {'rxnav.nlm.nih.gov'},
          ports: const {443},
          exactPaths: {'/REST/rxcui/$rxCui/historystatus.json'},
          pathPrefixes: const <String>{},
          methods: const {'GET'},
          dataClasses: const {RuntimeNetworkDataClass.userSelectedRxCui},
          allowedHeaders: const {'accept'},
          allowQuery: false,
          maxRequestBodyBytes: 0,
        ),
      ],
    );
  }

  static final localAiLoopback = RuntimeNetworkEgressPolicy(
    version: currentVersion,
    rules: <RuntimeNetworkEgressRule>[
      RuntimeNetworkEgressRule(
        id: 'user-configured-loopback-model',
        purpose: RuntimeNetworkEgressPurpose.localAiRecommendation,
        schemes: const {'http', 'https'},
        hosts: const {'127.0.0.1', 'localhost', '::1'},
        ports: const <int>{},
        allowAnyPort: true,
        exactPaths: const <String>{},
        pathPrefixes: const {'/'},
        methods: const {'GET', 'POST'},
        dataClasses: const {
          RuntimeNetworkDataClass.localModelAvailabilityProbe,
          RuntimeNetworkDataClass.userSelectedHealthContext,
        },
        allowedHeaders: const {'accept', 'content-type'},
        allowQuery: false,
        maxRequestBodyBytes: 2 * 1024 * 1024,
      ),
    ],
  );

  /// Allows one user-initiated, bodyless SMART metadata GET in debug builds.
  /// No discovered endpoint is followed and no FHIR resource is requested.
  static final smartSandboxDiscovery = RuntimeNetworkEgressPolicy(
    version: currentVersion,
    rules: <RuntimeNetworkEgressRule>[
      RuntimeNetworkEgressRule(
        id: 'smart-health-it-r4-discovery',
        purpose: RuntimeNetworkEgressPurpose.smartSandboxDiscovery,
        schemes: const {'https'},
        hosts: const {'launch.smarthealthit.org'},
        ports: const {443},
        exactPaths: const {'/v/r4/fhir/.well-known/smart-configuration'},
        pathPrefixes: const <String>{},
        methods: const {'GET'},
        dataClasses: const {RuntimeNetworkDataClass.publicSandboxMetadata},
        allowedHeaders: const {'accept'},
        allowQuery: false,
        maxRequestBodyBytes: 0,
      ),
    ],
  );

  /// Builds the exact rule already constrained by the distribution client's
  /// validated, release-configured host allowlist and endpoint.
  factory RuntimeNetworkEgressPolicy.capabilityManifestEndpoint({
    required Uri endpoint,
    required Set<String> allowedHosts,
  }) => RuntimeNetworkEgressPolicy(
    version: currentVersion,
    rules: <RuntimeNetworkEgressRule>[
      RuntimeNetworkEgressRule(
        id: 'release-configured-capability-manifest-endpoint',
        purpose: RuntimeNetworkEgressPurpose.signedCapabilityManifestFetch,
        schemes: const {'https'},
        hosts: allowedHosts,
        ports: const {443},
        exactPaths: {endpoint.path},
        pathPrefixes: const <String>{},
        methods: const {'GET'},
        dataClasses: const {RuntimeNetworkDataClass.publicCapabilityValidator},
        allowedHeaders: const {'accept', 'if-none-match'},
        allowQuery: false,
        maxRequestBodyBytes: 0,
      ),
    ],
  );

  final String version;
  final List<RuntimeNetworkEgressRule> rules;

  RuntimeNetworkEgressDecision evaluate({
    required Uri uri,
    required String method,
    required RuntimeNetworkEgressPurpose purpose,
    required Set<RuntimeNetworkDataClass> dataClasses,
    required Map<String, String> headers,
    required int? requestBodyBytes,
    required bool followsRedirects,
  }) {
    if (uri.userInfo.isNotEmpty) {
      return RuntimeNetworkEgressDecision.deny('userinfo_rejected');
    }
    if (uri.hasFragment) {
      return RuntimeNetworkEgressDecision.deny('fragment_rejected');
    }
    if (!uri.isAbsolute || uri.host.isEmpty || !uri.hasAuthority) {
      return RuntimeNetworkEgressDecision.deny('uri_invalid');
    }
    if (_hasAmbiguousPath(uri)) {
      return RuntimeNetworkEgressDecision.deny('path_ambiguous');
    }

    final purposeRules = rules.where((rule) => rule.purpose == purpose);
    final hostRules = purposeRules
        .where((rule) => rule.matchesHost(uri.host))
        .toList(growable: false);
    if (hostRules.isEmpty) {
      return RuntimeNetworkEgressDecision.deny('destination_not_declared');
    }
    final rule = hostRules.firstWhere(
      (candidate) => candidate.matchesPath(uri.path),
      orElse: () => hostRules.first,
    );
    if (!rule.matchesPath(uri.path)) {
      return RuntimeNetworkEgressDecision.deny('path_not_allowed');
    }
    if (!rule.schemes.contains(uri.scheme.toLowerCase())) {
      return RuntimeNetworkEgressDecision.deny('scheme_not_allowed');
    }
    final port = uri.port;
    if ((rule.allowAnyPort && (port < 1 || port > 65535)) ||
        (!rule.allowAnyPort && !rule.ports.contains(port))) {
      return RuntimeNetworkEgressDecision.deny('port_not_allowed');
    }
    if (!rule.methods.contains(method.toUpperCase())) {
      return RuntimeNetworkEgressDecision.deny('method_not_allowed');
    }
    if (dataClasses.isEmpty || !rule.dataClasses.containsAll(dataClasses)) {
      return RuntimeNetworkEgressDecision.deny('data_class_not_allowed');
    }
    if (!rule.allowQuery && uri.hasQuery) {
      return RuntimeNetworkEgressDecision.deny('query_not_allowed');
    }
    final queryNames = uri.queryParametersAll.keys
        .map((name) => name.toLowerCase())
        .toSet();
    if (rule.allowedQueryParameters != null &&
        !rule.allowedQueryParameters!.containsAll(queryNames)) {
      return RuntimeNetworkEgressDecision.deny('query_parameter_not_allowed');
    }
    if (rule.requiredQueryParameters != null &&
        !queryNames.containsAll(rule.requiredQueryParameters!)) {
      return RuntimeNetworkEgressDecision.deny('query_parameter_required');
    }
    if (rule.allowedQueryParameters != null &&
        uri.queryParametersAll.values.any((values) => values.length != 1)) {
      return RuntimeNetworkEgressDecision.deny(
        'duplicate_query_parameter_rejected',
      );
    }
    if (_hasCredentialQueryParameter(uri)) {
      return RuntimeNetworkEgressDecision.deny(
        'credential_query_parameter_rejected',
      );
    }
    final headerNames = headers.keys.map((name) => name.toLowerCase()).toSet();
    if (!rule.allowedHeaders.containsAll(headerNames)) {
      return RuntimeNetworkEgressDecision.deny('header_not_allowed');
    }
    if (headers.keys.any((name) => name.toLowerCase() == 'x-api-key') &&
        !dataClasses.contains(
          RuntimeNetworkDataClass.operatorSuppliedSourceCredential,
        )) {
      return RuntimeNetworkEgressDecision.deny('credential_class_not_declared');
    }
    if (requestBodyBytes == null ||
        requestBodyBytes < 0 ||
        requestBodyBytes > rule.maxRequestBodyBytes) {
      return RuntimeNetworkEgressDecision.deny('request_body_not_allowed');
    }
    if (followsRedirects && !rule.allowRedirects) {
      return RuntimeNetworkEgressDecision.deny('redirects_not_allowed');
    }
    return RuntimeNetworkEgressDecision.allowByRule(rule.id);
  }

  static RuntimeNetworkEgressRule _publicSourceRule(
    String id,
    String host,
    Set<String> pathPrefixes, {
    bool allowApiKey = false,
  }) => RuntimeNetworkEgressRule(
    id: id,
    purpose: RuntimeNetworkEgressPurpose.publicCatalogImport,
    schemes: const {'https'},
    hosts: {host},
    ports: const {443},
    exactPaths: const <String>{},
    pathPrefixes: pathPrefixes,
    methods: const {'GET'},
    dataClasses: {
      RuntimeNetworkDataClass.publicCatalogIdentifier,
      if (allowApiKey) RuntimeNetworkDataClass.operatorSuppliedSourceCredential,
    },
    allowedHeaders: {
      'accept',
      'if-modified-since',
      'if-none-match',
      if (allowApiKey) 'x-api-key',
    },
    allowQuery: true,
    maxRequestBodyBytes: 0,
  );

  static bool _hasAmbiguousPath(Uri uri) {
    if (uri.path.isEmpty || !uri.path.startsWith('/')) return true;
    if (uri.normalizePath().path != uri.path) return true;
    for (final segment in uri.pathSegments) {
      if (segment == '.' ||
          segment == '..' ||
          segment.contains('/') ||
          segment.contains('\\') ||
          segment.contains('\u0000')) {
        return true;
      }
    }
    return false;
  }

  static bool _hasCredentialQueryParameter(Uri uri) {
    const exactRejected = {'key', 'auth', 'authorization', 'password'};
    return uri.queryParameters.keys.any((name) {
      final normalized = name.toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]'),
        '',
      );
      return exactRejected.contains(normalized) ||
          normalized.endsWith('apikey') ||
          normalized.endsWith('token') ||
          normalized.endsWith('secret');
    });
  }
}
