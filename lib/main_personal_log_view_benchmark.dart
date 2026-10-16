import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/models/intake.dart';
import 'core/models/meal.dart';
import 'core/services/pinned_timezone_rules_service.dart';
import 'core/services/services.dart';
import 'core/state/app_state.dart';
import 'core/theme/paper_theme.dart';
import 'domain/entities/personal_log_view.dart';
import 'domain/entities/personal_observation.dart';
import 'domain/entities/timeline_event.dart';
import 'domain/usecases/get_timeline_usecase.dart';
import 'domain/usecases/personal_log_date_window_resolver.dart';
import 'domain/usecases/personal_log_view_projector.dart';
import 'engineering/personal_log_view_benchmark_fixture.dart';
import 'engineering/personal_log_persistent_benchmark.dart';
import 'features/timeline/timeline_lookup_index.dart';
import 'features/timeline/timeline_page.dart';

/// Separately built engineering target. The memory and guarded disposable
/// storage experiments are separate runs, following formal W31 verification.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await pinnedTimezoneRulesService.initializeForApp();
  runApp(
    MaterialApp(
      title: 'ParkinSUM personal-log release benchmark',
      theme: Paper.themeData(),
      locale: const Locale('en', 'US'),
      supportedLocales: const [Locale('en', 'US'), Locale('zh', 'CN')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _BenchmarkPage(),
    ),
  );
}

const _w31Verified = bool.fromEnvironment('PARKINSUM_W31_BASELINE_VERIFIED');
const _w31Receipt = String.fromEnvironment('PARKINSUM_W31_RECEIPT');
const _buildReceiptPath = 'build/upgrade_delivery/build_receipt.json';
const _candidateInputs = String.fromEnvironment(
  'PARKINSUM_BENCHMARK_INPUT_SHA256',
);
const _toolchain = String.fromEnvironment('PARKINSUM_BENCHMARK_TOOLCHAIN');
const _warmups = 2;
const _repetitions = 7;
const _scrollSteps = [
  'top',
  'one_viewport',
  'three_viewports',
  'estimated_tail',
  'top',
];
final _receiptShape = RegExp(r'^[a-fA-F0-9]{64}$');

String? get _holdReason {
  if (!kReleaseMode || !kIsWeb) {
    return 'Use the separately built release-Web target.';
  }
  if (!_w31Verified || _w31Receipt.trim().isEmpty) {
    return 'HOLD: the formal entry and real-storage W31 journey must be verified first.';
  }
  if (!_receiptShape.hasMatch(_candidateInputs) || _toolchain.trim().isEmpty) {
    return 'HOLD: supply candidate-input and toolchain receipts.';
  }
  return null;
}

class _BenchmarkPage extends StatefulWidget {
  const _BenchmarkPage();
  @override
  State<_BenchmarkPage> createState() => _BenchmarkPageState();
}

class _BenchmarkPageState extends State<_BenchmarkPage> {
  final _hardware = TextEditingController();
  final _browser = TextEditingController();
  bool _running = false;
  String _progress = 'No measurements have run.';
  Map<String, Object?>? _report;
  int _sink = 0;
  int _fixtureCount = 0;
  Map<String, Object>? _activePhases;

  // Synthetic engineering metrics only. Emit outside timed intervals so a
  // stalled renderer does not erase all diagnostic context before final JSON.
  void _metric(String event, Map<String, Object?> details) {
    // ignore: avoid_print
    print(
      '[personal-log-benchmark] ${jsonEncode({'event': event, 'atUtc': DateTime.now().toUtc().toIso8601String(), 'mealCount': _fixtureCount, ...details})}',
    );
  }

  @override
  void dispose() {
    _hardware.dispose();
    _browser.dispose();
    super.dispose();
  }

  void _note(String message) {
    if (mounted) {
      setState(() => _progress = message);
    }
  }

  Future<Map<String, Object>> _measure(
    String phase,
    Future<int> Function() operation,
  ) async {
    _metric('phase_started', {'phase': phase});
    try {
      final distribution = await measurePersonalLogBenchmark(
        operation: operation,
        consume: (checksum) => _sink = (_sink + checksum) % 2147483647,
        onSample: (sample) =>
            _metric('sample_completed', {'phase': phase, ...sample}),
      );
      _metric('phase_completed', {
        'phase': phase,
        'distribution': distribution,
      });
      return distribution;
    } on PersonalLogBenchmarkIncomplete catch (error) {
      _activePhases?[phase] = error.evidence;
      _metric('phase_incomplete', {'phase': phase, 'evidence': error.evidence});
      rethrow;
    }
  }

  Future<_FixtureState> _ready(PersonalLogBenchmarkFixture fixture) async {
    final state = _FixtureState(fixture);
    try {
      await state.services.ready;
      await state.bootstrap();
      await state.saveUserProfile(
        state.userProfile.copyWith(timezone: 'Etc/UTC', displayLocale: 'en-US'),
      );
      state.foodRepo.replaceAll(fixture.foods);
      state.medRepo.replaceAll(fixture.drugs);
      return state;
    } catch (_) {
      state.dispose();
      rethrow;
    }
  }

  Future<Map<String, Object>> _mountedTimeline(
    _FixtureState state,
    Map<String, Object> phases,
  ) async {
    final initialRaw = <double>[];
    final scrollRaw = <double>[];
    final scrollEvidence = <Map<String, Object>>[];
    final pageRaw = <double>[];
    final pageEvidence = <Map<String, Object>>[];
    final progress = <String, Object>{
      'status': 'running',
      'initialFrameRawSamplesMs': initialRaw,
      'scrollRawSamplesMs': scrollRaw,
      'scrollEvidence': scrollEvidence,
      'allPageNavigationRawSamplesMs': pageRaw,
      'allPageNavigationEvidence': pageEvidence,
    };
    // Keep completed samples even when a mounted route/scroll step fails.
    phases['mounted_timeline_progress'] = progress;
    for (var index = 0; index < _warmups + _repetitions; index++) {
      if (!mounted) {
        throw StateError('Benchmark view was closed.');
      }
      _metric('mounted_iteration_started', {'iteration': index});
      final rootKey = GlobalKey();
      final navigator = Navigator.of(context);
      final stopwatch = Stopwatch()..start();
      final route = PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, animation, secondaryAnimation) =>
            ChangeNotifierProvider<AppState>.value(
              value: state,
              child: KeyedSubtree(key: rootKey, child: const TimelinePage()),
            ),
      );
      final closed = navigator.push<void>(route);
      try {
        await _twoFrames();
        stopwatch.stop();
        if (index >= _warmups) {
          initialRaw.add(stopwatch.elapsedMicroseconds / 1000);
        }
        _metric('initial_frames_completed', {
          'iteration': index,
          'warmup': index < _warmups,
          'elapsedMs': stopwatch.elapsedMicroseconds / 1000,
        });
        // Let finite Paper entrance transitions finish before scroll timing.
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (rootKey.currentContext?.mounted != true || !route.isCurrent) {
          throw StateError('The actual Timeline page is no longer mounted.');
        }
        final list = _timelineList(rootKey);
        var maxMountedRows = _mountedRows(rootKey);
        final offsets = <double>[];
        final correctionCounts = <int>[];
        final scrollWatch = Stopwatch()..start();
        for (final step in _scrollSteps) {
          final position = list.position;
          final requested = switch (step) {
            'one_viewport' => position.viewportDimension,
            'three_viewports' => position.viewportDimension * 3,
            'estimated_tail' => position.maxScrollExtent,
            _ => 0.0,
          };
          position.jumpTo(
            requested.clamp(0.0, position.maxScrollExtent).toDouble(),
          );
          await _twoFrames();
          if (rootKey.currentContext?.mounted != true ||
              !list.mounted ||
              !route.isCurrent) {
            throw StateError('Timeline changed during the measured scroll.');
          }
          var count = _mountedRows(rootKey);
          var corrections = 0;
          // Variable row heights can shrink the estimated tail after layout.
          // Include bounded corrective frames in timing instead of calling an
          // empty overshoot a successful scroll. Do not substitute row heights.
          while (count == 0 && corrections < 2) {
            position.jumpTo(
              position.pixels.clamp(0.0, position.maxScrollExtent).toDouble(),
            );
            await _twoFrames();
            count = _mountedRows(rootKey);
            corrections++;
          }
          if (count == 0) {
            throw StateError(
              'The measured scroll produced no original records.',
            );
          }
          correctionCounts.add(corrections);
          offsets.add(position.pixels);
          if (count > maxMountedRows) {
            maxMountedRows = count;
          }
        }
        scrollWatch.stop();
        _metric('scroll_frames_completed', {
          'iteration': index,
          'warmup': index < _warmups,
          'elapsedMs': scrollWatch.elapsedMicroseconds / 1000,
          'actualOffsetsPx': offsets,
          'maxMountedOriginalRows': maxMountedRows,
          'correctiveTwoFrameSteps': correctionCounts,
        });
        if (maxMountedRows == 0 ||
            maxMountedRows >= state.fixture.meals.length) {
          throw StateError(
            'Expected original rows in a virtual list, not full materialization.',
          );
        }
        _sink = (_sink + maxMountedRows) % 2147483647;
        if (index >= _warmups) {
          scrollRaw.add(scrollWatch.elapsedMicroseconds / 1000);
          scrollEvidence.add({
            'actualOffsetsPx': offsets,
            'maxMountedOriginalRows': maxMountedRows,
            'eventCount': state.timeline.length,
            'visibleWindowEventCount': state.timeline.length.clamp(
              0,
              TimelinePage.recordWindowSize,
            ),
            'windowIndex': 0,
            'correctiveTwoFrameSteps': correctionCounts,
          });
        }
        final fullEvents = state.timeline;
        final pageCount = (fullEvents.length / TimelinePage.recordWindowSize)
            .ceil();
        final pages = <String>[];
        final counts = <String>[];
        final pageWatch = Stopwatch()..start();
        for (var page = 0; page < pageCount; page++) {
          if (page > 0) {
            final next = _widgetForKey<IconButton>(
              rootKey,
              'timeline-next-records',
            );
            if (next?.onPressed == null) {
              throw StateError('Timeline next-page control unavailable.');
            }
            next!.onPressed!();
            await _twoFrames();
          }
          final count = _widgetForKey<Text>(
            rootKey,
            'timeline-view-count',
          )?.data;
          final label = _widgetForKey<Text>(
            rootKey,
            'timeline-record-page',
          )?.data;
          final remaining =
              fullEvents.length - page * TimelinePage.recordWindowSize;
          final expectedShown = remaining.clamp(
            0,
            TimelinePage.recordWindowSize,
          );
          final actualKeys = _mountedRowKeys(rootKey);
          final allowedKeys = fullEvents
              .skip(page * TimelinePage.recordWindowSize)
              .take(TimelinePage.recordWindowSize)
              .map(
                (event) =>
                    'timeline-record-${TypedLogRecordRef.fromEvent(event).viewKey}',
              )
              .toSet();
          if (count !=
                  '${fullEvents.length} of ${fullEvents.length} records match; $expectedShown currently shown.' ||
              actualKeys.isEmpty ||
              !actualKeys.every(allowedKeys.contains)) {
            throw StateError(
              'Timeline page does not show the exact declared original-record window.',
            );
          }
          if (pageCount > 1 &&
              (label == null ||
                  !label.startsWith('Page ${page + 1} of $pageCount ·'))) {
            throw StateError('Timeline page control selected the wrong page.');
          }
          pages.add(label ?? 'Single page');
          counts.add(count!);
        }
        if (pageCount > 1 &&
            _widgetForKey<IconButton>(
                  rootKey,
                  'timeline-next-records',
                )?.onPressed !=
                null) {
          throw StateError('Timeline final-page boundary is not disabled.');
        }
        pageWatch.stop();
        _metric('all_pages_completed', {
          'iteration': index,
          'warmup': index < _warmups,
          'elapsedMs': pageWatch.elapsedMicroseconds / 1000,
          'pageCount': pageCount,
        });
        if (index >= _warmups) {
          pageRaw.add(pageWatch.elapsedMicroseconds / 1000);
          pageEvidence.add({
            'pageCount': pageCount,
            'pageLabels': pages,
            'countLabels': counts,
            'eventCount': fullEvents.length,
            'forwardMoves': pageCount - 1,
          });
        }
      } finally {
        if (route.isCurrent) {
          navigator.pop();
        } else if (route.isActive) {
          navigator.removeRoute(route);
        }
        await closed;
        await _twoFrames();
        _metric('mounted_iteration_released', {'iteration': index});
      }
    }
    progress['status'] = 'completed';
    return {
      'timeline_initial_two_frames': personalLogBenchmarkDistribution(
        initialRaw,
      ),
      'timeline_first_window_scroll': personalLogBenchmarkDistribution(
        scrollRaw,
      ),
      'scrollEvidence': scrollEvidence,
      'timeline_all_record_page_controls': personalLogBenchmarkDistribution(
        pageRaw,
      ),
      'allPageNavigationEvidence': pageEvidence,
    };
  }

  Future<void> _run({bool persistent = false}) async {
    if (_running || _holdReason != null) {
      return;
    }
    final hardware = _hardware.text.trim();
    final browser = _browser.text.trim();
    if (hardware.isEmpty || browser.isEmpty) {
      _note('Enter the hardware/OS and browser/version used for this run.');
      return;
    }
    setState(() {
      _running = true;
      _report = null;
      _sink = 0;
      _activePhases = null;
    });
    final started = DateTime.now().toUtc();
    final results = <Map<String, Object?>>[];
    String? failure;
    try {
      final persistentSession = persistent
          ? await PersonalLogPersistentBenchmark.open(source: _candidateInputs)
          : null;
      for (final count in PersonalLogBenchmarkFixture.sizes) {
        _fixtureCount = count;
        _metric('fixture_started', {});
        _note(
          '$count synthetic meals: measuring production projections and the actual Timeline list.',
        );
        final fixture = PersonalLogBenchmarkFixture.generate(count);
        if (persistentSession != null) {
          if (!mounted) {
            throw StateError('Benchmark view was closed.');
          }
          _note(
            '$count synthetic meals: measuring actual local Web storage paths.',
          );
          await persistentSession.measure(
            fixture: fixture,
            context: context,
            measurePhase: _measure,
            retainEvidence: results.add,
          );
          continue;
        }
        final inputSha = fixture.inputSha256;
        final window = PersonalLogDateWindowResolver().resolve(
          PersonalLogDateWindow(
            start: LogCivilDate(2026, 9, 1),
            endInclusive: LogCivilDate(2026, 9, 30),
            zoneId: 'Etc/UTC',
          ),
          asOf: PersonalLogBenchmarkFixture.asOf,
        );
        final timeline = GetTimelineUseCase()(
          meals: fixture.meals,
          intakes: fixture.intakes,
          medications: fixture.drugs,
        );
        const projector = PersonalLogViewProjector();
        const focus = TypedLogRecordRef(
          TimelineEventType.meal,
          'synthetic-perf-row-1',
        );
        final phases = <String, Object>{};
        _activePhases = phases;
        results.add({
          'fixture': fixture.parameters,
          'fixtureInputSha256': inputSha,
          'phases': phases,
        });
        phases['fixture_generation_only'] = await _measure(
          'fixture_generation_only',
          () async => PersonalLogBenchmarkFixture.generate(count).meals.length,
        );
        phases['timeline_sort'] = await _measure(
          'timeline_sort',
          () async => GetTimelineUseCase()(
            meals: fixture.meals,
            intakes: fixture.intakes,
            medications: fixture.drugs,
          ).length,
        );
        phases['insights_projection'] = await _measure(
          'insights_projection',
          () async {
            final projected = projector.insights(
              window: window,
              meals: fixture.meals,
              intakes: fixture.intakes,
              observations: const [],
              foods: fixture.foods,
              medications: fixture.drugs,
            );
            return projected.historical.length +
                projected.future.length +
                projected.knownProtein.length;
          },
        );
        phases['timeline_name_source_filter'] = await _measure(
          'timeline_name_source_filter',
          () async => projector
              .timeline(
                fullEvents: timeline,
                meals: fixture.meals,
                intakes: fixture.intakes,
                observations: const [],
                foods: fixture.foods,
                medications: fixture.drugs,
                query: TimelineViewQuery(
                  window: window,
                  name: 'Synthetic benchmark meal',
                  types: {TimelineEventType.meal},
                  sources: {'catalog:SYNTHETIC_PERF'},
                ),
              )
              .visible
              .length,
        );
        phases['timeline_typed_focus'] = await _measure(
          'timeline_typed_focus',
          () async {
            final projected = projector.timeline(
              fullEvents: timeline,
              meals: fixture.meals,
              intakes: fixture.intakes,
              observations: const [],
              foods: fixture.foods,
              medications: fixture.drugs,
              query: TimelineViewQuery(),
              focus: focus,
            );
            if (projected.focusStatus != TimelineFocusStatus.found ||
                projected.visible.single.recordId != focus.recordId) {
              throw StateError(
                'Typed focus did not resolve the exact original record.',
              );
            }
            return projected.visible.length;
          },
        );
        phases['full_timeline_lookup_index'] = await _measure(
          'full_timeline_lookup_index',
          () async {
            final index = TimelineLookupIndex(
              events: timeline,
              meals: fixture.meals,
              intakes: fixture.intakes,
            );
            return index.nearestIntakeForMeal(fixture.meals[1]) == null ? 0 : 1;
          },
        );
        phases['ephemeral_services_bootstrap_only'] = await _measure(
          'ephemeral_services_bootstrap_only',
          () async {
            final state = await _ready(fixture);
            try {
              return state.meals.length;
            } finally {
              state.dispose();
            }
          },
        );
        _metric('mounted_services_started', {});
        final state = await _ready(fixture);
        _metric('mounted_services_ready', {});
        try {
          phases.addAll(await _mountedTimeline(state, phases));
        } finally {
          state.dispose();
        }
        if (inputSha != fixture.inputSha256) {
          throw StateError('Fixture mutated during measurement.');
        }
      }
    } catch (error) {
      failure = '$error';
      _metric('run_failed', {'failure': failure});
    } finally {
      final view = WidgetsBinding.instance.platformDispatcher.views.first;
      final report = <String, Object?>{
        'schema': 'parkinsum.personal-log-view-release-benchmark/2',
        'experiment': persistent
            ? 'disposable_persistent_web'
            : 'ephemeral_timeline',
        'status': failure != null
            ? 'failed'
            : results.any((row) => (row['holds'] as List?)?.isNotEmpty == true)
            ? 'measured_with_holds'
            : 'measured',
        'startedAtUtc': started.toIso8601String(),
        'completedAtUtc': DateTime.now().toUtc().toIso8601String(),
        'declaredReceipts': {
          'w31': _w31Receipt,
          'benchmarkBuildReceiptPath': _buildReceiptPath,
          'candidateInputsSha256': _candidateInputs,
          'toolchain': _toolchain,
          'verification':
              'W31/source/toolchain labels are supplied at build time. Root separately verifies the actual build_id/hash in the external build receipt and delivery index; no build ID is asserted by this program.',
        },
        'environment': {
          'hardwareAndOsOperatorDeclared': hardware,
          'browserVersionOperatorDeclared': browser,
          'runtime': persistent
              ? 'Flutter release Web; actual Services.createDefault and WebAppDatabase in guarded disposable origin'
              : 'Flutter release Web; production TimelinePage; ephemeral AppState fixture subclass',
          'isWeb': kIsWeb,
          'isRelease': kReleaseMode,
          'targetPlatform': defaultTargetPlatform.name,
          'locale': WidgetsBinding.instance.platformDispatcher.locale
              .toLanguageTag(),
          'physicalWidth': view.physicalSize.width,
          'physicalHeight': view.physicalSize.height,
          'devicePixelRatio': view.devicePixelRatio,
          'stopwatchFrequencyHz': Stopwatch().frequency,
        },
        'protocol': {
          'warmupsPerPhaseAndSize': _warmups,
          'measuredRepetitionsPerPhaseAndSize': _repetitions,
          'sampleUnit': 'ms',
          'clock': 'Stopwatch.elapsedMicroseconds',
          'scrollSteps': _scrollSteps,
          'completeFramesPerScrollStep': 2,
          'maximumCorrectiveTwoFrameStepsPerScroll': 2,
          'recordWindowSize': TimelinePage.recordWindowSize,
          'scrollScope':
              'First bounded record window over the full input projection; no full-history tail timing claim.',
          'pageNavigationScope':
              'All forward record-page controls with two complete frames per move; separate from first-window scrollbar timing.',
          'entranceWaitOutsideScrollMeasurementMs': 500,
          'includes': persistent
              ? [
                  'fresh production service graph and AppState over durable synthetic records',
                  'shipped catalogue search with six fixed queries',
                  'complete-input countsOnly summary and HTML, within production budgets',
                  'raster PDF with fixed 20-meal/4-intake subset',
                  'portable package generation, prepare, confirmed commit, readback and rollback attempts',
                ]
              : [
                  'declared fixture generation',
                  'production timeline sort',
                  'production insights projection',
                  'view-only name/source/type/date filter',
                  'typed focus',
                  'full nearest-neighbour index',
                  'ephemeral services setup',
                  'actual Timeline first two complete frames',
                  'actual first-window virtual list scroll frames, including any overshoot corrections',
                  'actual forward controls through every bounded record page (memory run)',
                ],
          'excludes': [
            'browser or OS process restart and uncached resource fetching',
            'full-history scrollbar tail traversal',
            if (!persistent) ...[
              'persistent startup',
              'catalogue search',
              'report generation',
              'portable restore',
            ],
            if (persistent)
              'mounted Timeline measurements (separate memory run)',
            'formal entry and real-storage W31 journey',
            'native hardware',
            'clinical performance',
          ],
          'comparisonRule':
              'Compare only matching fixture SHA, hardware, browser, viewport, runtime and protocol; retain both source/build receipts.',
          'optimizationsApplied': 1,
          'optimization':
              'Explicit bounded Timeline record windows; full filter/focus/nearest-neighbour projection retained. Prior unbounded release runs crashed before complete raw timings; no numerical speed-up asserted.',
          'diagnostics':
              'Synthetic phase/sample events outside Stopwatch intervals. Persistent run requires an initially empty marker-owned origin; no formal W31 data is used. Not a cross-tab lease guarantee.',
        },
        'results': results,
        'consumedOutputChecksum': _sink,
        'failure': ?failure,
      };
      _metric('run_report', {'report': report});
      if (mounted) {
        setState(() {
          _report = report;
          _running = false;
          _progress = failure == null
              ? 'Measurements complete. Keep the JSON and independent build receipt.'
              : 'Measurement failed. Partial samples are retained; this is not a passing baseline.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Personal-log release benchmark — engineering'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Two separate synthetic experiments: Timeline in memory, or actual local Web storage in an initially empty disposable origin. Storage measurements retain production budget/validation failures; no clinical interpretation.',
        ),
        const SizedBox(height: 12),
        const Text(
          'Run after the independently verified W31 journey. Keep this tab visible and avoid changing viewport or interacting with the measured Timeline. Two warmups and seven measured repetitions are run at each size.',
        ),
        if (_holdReason != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(_holdReason!, key: const ValueKey('benchmark-hold')),
          ),
        TextField(
          controller: _hardware,
          enabled: !_running,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Hardware and OS (operator declared)',
          ),
        ),
        TextField(
          controller: _browser,
          enabled: !_running,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Browser and version (operator declared)',
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            key: const ValueKey('benchmark-run'),
            onPressed: _running || _holdReason != null ? null : () => _run(),
            child: const Text('Measure 100 / 1,000 / 10,000 synthetic meals'),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            key: const ValueKey('benchmark-run-persistent'),
            onPressed: _running || _holdReason != null
                ? null
                : () => _run(persistent: true),
            child: const Text(
              'Measure actual storage — empty disposable origin only',
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(_progress, key: const ValueKey('benchmark-progress')),
        if (_report != null) ...[
          const SizedBox(height: 16),
          SelectableText(
            const JsonEncoder.withIndent('  ').convert(_report),
            key: const ValueKey('benchmark-json'),
          ),
        ],
      ],
    ),
  );
}

Future<void> _twoFrames() async {
  await WidgetsBinding.instance.endOfFrame;
  await WidgetsBinding.instance.endOfFrame;
}

Element _mountedElement(GlobalKey key) {
  final context = key.currentContext;
  if (context is! Element || !context.mounted) {
    throw StateError('The measured Timeline subtree is unavailable.');
  }
  return context;
}

ScrollableState _timelineList(GlobalKey key) {
  final root = _mountedElement(key);
  final matches = <ScrollableState>[];
  void visit(Element element) {
    if (element is StatefulElement && element.state is ScrollableState) {
      final scrollable = element.state as ScrollableState;
      if (axisDirectionToAxis(scrollable.widget.axisDirection) ==
              Axis.vertical &&
          element.findAncestorWidgetOfExactType<ListView>() != null) {
        matches.add(scrollable);
      }
    }
    element.visitChildren(visit);
  }

  visit(root);
  if (matches.length != 1) {
    throw StateError('Expected the actual Timeline virtual ListView.');
  }
  return matches.single;
}

int _mountedRows(GlobalKey key) => _mountedRowKeys(key).length;

Set<String> _mountedRowKeys(GlobalKey key) {
  final root = _mountedElement(key);
  final keys = <String>{};
  void visit(Element element) {
    final key = element.widget.key;
    if (key is ValueKey<String> &&
        RegExp(r'^timeline-record-(meal|medication):').hasMatch(key.value)) {
      keys.add(key.value);
    }
    element.visitChildren(visit);
  }

  visit(root);
  return keys;
}

T? _widgetForKey<T extends Widget>(GlobalKey rootKey, String value) {
  T? found;
  void visit(Element element) {
    if (element.widget is T && element.widget.key == ValueKey(value)) {
      found = element.widget as T;
    }
    element.visitChildren(visit);
  }

  visit(_mountedElement(rootKey));
  return found;
}

class _FixtureState extends AppState {
  _FixtureState(this.fixture) : super(services: Services.createEphemeral());
  final PersonalLogBenchmarkFixture fixture;
  @override
  List<Meal> get meals => List.unmodifiable(fixture.meals);
  @override
  List<Intake> get intakes => List.unmodifiable(fixture.intakes);
  @override
  List<PersonalObservation> get observations => const [];
  @override
  List<TimelineEvent> get timeline => services.getTimelineUseCase(
    meals: meals,
    intakes: intakes,
    observations: observations,
    medications: medRepo.allDrugs,
  );
}
