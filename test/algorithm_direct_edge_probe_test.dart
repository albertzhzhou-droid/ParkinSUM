import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/algorithm_dependency_compatibility.dart';
import 'package:path/path.dart' as path;

import '../tool/algorithm_direct_edge_probe.dart';

void main() {
  test(
    'resolves direct calls and constructors while holding dispatch gaps',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'parkinsum_direct_edge_fixture_',
      );
      addTearDown(() => root.delete(recursive: true));
      final lib = Directory(path.join(root.path, 'lib'))
        ..createSync(recursive: true);
      final source = File(path.join(lib.path, 'fixture.dart'))
        ..writeAsStringSync('''
import 'helper.dart' show Helper hide Hidden
    if (dart.library.io) 'helper_io.dart';
import 'helper.dart' deferred as deferredHelper show Helper;
export 'api.dart' show PublicApi hide InternalApi;
part 'fixture_part.dart';

class Leaf {
  Leaf.create();
  static void pingStatic() {}
  void ping() {}
}

class DefaultLeaf {}

class InitializerBase {
  final int inherited;

  InitializerBase() : inherited = 0;
  InitializerBase.withValue(this.inherited);
  InitializerBase.named(this.inherited);
}

class InitializerChild extends InitializerBase {
  final int value;
  final DefaultLeaf dependency;

  InitializerChild(this.value, this.dependency) : super.withValue(value);

  InitializerChild.named(int value)
    : dependency = DefaultLeaf(),
      value = value,
      super.named(value);

  InitializerChild.redirected(int value) : this.named(value);

  InitializerChild.implicit(int value)
    : dependency = DefaultLeaf(),
      value = value;
}

class OperatorBox {
  OperatorBox operator +(OperatorBox other) => this;
  OperatorBox operator -() => this;
  int operator [](int index) => index;
  void operator []=(int index, int value) {}
}

class CompoundIndexBox {
  int operator [](int index) => index;
  void operator []=(int index, int value) {}
}

abstract interface class InterfaceContract {}

class InheritedBase {}

mixin DependencyMixin on InheritedBase implements InterfaceContract {}

class InheritedLeaf extends InheritedBase
    with DependencyMixin
    implements InterfaceContract {}

mixin EnumMixin {}

enum DependencyEnum with EnumMixin implements InterfaceContract { one }

extension NamedDependencyExtension on InheritedLeaf {}

extension GenericDependency<T> on List<T> {}

class ExtensionRepresentation implements InterfaceContract {}

extension type IntWrapper(ExtensionRepresentation value)
    implements InterfaceContract {}

typedef InheritedAlias = InheritedBase;

class AliasLeaf extends InheritedAlias {}

class GenericAliasTarget<T> {}

typedef GenericInheritedAlias<T> = GenericAliasTarget<T>;

typedef FunctionAlias = void Function();

class CallbackHost {
  void callbackTarget() {}
}

class Holder {
  final cached = DefaultLeaf();
  static int staticValue = 1;
  int stored = 1;

  int get computed => stored;

  set computed(int value) {
    stored = value;
  }
}

int topLevelValue = 1;

void rootFunction() {
  Leaf.create().ping();
  Leaf.pingStatic();
  DefaultLeaf();
  final holder = Holder();
  final value = holder.stored;
  holder.stored = value;
  holder.stored += 1;
  final computed = holder.computed;
  holder.computed = computed;
  final staticValue = Holder.staticValue;
  Holder.staticValue = staticValue;
  final topLevel = topLevelValue;
  topLevelValue = topLevel;
  final Object candidate = holder;
  final typeTest = candidate is Holder;
  final castValue = candidate as Holder;
  final holderType = Holder;
  if (typeTest && holderType == castValue.runtimeType) return;
}

void rootCallsPart() { partCaller(); }

void operatorRoot() {
  final box = OperatorBox();
  final sum = box + box;
  final negative = -box;
  final read = box[0];
  box[0] = 1;
  box[0] += 2;
  final compoundBox = CompoundIndexBox();
  compoundBox[0] += 2;
}

void dynamicOperatorRoot(dynamic receiver) {
  final sum = receiver + 1;
  final read = receiver[0];
  receiver[0] = 1;
  receiver[0] += 2;
}

void functionValueRoot() {
  final topLevel = topLevelCallback;
  final host = CallbackHost();
  final method = host.callbackTarget;
  final namedConstructor = Leaf.create;
  final defaultConstructor = DefaultLeaf.new;
  topLevel();
  method();
  namedConstructor();
  defaultConstructor();
}

void topLevelCallback() {}

void invokeCallback(void Function() callback) {
  callback();
}
''');
      File(path.join(lib.path, 'helper.dart')).writeAsStringSync('''
import 'api.dart' show PublicApi;
class Helper { static void ping() {} }
class Hidden {}
void helperCaller() { Helper.ping(); PublicApi(); }
''');
      File(
        path.join(lib.path, 'helper_io.dart'),
      ).writeAsStringSync('class Helper {}\nclass Hidden {}\n');
      File(
        path.join(lib.path, 'api.dart'),
      ).writeAsStringSync('class PublicApi {}\nclass InternalApi {}\n');
      final partSource = File(path.join(lib.path, 'fixture_part.dart'))
        ..writeAsStringSync('''
part of 'fixture.dart';
class PartLeaf {}
void partCaller() { PartLeaf(); }
''');
      final sdkPath = algorithmAnalyzerSdkPathForCurrentRuntime();
      expect(sdkPath, isNotNull);
      final collection = AnalysisContextCollection(
        includedPaths: [lib.path],
        sdkPath: sdkPath!,
      );
      try {
        final context = collection.contextFor(source.path);
        final result = await context.currentSession.getResolvedUnit(
          source.path,
        );
        expect(result, isA<ResolvedUnitResult>());
        final resolved = result as ResolvedUnitResult;
        expect(
          resolved.diagnostics.where(
            (diagnostic) => diagnostic.severity == Severity.error,
          ),
          isEmpty,
        );

        final collected = collectAlgorithmRootCallEdges(
          algorithmId: 'fixture_algorithm',
          logicalRootId: 'algorithm-root/fixture_algorithm',
          sourcePackageUri: 'package:fixture/fixture.dart',
          unit: resolved,
          repositoryRoot: root.path,
          packageName: 'fixture',
        );

        expect(
          collected.edges.map((edge) => edge.edgeKind),
          containsAll(['constructor_call', 'method_invocation']),
        );
        expect(
          collected.edges.any(
            (edge) =>
                edge.edgeKind == 'constructor_call' &&
                edge.targetIdentity.contains('DefaultLeaf'),
          ),
          isTrue,
          reason: collected.edges.map((edge) => edge.targetIdentity).join('\n'),
        );
        expect(
          collected.edges.any(
            (edge) => edge.targetIdentity.contains('pingStatic'),
          ),
          isTrue,
        );
        expect(
          collected.edges
              .where(
                (edge) => edge.sourceDeclarationIdentity.endsWith(
                  '#FUNCTION:rootFunction',
                ),
              )
              .where(
                (edge) =>
                    edge.edgeKind == 'constructor_call' ||
                    edge.edgeKind == 'method_invocation',
              )
              .length,
          5,
        );
        final rootFunctionEdges = collected.edges.where(
          (edge) =>
              edge.sourceDeclarationIdentity.endsWith('#FUNCTION:rootFunction'),
        );
        expect(
          rootFunctionEdges.any(
            (edge) =>
                edge.edgeKind == 'property_read' &&
                edge.targetIdentity.contains('stored'),
          ),
          isTrue,
        );
        final operatorRootEdges = collected.edges.where(
          (edge) =>
              edge.sourceDeclarationIdentity.endsWith('#FUNCTION:operatorRoot'),
        );
        expect(
          operatorRootEdges.map((edge) => edge.edgeKind),
          containsAll([
            'binary_operator',
            'prefix_operator',
            'index_read',
            'index_write',
            'compound_assignment_operator',
          ]),
          reason: operatorRootEdges
              .map((edge) => '${edge.edgeKind}: ${edge.targetIdentity}')
              .join('\n'),
        );
        expect(
          operatorRootEdges.any(
            (edge) =>
                edge.edgeKind == 'index_read' &&
                edge.targetIdentity.contains('CompoundIndexBox'),
          ),
          isTrue,
          reason: operatorRootEdges
              .map((edge) => '${edge.edgeKind}: ${edge.targetIdentity}')
              .join('\n'),
        );
        final dynamicOperatorHolds = collected.unresolved.where(
          (edge) =>
              edge.reason.startsWith('dynamic_operator_target_') &&
              edge.edgeKind != 'prefix_operator',
        );
        expect(
          dynamicOperatorHolds.map((edge) => edge.edgeKind),
          containsAll([
            'binary_operator',
            'index_read',
            'index_write',
            'compound_assignment_operator',
          ]),
        );
        final inheritanceEdges = collected.edges.where(
          (edge) => edge.sourceDeclarationIdentity.contains('InheritedLeaf'),
        );
        expect(
          inheritanceEdges.map((edge) => edge.edgeKind),
          containsAll([
            'inheritance_extends',
            'inheritance_mixin',
            'inheritance_implements',
          ]),
          reason: inheritanceEdges
              .map((edge) => '${edge.edgeKind}: ${edge.targetIdentity}')
              .join('\n'),
        );
        expect(
          collected.edges.map((edge) => edge.edgeKind),
          containsAll([
            'mixin_on_constraint',
            'extension_on_type',
            'extension_type_implements',
            'extension_type_representation',
          ]),
        );
        expect(
          collected.edges.any(
            (edge) =>
                edge.edgeKind == 'extension_on_type' &&
                edge.targetIdentity.contains('InheritedLeaf'),
          ),
          isTrue,
        );
        expect(
          collected.edges.any(
            (edge) =>
                edge.edgeKind == 'extension_type_representation' &&
                edge.targetLibraryUri == 'package:fixture/fixture.dart' &&
                edge.targetIdentity.contains('ExtensionRepresentation'),
          ),
          isTrue,
        );
        expect(
          collected.declarationEdges.any(
            (edge) =>
                edge.edgeKind == 'type_alias_target' &&
                edge.sourceDeclarationIdentity.contains('InheritedAlias') &&
                edge.targetIdentity.contains('InheritedBase'),
          ),
          isTrue,
        );
        expect(
          collected.unresolved.any(
            (edge) =>
                edge.edgeKind == 'inheritance_extends' &&
                edge.reason == 'type_alias_target_shape_unclosed',
          ),
          isFalse,
        );
        expect(
          collected.unresolved.any(
            (edge) =>
                edge.edgeKind == 'type_alias_target' &&
                edge.reason == 'generic_type_arguments_unreviewed',
          ),
          isTrue,
        );
        expect(
          collected.unresolved.any(
            (edge) =>
                edge.edgeKind == 'type_alias_target' &&
                edge.reason == 'type_alias_target_shape_unclosed',
          ),
          isTrue,
        );
        expect(
          collected.unresolved.any(
            (edge) =>
                edge.edgeKind == 'extension_on_type' &&
                edge.reason == 'generic_type_arguments_unreviewed',
          ),
          isTrue,
        );
        final functionValueEdges = collected.edges.where(
          (edge) => edge.sourceDeclarationIdentity.endsWith(
            '#FUNCTION:functionValueRoot',
          ),
        );
        expect(
          functionValueEdges.any(
            (edge) =>
                edge.edgeKind == 'function_value_reference' &&
                edge.targetIdentity.contains('topLevelCallback'),
          ),
          isTrue,
        );
        expect(
          functionValueEdges.any(
            (edge) =>
                edge.edgeKind == 'function_value_reference' &&
                edge.targetIdentity.contains('callbackTarget'),
          ),
          isTrue,
        );
        expect(
          functionValueEdges.any(
            (edge) =>
                edge.edgeKind == 'constructor_tear_off' &&
                edge.targetIdentity.contains('Leaf'),
          ),
          isTrue,
        );
        expect(
          functionValueEdges.any(
            (edge) =>
                edge.edgeKind == 'constructor_tear_off' &&
                edge.targetIdentity.contains('DefaultLeaf'),
          ),
          isTrue,
        );
        expect(
          collected.unresolved.any(
            (edge) =>
                edge.edgeKind == 'function_expression_invocation' &&
                edge.reason.startsWith('function_value_target_'),
          ),
          isTrue,
        );
        final initializerEdges = collected.edges.where(
          (edge) => edge.sourceDeclarationIdentity.contains('Initializer'),
        );
        expect(
          initializerEdges.map((edge) => edge.edgeKind),
          containsAll([
            'constructor_field_initialization',
            'super_constructor_call',
            'constructor_redirection',
          ]),
          reason: initializerEdges
              .map((edge) => '${edge.edgeKind}: ${edge.targetIdentity}')
              .join('\n'),
        );
        expect(
          initializerEdges.any(
            (edge) =>
                edge.edgeKind == 'super_constructor_call' &&
                edge.targetIdentity.contains('InitializerBase'),
          ),
          isTrue,
        );
        expect(
          initializerEdges.any(
            (edge) =>
                edge.edgeKind == 'constructor_redirection' &&
                edge.targetIdentity.contains('named'),
          ),
          isTrue,
        );
        expect(
          collected.unresolved.any(
            (edge) =>
                edge.edgeKind == 'constructor_body' &&
                edge.reason ==
                    'implicit_or_generated_constructor_body_unreviewed',
          ),
          isTrue,
        );
        expect(
          rootFunctionEdges.any(
            (edge) =>
                edge.edgeKind == 'property_write' &&
                edge.targetIdentity.contains('stored'),
          ),
          isTrue,
        );
        expect(
          rootFunctionEdges.any(
            (edge) =>
                edge.edgeKind == 'property_read' &&
                edge.targetIdentity.contains('computed'),
          ),
          isTrue,
        );
        expect(
          rootFunctionEdges.any(
            (edge) =>
                edge.edgeKind == 'property_write' &&
                edge.targetIdentity.contains('computed'),
          ),
          isTrue,
        );
        expect(
          rootFunctionEdges.any(
            (edge) =>
                edge.edgeKind == 'property_read' &&
                edge.targetIdentity.contains('staticValue'),
          ),
          isTrue,
        );
        expect(
          rootFunctionEdges.any(
            (edge) =>
                edge.edgeKind == 'property_write' &&
                edge.targetIdentity.contains('staticValue'),
          ),
          isTrue,
        );
        expect(
          rootFunctionEdges.any(
            (edge) =>
                edge.edgeKind == 'property_read' &&
                edge.targetIdentity.contains('topLevelValue'),
          ),
          isTrue,
        );
        expect(
          rootFunctionEdges.any(
            (edge) =>
                edge.edgeKind == 'property_write' &&
                edge.targetIdentity.contains('topLevelValue'),
          ),
          isTrue,
        );
        expect(
          rootFunctionEdges.map((edge) => edge.edgeKind),
          containsAll(['type_test', 'type_cast', 'type_literal']),
          reason: rootFunctionEdges
              .map((edge) => '${edge.edgeKind}: ${edge.targetIdentity}')
              .join('\n'),
        );
        expect(
          collected.edges.any(
            (edge) =>
                edge.targetIdentity.contains('DefaultLeaf') &&
                edge.sourceDeclarationIdentity.contains('cached'),
          ),
          isTrue,
        );
        expect(collected.namespaceEdges, hasLength(5));
        final importBranches = collected.namespaceEdges
            .where((edge) => edge.directiveKind == 'import')
            .toList();
        expect(importBranches, hasLength(3));
        expect(importBranches.first.branchIndex, 0);
        expect(
          importBranches.first.targetPackageUri,
          'package:fixture/helper.dart',
        );
        expect(importBranches.first.prefix, isNull);
        expect(importBranches.first.combinators, [
          {
            'kind': 'show',
            'names': ['Helper'],
          },
          {
            'kind': 'hide',
            'names': ['Hidden'],
          },
        ]);
        expect(importBranches[1].branchIndex, 1);
        expect(importBranches[1].conditionName, 'dart.library.io');
        expect(
          importBranches[1].targetPackageUri,
          'package:fixture/helper_io.dart',
        );
        expect(importBranches.last.branchIndex, 0);
        expect(importBranches.last.conditionName, isNull);
        expect(
          importBranches.last.targetPackageUri,
          'package:fixture/helper.dart',
        );
        expect(importBranches.last.prefix, 'deferredHelper');
        expect(importBranches.last.deferred, isTrue);
        expect(importBranches.last.combinators, [
          {
            'kind': 'show',
            'names': ['Helper'],
          },
        ]);
        expect(
          collected.namespaceEdges.any(
            (edge) =>
                edge.directiveKind == 'export' &&
                edge.targetPackageUri == 'package:fixture/api.dart' &&
                edge.combinators.isNotEmpty,
          ),
          isTrue,
        );
        expect(
          collected.namespaceEdges.any(
            (edge) =>
                edge.directiveKind == 'part' &&
                edge.targetPackageUri == 'package:fixture/fixture_part.dart',
          ),
          isTrue,
        );
        expect(
          collected.unresolved.any(
            (edge) =>
                edge.edgeKind == 'function_expression_invocation' &&
                edge.reason.startsWith('function_value_target_'),
          ),
          isTrue,
        );
        expect(
          collected.unresolved.any(
            (edge) => edge.reason.contains('polymorphic_dispatch'),
          ),
          isTrue,
        );
        expect(
          collected.unresolved.any(
            (edge) =>
                edge.reason ==
                'part_source_scanned_without_root_ownership_join',
          ),
          isFalse,
        );
        final partResult = await context.currentSession.getResolvedUnit(
          partSource.path,
        );
        expect(partResult, isA<ResolvedUnitResult>());
        final partCollection = collectAlgorithmRootCallEdges(
          algorithmId: 'fixture_algorithm',
          logicalRootId: 'algorithm-root/fixture_algorithm',
          sourcePackageUri: 'package:fixture/fixture_part.dart',
          unit: partResult as ResolvedUnitResult,
          repositoryRoot: root.path,
          packageName: 'fixture',
        );
        expect(partCollection.namespaceEdges, hasLength(1));
        expect(partCollection.namespaceEdges.single.directiveKind, 'part_of');
        expect(
          partCollection.namespaceEdges.single.targetPackageUri,
          'package:fixture/fixture.dart',
        );
        expect(
          jsonEncode({
            'edges': collected.edges.map((edge) => edge.toJson()).toList(),
            'namespace_edges': collected.namespaceEdges
                .map((edge) => edge.toJson())
                .toList(),
            'part_of_edges': partCollection.namespaceEdges
                .map((edge) => edge.toJson())
                .toList(),
          }),
          isNot(contains(root.path)),
        );

        final helperResult = await context.currentSession.getResolvedUnit(
          path.join(lib.path, 'helper.dart'),
        );
        expect(helperResult, isA<ResolvedUnitResult>());
        final helperCollection = collectAlgorithmSourceUnitEdges(
          sourcePackageUri: 'package:fixture/helper.dart',
          unit: helperResult as ResolvedUnitResult,
          repositoryRoot: root.path,
          packageName: 'fixture',
        );
        expect(helperCollection.edges, isEmpty);
        expect(
          helperCollection.declarationEdges.map((edge) => edge.edgeKind),
          containsAll(['method_invocation', 'constructor_call']),
        );
        expect(helperCollection.namespaceEdges, hasLength(1));
        expect(helperCollection.namespaceEdges.single.algorithmId, isNull);
        expect(helperCollection.namespaceEdges.single.logicalRootId, isNull);
        expect(helperCollection.namespaceEdges.single.combinators, [
          {
            'kind': 'show',
            'names': ['PublicApi'],
          },
        ]);

        final helperIoResult = await context.currentSession.getResolvedUnit(
          path.join(lib.path, 'helper_io.dart'),
        );
        expect(helperIoResult, isA<ResolvedUnitResult>());
        final helperIoCollection = collectAlgorithmSourceUnitEdges(
          sourcePackageUri: 'package:fixture/helper_io.dart',
          unit: helperIoResult as ResolvedUnitResult,
          repositoryRoot: root.path,
          packageName: 'fixture',
        );
        final apiResult = await context.currentSession.getResolvedUnit(
          path.join(lib.path, 'api.dart'),
        );
        expect(apiResult, isA<ResolvedUnitResult>());
        final apiCollection = collectAlgorithmSourceUnitEdges(
          sourcePackageUri: 'package:fixture/api.dart',
          unit: apiResult as ResolvedUnitResult,
          repositoryRoot: root.path,
          packageName: 'fixture',
        );

        final genericPartCollection = collectAlgorithmSourceUnitEdges(
          sourcePackageUri: 'package:fixture/fixture_part.dart',
          unit: partResult,
          repositoryRoot: root.path,
          packageName: 'fixture',
        );
        expect(
          genericPartCollection.declarationEdges.any(
            (edge) =>
                edge.edgeKind == 'constructor_call' &&
                edge.targetIdentity.contains('PartLeaf'),
          ),
          isTrue,
        );
        expect(genericPartCollection.namespaceEdges.single.algorithmId, isNull);
        expect(
          genericPartCollection.namespaceEdges.single.directiveKind,
          'part_of',
        );
        final partRootEdges = collected.edges
            .where(
              (edge) => edge.sourceDeclarationIdentity.endsWith(
                '#FUNCTION:rootCallsPart',
              ),
            )
            .toList();
        expect(
          partRootEdges.any(
            (edge) => edge.targetIdentity.endsWith('#FUNCTION:partCaller'),
          ),
          isTrue,
        );
        final partRootDeclarationEdges = collected.declarationEdges.where(
          (edge) => edge.sourceDeclarationIdentity.endsWith(
            '#FUNCTION:rootCallsPart',
          ),
        );
        final rootObservation = AlgorithmDirectEdgeRootObservation(
          algorithmId: 'fixture_algorithm',
          logicalRootId: 'algorithm-root/fixture_algorithm',
          canonicalPackageUri: 'package:fixture/fixture.dart',
          resultVariant: 'ResolvedUnitResult',
          sessionConsistent: true,
          resolvedLibraryUri: 'package:fixture/fixture.dart',
          blockingDiagnosticCodes: const [],
          edgeCount: partRootEdges.length,
          namespaceEdgeCount: collected.namespaceEdges.length,
          unresolvedCallCount: 0,
        );
        final namespaceEdges = [
          ...collected.namespaceEdges,
          ...genericPartCollection.namespaceEdges,
          ...helperCollection.namespaceEdges,
          ...helperIoCollection.namespaceEdges,
          ...apiCollection.namespaceEdges,
        ];
        AlgorithmSourceUnitObservation sourceUnitObservation({
          required String uri,
          required AlgorithmRootCallEdgeCollection collection,
          String unitKind = 'library',
          String? containingLibraryUri,
        }) => AlgorithmSourceUnitObservation(
          sourcePackageUri: uri,
          containingLibraryPackageUri: containingLibraryUri,
          unitKind: unitKind,
          resultVariant: 'ResolvedUnitResult',
          sessionConsistent: true,
          blockingDiagnosticCodes: const [],
          declarationEdgeCount: collection.declarationEdges.length,
          namespaceEdgeCount: collection.namespaceEdges.length,
          unresolvedCallCount: collection.sourceUnresolved.length,
        );
        final reachableSourceUnits = [
          sourceUnitObservation(
            uri: 'package:fixture/fixture.dart',
            collection: collected,
            containingLibraryUri: 'package:fixture/fixture.dart',
          ),
          sourceUnitObservation(
            uri: 'package:fixture/fixture_part.dart',
            collection: genericPartCollection,
            unitKind: 'part',
            containingLibraryUri: 'package:fixture/fixture.dart',
          ),
          sourceUnitObservation(
            uri: 'package:fixture/helper.dart',
            collection: helperCollection,
          ),
          sourceUnitObservation(
            uri: 'package:fixture/helper_io.dart',
            collection: helperIoCollection,
          ),
          sourceUnitObservation(
            uri: 'package:fixture/api.dart',
            collection: apiCollection,
          ),
        ];
        final partReachability = computeAlgorithmSupportedCallReachability(
          roots: [rootObservation],
          rootEdges: partRootEdges,
          declarationEdges: [
            ...partRootDeclarationEdges,
            ...genericPartCollection.declarationEdges,
          ],
          namespaceEdges: namespaceEdges,
          rootUnresolved: const [],
          sourceUnresolved: const [],
          sourceUnits: reachableSourceUnits,
        );
        final partReachabilitySummary = partReachability.summaries.single;
        expect(partReachabilitySummary.reachableSourceUnitCount, 5);
        expect(partReachabilitySummary.reachableSourcePackageUris, [
          'package:fixture/api.dart',
          'package:fixture/fixture.dart',
          'package:fixture/fixture_part.dart',
          'package:fixture/helper.dart',
          'package:fixture/helper_io.dart',
        ]);
        expect(partReachabilitySummary.reachableNamespaceBranchCount, 7);
        expect(
          partReachability.holds.map((hold) => hold.reason),
          containsAll([
            'conditional_namespace_selection_semantics_unmodeled',
            'deferred_namespace_load_not_modeled',
          ]),
        );
        expect(
          partReachabilitySummary.reachableDeclarationIdentities.any(
            (identity) => identity.endsWith('#FUNCTION:rootCallsPart'),
          ),
          isTrue,
        );
        expect(
          partReachabilitySummary.reachableDeclarationIdentities.any(
            (identity) => identity.endsWith('#FUNCTION:partCaller'),
          ),
          isTrue,
        );
        expect(
          partReachabilitySummary.reachableDeclarationIdentities.any(
            (identity) => identity.contains('#CLASS:PartLeaf'),
          ),
          isTrue,
        );
        expect(
          partReachabilitySummary.reachableEdgeCount,
          greaterThanOrEqualTo(2),
        );
        expect(
          partReachability.holds.any(
            (hold) =>
                hold.reason == 'part_ownership_not_analyzer_validated' ||
                hold.reason == 'part_or_augment_source_ownership_not_joined',
          ),
          isFalse,
        );
        expect(
          partReachability.reverseSourceOwnership
              .singleWhere(
                (row) =>
                    row.sourcePackageUri == 'package:fixture/helper_io.dart',
              )
              .algorithmIds,
          ['fixture_algorithm'],
        );
        final sourceBudgetReachability =
            computeAlgorithmSupportedCallReachability(
              roots: [rootObservation],
              rootEdges: partRootEdges,
              declarationEdges: [
                ...partRootDeclarationEdges,
                ...genericPartCollection.declarationEdges,
              ],
              namespaceEdges: namespaceEdges,
              rootUnresolved: const [],
              sourceUnresolved: const [],
              sourceUnits: reachableSourceUnits,
              maxSourceUnitsPerRoot: 1,
            );
        expect(
          sourceBudgetReachability.summaries.single.budgetExceeded,
          isTrue,
        );
        expect(
          sourceBudgetReachability.summaries.single.reachableSourcePackageUris,
          ['package:fixture/fixture.dart'],
        );
        expect(
          sourceBudgetReachability.holds.any(
            (hold) => hold.reason == 'source_unit_budget_exceeded',
          ),
          isTrue,
        );
        final mismatchedOwnerReachability =
            computeAlgorithmSupportedCallReachability(
              roots: [rootObservation],
              rootEdges: partRootEdges,
              declarationEdges: [
                ...partRootDeclarationEdges,
                ...genericPartCollection.declarationEdges,
              ],
              namespaceEdges: namespaceEdges,
              rootUnresolved: const [],
              sourceUnresolved: const [],
              sourceUnits: [
                ...reachableSourceUnits.where(
                  (unit) =>
                      unit.sourcePackageUri !=
                      'package:fixture/fixture_part.dart',
                ),
                sourceUnitObservation(
                  uri: 'package:fixture/fixture_part.dart',
                  collection: genericPartCollection,
                  unitKind: 'part',
                  containingLibraryUri: 'package:fixture/foreign.dart',
                ),
              ],
            );
        expect(
          mismatchedOwnerReachability.holds.any(
            (hold) =>
                hold.reason == 'part_ownership_not_analyzer_validated' ||
                hold.reason == 'part_or_augment_source_ownership_not_joined',
          ),
          isTrue,
        );
        expect(
          mismatchedOwnerReachability
              .summaries
              .single
              .reachableDeclarationIdentities
              .any((identity) => identity.contains('#CLASS:PartLeaf')),
          isFalse,
        );
      } finally {
        await collection.dispose();
      }
    },
  );

  test(
    'supported call reachability follows local calls and keeps blockers explicit',
    () {
      const rootUri = 'package:fixture/root.dart';
      const helperUri = 'package:fixture/helper.dart';
      const otherUri = 'package:fixture/other.dart';
      const caller = '$rootUri#FUNCTION:run';
      const helper = '$helperUri#FUNCTION:step';
      const helperNext = '$helperUri#FUNCTION:next';
      const missingTarget = 'package:fixture/missing.dart#FUNCTION:missing';
      const externalTarget = 'dart:core#METHOD:toString';

      AlgorithmDeclarationDependencyEdge localCall(
        String sourceUri,
        String sourceIdentity,
        String targetIdentity,
        String targetUri,
      ) => AlgorithmDeclarationDependencyEdge(
        sourcePackageUri: sourceUri,
        sourceDeclarationIdentity: sourceIdentity,
        targetIdentity: targetIdentity,
        targetLibraryUri: targetUri,
        edgeKind: 'method_invocation',
        targetScope: 'local_package',
      );
      AlgorithmDirectDependencyEdge rootCall(
        String targetIdentity,
        String targetUri,
        String scope,
      ) => AlgorithmDirectDependencyEdge(
        algorithmId: 'fixture_algorithm',
        logicalRootId: 'root/fixture_algorithm',
        sourcePackageUri: rootUri,
        sourceDeclarationIdentity: caller,
        targetIdentity: targetIdentity,
        targetLibraryUri: targetUri,
        edgeKind: 'method_invocation',
        targetScope: scope,
      );

      final rootToHelper = localCall(rootUri, caller, helper, helperUri);
      final rootToExternal = AlgorithmDeclarationDependencyEdge(
        sourcePackageUri: rootUri,
        sourceDeclarationIdentity: caller,
        targetIdentity: externalTarget,
        targetLibraryUri: 'dart:core',
        edgeKind: 'method_invocation',
        targetScope: 'external_or_sdk',
      );
      final rootToMissing = localCall(
        rootUri,
        caller,
        missingTarget,
        'package:fixture/missing.dart',
      );
      final helperToNext = localCall(helperUri, helper, helperNext, helperUri);
      final nextToHelper = localCall(helperUri, helperNext, helper, helperUri);
      final unreachableCall = AlgorithmDeclarationDependencyEdge(
        sourcePackageUri: otherUri,
        sourceDeclarationIdentity: '$otherUri#FUNCTION:unused',
        targetIdentity: 'dart:core#METHOD:hashCode',
        targetLibraryUri: 'dart:core',
        edgeKind: 'method_invocation',
        targetScope: 'external_or_sdk',
      );
      final roots = [
        AlgorithmDirectEdgeRootObservation(
          algorithmId: 'fixture_algorithm',
          logicalRootId: 'root/fixture_algorithm',
          canonicalPackageUri: rootUri,
          resultVariant: 'ResolvedUnitResult',
          sessionConsistent: true,
          resolvedLibraryUri: rootUri,
          blockingDiagnosticCodes: const [],
          edgeCount: 3,
          namespaceEdgeCount: 0,
          unresolvedCallCount: 1,
        ),
      ];
      final rootEdges = [
        rootCall(helper, helperUri, 'local_package'),
        rootCall(externalTarget, 'dart:core', 'external_or_sdk'),
        rootCall(
          missingTarget,
          'package:fixture/missing.dart',
          'local_package',
        ),
      ];
      final sourceUnits = [
        for (final uri in [rootUri, helperUri, otherUri])
          AlgorithmSourceUnitObservation(
            sourcePackageUri: uri,
            unitKind: 'library',
            resultVariant: 'ResolvedUnitResult',
            sessionConsistent: true,
            blockingDiagnosticCodes: const [],
            declarationEdgeCount: 0,
            namespaceEdgeCount: 0,
            unresolvedCallCount: 0,
          ),
      ];
      const rootHold = AlgorithmUnresolvedDirectEdge(
        algorithmId: 'fixture_algorithm',
        logicalRootId: 'root/fixture_algorithm',
        edgeKind: 'method_invocation',
        reason: 'possible_polymorphic_dispatch_target_set_unclosed',
        count: 3,
      );
      const helperHold = AlgorithmUnresolvedSourceEdge(
        sourcePackageUri: helperUri,
        edgeKind: 'function_expression_invocation',
        reason: 'function_value_target_unresolved',
        count: 2,
      );
      const unreachableHold = AlgorithmUnresolvedSourceEdge(
        sourcePackageUri: otherUri,
        edgeKind: 'function_expression_invocation',
        reason: 'function_value_target_unresolved',
        count: 4,
      );

      AlgorithmCallReachabilityResult run({bool reverse = false}) =>
          computeAlgorithmSupportedCallReachability(
            roots: roots,
            rootEdges: reverse ? rootEdges.reversed : rootEdges,
            declarationEdges: reverse
                ? [
                    unreachableCall,
                    nextToHelper,
                    helperToNext,
                    rootToMissing,
                    rootToExternal,
                    rootToHelper,
                  ]
                : [
                    rootToHelper,
                    rootToExternal,
                    rootToMissing,
                    helperToNext,
                    nextToHelper,
                    unreachableCall,
                  ],
            namespaceEdges: const [],
            rootUnresolved: const [rootHold],
            sourceUnresolved: reverse
                ? const [unreachableHold, helperHold]
                : const [helperHold, unreachableHold],
            sourceUnits: reverse ? sourceUnits.reversed : sourceUnits,
          );

      final forward = run();
      final reverse = run(reverse: true);
      final summary = forward.summaries.single;
      expect(
        forward.summaries.single.toJson(),
        reverse.summaries.single.toJson(),
      );
      expect(
        forward.holds.map((hold) => hold.toJson()).toList(),
        reverse.holds.map((hold) => hold.toJson()).toList(),
      );
      expect(summary.seedDeclarationCount, 1);
      expect(summary.reachableDeclarationCount, 5);
      expect(summary.reachableEdgeCount, 5);
      expect(summary.reachableSourceUnitCount, 2);
      expect(summary.externalEdgeCount, 1);
      expect(summary.maximumDepth, 3);
      expect(summary.rootUnresolvedGroupCount, 1);
      expect(summary.rootUnresolvedOccurrenceCount, 3);
      expect(summary.sourceUnresolvedGroupCount, 1);
      expect(summary.sourceUnresolvedOccurrenceCount, 2);
      expect(summary.blockerGroupCount, 4);
      expect(summary.blockerOccurrenceCount, 7);
      expect(summary.budgetExceeded, isFalse);
      expect(summary.reachableGraphSha256, matches(RegExp(r'^[a-f0-9]{64}$')));
      expect(
        summary.reachableDeclarationIdentities,
        containsAll([
          caller,
          helper,
          helperNext,
          missingTarget,
          externalTarget,
        ]),
      );
      expect(summary.cyclicComponents, hasLength(1));
      expect(summary.cyclicComponents.single.declarationIdentities, [
        helperNext,
        helper,
      ]);
      expect(
        forward.reverseReachability
            .singleWhere((row) => row.declarationIdentity == helper)
            .algorithmIds,
        ['fixture_algorithm'],
      );
      expect(
        forward.reverseReachability.map((row) => row.toJson()).toList(),
        reverse.reverseReachability.map((row) => row.toJson()).toList(),
      );
      expect(
        forward.reverseSourceOwnership.map((row) => row.toJson()).toList(),
        reverse.reverseSourceOwnership.map((row) => row.toJson()).toList(),
      );
      expect(
        forward.reverseSourceOwnership
            .singleWhere((row) => row.sourcePackageUri == helperUri)
            .algorithmIds,
        ['fixture_algorithm'],
      );
      expect(
        forward.holds.any(
          (hold) => hold.reason == 'external_target_not_traversed',
        ),
        isTrue,
      );
      expect(
        forward.holds.any(
          (hold) => hold.reason == 'local_target_not_in_source_inventory',
        ),
        isTrue,
      );
      expect(
        forward.holds.any((hold) => hold.sourcePackageUri == otherUri),
        isFalse,
        reason: 'unreachable source blockers must not be attached to this root',
      );

      final bounded = computeAlgorithmSupportedCallReachability(
        roots: roots,
        rootEdges: rootEdges,
        declarationEdges: [
          rootToHelper,
          rootToExternal,
          rootToMissing,
          helperToNext,
          nextToHelper,
          unreachableCall,
        ],
        namespaceEdges: const [],
        rootUnresolved: const [rootHold],
        sourceUnresolved: const [helperHold, unreachableHold],
        sourceUnits: sourceUnits,
        maxEdgesPerRoot: 2,
      );
      expect(bounded.summaries.single.budgetExceeded, isTrue);
      expect(bounded.summaries.single.reachableEdgeCount, 2);
      expect(
        bounded.holds.any((hold) => hold.reason == 'edge_budget_exceeded'),
        isTrue,
      );
      final sourceBounded = computeAlgorithmSupportedCallReachability(
        roots: roots,
        rootEdges: rootEdges,
        declarationEdges: [rootToHelper, rootToExternal, rootToMissing],
        namespaceEdges: const [],
        rootUnresolved: const [rootHold],
        sourceUnresolved: const [helperHold, unreachableHold],
        sourceUnits: sourceUnits,
        maxSourceUnitsPerRoot: 1,
      );
      expect(sourceBounded.summaries.single.budgetExceeded, isTrue);
      expect(sourceBounded.summaries.single.reachableSourceUnitCount, 1);
      expect(
        sourceBounded.holds.any(
          (hold) => hold.reason == 'source_unit_budget_exceeded',
        ),
        isTrue,
      );
    },
  );

  test('reverse ownership and cycle components bind shared dependencies', () {
    const rootAUri = 'package:fixture/root_a.dart';
    const rootBUri = 'package:fixture/root_b.dart';
    const helperUri = 'package:fixture/shared.dart';
    const rootA = '$rootAUri#FUNCTION:runA';
    const rootB = '$rootBUri#FUNCTION:runB';
    const shared = '$helperUri#FUNCTION:shared';
    const peer = '$helperUri#FUNCTION:peer';

    AlgorithmDirectEdgeRootObservation observation(
      String algorithmId,
      String uri,
    ) => AlgorithmDirectEdgeRootObservation(
      algorithmId: algorithmId,
      logicalRootId: 'root/$algorithmId',
      canonicalPackageUri: uri,
      resultVariant: 'ResolvedUnitResult',
      sessionConsistent: true,
      resolvedLibraryUri: uri,
      blockingDiagnosticCodes: const [],
      edgeCount: 1,
      namespaceEdgeCount: 0,
      unresolvedCallCount: 0,
    );

    AlgorithmDeclarationDependencyEdge dependency(
      String sourceUri,
      String source,
      String target,
    ) => AlgorithmDeclarationDependencyEdge(
      sourcePackageUri: sourceUri,
      sourceDeclarationIdentity: source,
      targetIdentity: target,
      targetLibraryUri: target.substring(0, target.indexOf('#')),
      edgeKind: 'method_invocation',
      targetScope: 'local_package',
    );

    AlgorithmDirectDependencyEdge rootEdge(
      String algorithmId,
      String logicalRootId,
      String sourceUri,
      String source,
    ) => AlgorithmDirectDependencyEdge(
      algorithmId: algorithmId,
      logicalRootId: logicalRootId,
      sourcePackageUri: sourceUri,
      sourceDeclarationIdentity: source,
      targetIdentity: shared,
      targetLibraryUri: helperUri,
      edgeKind: 'method_invocation',
      targetScope: 'local_package',
    );

    AlgorithmSourceUnitObservation unit(String uri) =>
        AlgorithmSourceUnitObservation(
          sourcePackageUri: uri,
          unitKind: 'library',
          resultVariant: 'ResolvedUnitResult',
          sessionConsistent: true,
          blockingDiagnosticCodes: const [],
          declarationEdgeCount: 0,
          namespaceEdgeCount: 0,
          unresolvedCallCount: 0,
        );

    final roots = [
      observation('algorithm_a', rootAUri),
      observation('algorithm_b', rootBUri),
    ];
    final rootEdges = [
      rootEdge('algorithm_a', 'root/algorithm_a', rootAUri, rootA),
      rootEdge('algorithm_b', 'root/algorithm_b', rootBUri, rootB),
    ];
    final dependencies = [
      dependency(rootAUri, rootA, shared),
      dependency(rootBUri, rootB, shared),
      dependency(helperUri, shared, peer),
      dependency(helperUri, peer, shared),
    ];
    final sourceUnits = [unit(rootAUri), unit(rootBUri), unit(helperUri)];

    AlgorithmCallReachabilityResult run({bool reversed = false}) =>
        computeAlgorithmSupportedCallReachability(
          roots: reversed ? roots.reversed : roots,
          rootEdges: reversed ? rootEdges.reversed : rootEdges,
          declarationEdges: reversed ? dependencies.reversed : dependencies,
          namespaceEdges: const [],
          rootUnresolved: const [],
          sourceUnresolved: const [],
          sourceUnits: reversed ? sourceUnits.reversed : sourceUnits,
        );

    final forward = run();
    final reversed = run(reversed: true);
    final sharedOwners = forward.reverseReachability.singleWhere(
      (row) => row.declarationIdentity == shared,
    );
    final peerOwners = forward.reverseReachability.singleWhere(
      (row) => row.declarationIdentity == peer,
    );
    expect(sharedOwners.algorithmIds, ['algorithm_a', 'algorithm_b']);
    expect(peerOwners.algorithmIds, ['algorithm_a', 'algorithm_b']);
    expect(
      forward.summaries.map((summary) => summary.toJson()).toList(),
      reversed.summaries.map((summary) => summary.toJson()).toList(),
    );
    expect(
      forward.reverseReachability.map((row) => row.toJson()).toList(),
      reversed.reverseReachability.map((row) => row.toJson()).toList(),
    );
    for (final summary in forward.summaries) {
      expect(summary.cyclicComponents, hasLength(1));
      expect(summary.cyclicComponents.single.declarationIdentities, [
        peer,
        shared,
      ]);
    }
  });

  test('report ordering and digest do not depend on input traversal order', () {
    final first = AlgorithmDirectDependencyEdge(
      algorithmId: 'a',
      logicalRootId: 'root/a',
      sourcePackageUri: 'package:fixture/a.dart',
      sourceDeclarationIdentity: 'package:fixture/a.dart#FUNCTION:a',
      targetIdentity: 'package:fixture/b.dart#FUNCTION:b',
      targetLibraryUri: 'package:fixture/b.dart',
      edgeKind: 'method_invocation',
      targetScope: 'local_package',
    );
    final second = AlgorithmDirectDependencyEdge(
      algorithmId: 'b',
      logicalRootId: 'root/b',
      sourcePackageUri: 'package:fixture/c.dart',
      sourceDeclarationIdentity: 'package:fixture/c.dart#FUNCTION:c',
      targetIdentity: 'dart:core#FUNCTION:toString',
      targetLibraryUri: 'dart:core',
      edgeKind: 'method_invocation',
      targetScope: 'external_or_sdk',
    );
    final declaration = AlgorithmDeclarationDependencyEdge(
      sourcePackageUri: 'package:fixture/a.dart',
      sourceDeclarationIdentity: 'package:fixture/a.dart#FUNCTION:a',
      targetIdentity: 'package:fixture/b.dart#FUNCTION:b',
      targetLibraryUri: 'package:fixture/b.dart',
      edgeKind: 'method_invocation',
      targetScope: 'local_package',
    );
    final declarationSecond = AlgorithmDeclarationDependencyEdge(
      sourcePackageUri: 'package:fixture/c.dart',
      sourceDeclarationIdentity: 'package:fixture/c.dart#FUNCTION:c',
      targetIdentity: 'dart:core#FUNCTION:toString',
      targetLibraryUri: 'dart:core',
      edgeKind: 'method_invocation',
      targetScope: 'external_or_sdk',
    );
    final sourceUnit = AlgorithmSourceUnitObservation(
      sourcePackageUri: 'package:fixture/a.dart',
      containingLibraryPackageUri: 'package:fixture/a.dart',
      unitKind: 'library',
      resultVariant: 'ResolvedUnitResult',
      sessionConsistent: true,
      blockingDiagnosticCodes: const [],
      declarationEdgeCount: 1,
      namespaceEdgeCount: 0,
      unresolvedCallCount: 0,
    );
    final unresolvedSource = AlgorithmUnresolvedSourceEdge(
      sourcePackageUri: 'package:fixture/b.dart',
      edgeKind: 'source_unit',
      reason: 'unreviewed_fixture',
      count: 1,
    );
    final genericNamespace = AlgorithmNamespaceDependencyEdge(
      algorithmId: null,
      logicalRootId: null,
      sourcePackageUri: 'package:fixture/a.dart',
      directiveIndex: 0,
      branchIndex: 0,
      directiveKind: 'import',
      uriLiteral: 'b.dart',
      targetPackageUri: 'package:fixture/b.dart',
      symbolicTarget: null,
      conditionName: null,
      conditionValue: null,
      prefix: null,
      deferred: false,
      combinators: const [],
    );
    final genericNamespaceSecond = AlgorithmNamespaceDependencyEdge(
      algorithmId: null,
      logicalRootId: null,
      sourcePackageUri: 'package:fixture/c.dart',
      directiveIndex: 1,
      branchIndex: 0,
      directiveKind: 'export',
      uriLiteral: 'd.dart',
      targetPackageUri: 'package:fixture/d.dart',
      symbolicTarget: null,
      conditionName: null,
      conditionValue: null,
      prefix: null,
      deferred: false,
      combinators: const [],
    );
    final declaredPartNamespace = AlgorithmNamespaceDependencyEdge(
      algorithmId: null,
      logicalRootId: null,
      sourcePackageUri: 'package:fixture/a.dart',
      directiveIndex: 2,
      branchIndex: 0,
      directiveKind: 'part',
      uriLiteral: 'b.dart',
      targetPackageUri: 'package:fixture/b.dart',
      symbolicTarget: null,
      conditionName: null,
      conditionValue: null,
      prefix: null,
      deferred: false,
      combinators: const [],
    );
    final duplicatePartNamespace = AlgorithmNamespaceDependencyEdge(
      algorithmId: null,
      logicalRootId: null,
      sourcePackageUri: 'package:fixture/a.dart',
      directiveIndex: 3,
      branchIndex: 0,
      directiveKind: 'part',
      uriLiteral: 'b.dart',
      targetPackageUri: 'package:fixture/b.dart',
      symbolicTarget: null,
      conditionName: null,
      conditionValue: null,
      prefix: null,
      deferred: false,
      combinators: const [],
    );
    final unresolvedSourceSecond = AlgorithmUnresolvedSourceEdge(
      sourcePackageUri: 'package:fixture/a.dart',
      edgeKind: 'method_invocation',
      reason: 'unresolved_fixture',
      count: 2,
    );
    AlgorithmDirectEdgeProbeReport report(
      List<AlgorithmDirectDependencyEdge> edges, {
      bool reverse = false,
      Iterable<AlgorithmNamespaceDependencyEdge>? namespaceEdges,
    }) => AlgorithmDirectEdgeProbeReport(
      analyzerVersion: algorithmDependencyAnalyzerVersion,
      analyzerArchiveSha256: algorithmDependencyAnalyzerArchiveSha256,
      dartVersion: algorithmDependencyReviewedDartVersion,
      rootManifestSha256: 'a' * 64,
      lockfileSha256: 'b' * 64,
      packageConfigSha256: 'c' * 64,
      packageJsonSha256: 'd' * 64,
      analysisOptionsSha256: 'e' * 64,
      generatorSourceSha256: 'f' * 64,
      runnerSourceSha256: '0' * 64,
      testSourceSha256: '1' * 64,
      rootSourceSnapshotSha256: '2' * 64,
      libSourceSnapshotSha256: '3' * 64,
      analysisContextCount: 1,
      sourceFileCount: 2,
      roots: const [],
      edges: edges,
      declarationEdges: reverse
          ? [declarationSecond, declaration]
          : [declaration, declarationSecond],
      namespaceEdges:
          namespaceEdges ??
          (reverse
              ? [
                  genericNamespaceSecond,
                  declaredPartNamespace,
                  genericNamespace,
                ]
              : [
                  genericNamespace,
                  declaredPartNamespace,
                  genericNamespaceSecond,
                ]),
      unresolved: const [],
      sourceUnresolved: reverse
          ? [unresolvedSourceSecond, unresolvedSource]
          : [unresolvedSource, unresolvedSourceSecond],
      sourceUnits: reverse
          ? [
              AlgorithmSourceUnitObservation(
                sourcePackageUri: 'package:fixture/b.dart',
                containingLibraryPackageUri: 'package:fixture/a.dart',
                unitKind: 'part',
                resultVariant: 'ResolvedUnitResult',
                sessionConsistent: true,
                blockingDiagnosticCodes: const [],
                declarationEdgeCount: 0,
                namespaceEdgeCount: 1,
                unresolvedCallCount: 0,
              ),
              sourceUnit,
            ]
          : [
              sourceUnit,
              AlgorithmSourceUnitObservation(
                sourcePackageUri: 'package:fixture/b.dart',
                containingLibraryPackageUri: 'package:fixture/a.dart',
                unitKind: 'part',
                resultVariant: 'ResolvedUnitResult',
                sessionConsistent: true,
                blockingDiagnosticCodes: const [],
                declarationEdgeCount: 0,
                namespaceEdgeCount: 1,
                unresolvedCallCount: 0,
              ),
            ],
      supportedCallReachability: const [],
      supportedCallReverseReachability: const [],
      supportedCallReverseSourceOwnership: const [],
      reachabilityHolds: const [],
      environmentHoldReasons: const [],
    );

    final forward = report([first, second]);
    final reverse = report([second, first], reverse: true);
    expect(forward.canonicalJson, reverse.canonicalJson);
    expect(forward.sha256Digest, matches(RegExp(r'^[a-f0-9]{64}$')));
    for (final key in [
      'package_json_sha256',
      'generator_source_sha256',
      'runner_source_sha256',
      'test_source_sha256',
    ]) {
      expect(forward.canonicalPayload[key], matches(RegExp(r'^[a-f0-9]{64}$')));
    }
    expect(
      forward.canonicalPayload['declared_entrypoint'],
      'npm run --silent algorithm:direct-edge-probe',
    );
    expect(forward.closureComplete, isFalse);
    expect(forward.compatibilityAccepted, isFalse);
    expect(forward.sourceInventoryReconciled, isTrue);
    expect(forward.acceptedSourceUnitCount, 2);
    expect(forward.canonicalPayload['schema_version'], 14);
    final partOwnership =
        (forward.canonicalPayload['part_ownership'] as List).single
            as Map<String, Object?>;
    expect(partOwnership['ownership_state'], 'accepted');
    expect(partOwnership['part_directive_branch_count'], 1);
    final ambiguousPartReport = report(
      [first, second],
      namespaceEdges: [
        genericNamespace,
        declaredPartNamespace,
        duplicatePartNamespace,
        genericNamespaceSecond,
      ],
    );
    final ambiguousPartOwnership =
        (ambiguousPartReport.canonicalPayload['part_ownership'] as List).single
            as Map<String, Object?>;
    expect(ambiguousPartOwnership['ownership_state'], 'held');
    expect(
      ambiguousPartOwnership['hold_reason'],
      'declaring_part_directive_not_unique',
    );
    expect(forward.canonicalPayload['supported_call_reachability'], isEmpty);
    expect(
      forward.canonicalPayload['supported_call_reverse_ownership'],
      isEmpty,
    );
    expect(
      forward.canonicalPayload['uncovered_edge_classes'],
      contains('untracked_gitignore_and_non_lib_source_snapshot'),
    );
  });
}
