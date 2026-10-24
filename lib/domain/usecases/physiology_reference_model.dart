/// Pure-Dart port of the physiology reference model
/// (`tool/physiology_reference/model.py`), Stage B.
///
/// Educational research prototype. It simulates population-typical curves in
/// physical units for synthetic scenarios: not a prediction for any person,
/// not a clinical cutoff and not dosing, timing or dietary advice.
///
/// Structure (see `docs/design/PHYSIOLOGY_MODEL_V2.md`):
///
///   stomach      per food component, nutrient-tracked. Solids pass two
///                grinding stages before they can empty; energy-containing
///                liquids can empty at once. The emptiable pool leaves at a
///                calorie-limited rate R = R_max·P/(P+E50) [kcal/min]. Water
///                and dissolved drug empty first-order, slowed by the energy
///                still in the stomach: k = k_fast/(1 + F/F50).
///   levodopa     IR tablet → dissolved → absorptive gut → one plasma
///                compartment [mg/L].
///   amino acids  one plasma pool per amino acid [µmol/L], fed by each
///                component's emptied energy, relaxing to its fasting value.
///   brain entry  B = (1 + ΣCb/Km)/(1 + ΣC/Km): levodopa entry relative to
///                the same plasma level when fasting.
///
/// The integration order, the floating-point operation order and the seeded
/// random stream follow the Python reference so the two runtimes agree to
/// rounding (`test/physiology_reference_agreement_test.dart`).
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../entities/physiology_reference_parameters.dart';

/// Molecular weights (g/mol) of the free amino acids.
const Map<String, double> physiologyAminoAcidMolecularWeights = {
  'leu': 131.17,
  'ile': 131.17,
  'val': 117.15,
  'phe': 165.19,
  'tyr': 181.19,
  'trp': 204.23,
  'met': 149.21,
  'his': 155.16,
};

/// The six large neutral amino acids summed for comparison with Carter 1989.
const List<String> physiologyLnaaSix = [
  'leu',
  'ile',
  'val',
  'phe',
  'tyr',
  'trp',
];

/// Every amino acid competing with levodopa at the blood-brain barrier.
const List<String> physiologyBbbSet = [...physiologyLnaaSix, 'met', 'his'];

enum PhysiologyComponentForm { solid, liquid, water, coagulating }

/// One food component of a meal; amounts are for the portion eaten.
final class PhysiologyComponent {
  final String name;
  final PhysiologyComponentForm form;
  final double kcal;
  final double proteinG;

  /// Grams of each amino acid in the portion; null uses the mixed-protein
  /// composition scaled by [proteinG].
  final Map<String, double>? aminoAcidsG;
  final double waterMl;

  const PhysiologyComponent(
    this.name,
    this.form, {
    this.kcal = 0.0,
    this.proteinG = 0.0,
    this.aminoAcidsG,
    this.waterMl = 0.0,
  });

  Map<String, double> aminoAcidGrams(Map<String, double> composition) {
    final explicit = aminoAcidsG;
    return {
      for (final a in physiologyBbbSet)
        a: explicit != null ? (explicit[a] ?? 0.0) : proteinG * composition[a]!,
    };
  }
}

final class PhysiologyMeal {
  final double timeMin;
  final List<PhysiologyComponent> components;
  const PhysiologyMeal(this.timeMin, this.components);
}

/// Immediate-release oral levodopa; other formulations are not executable.
final class PhysiologyDose {
  final double timeMin;
  final double levodopaMg;
  const PhysiologyDose(this.timeMin, this.levodopaMg);
}

final class PhysiologyInfusion {
  final double startMin;
  final double endMin;
  final double mgPerMin;
  const PhysiologyInfusion(this.startMin, this.endMin, this.mgPerMin);
}

final class PhysiologyScenario {
  final List<PhysiologyMeal> meals;
  final List<PhysiologyDose> doses;
  final List<PhysiologyInfusion> infusions;
  final double tEndMin;
  final double dtMin;
  final double recordEveryMin;

  const PhysiologyScenario({
    this.meals = const [],
    this.doses = const [],
    this.infusions = const [],
    this.tEndMin = 360.0,
    this.dtMin = 0.25,
    this.recordEveryMin = 1.0,
  });
}

/// Resolved parameter values: the central set or one seeded draw.
final class PhysiologyParameterValues {
  final Map<String, double> scalars;
  final Map<String, Map<String, double>> perAminoAcid;

  const PhysiologyParameterValues._(this.scalars, this.perAminoAcid);

  factory PhysiologyParameterValues.central([
    List<PhysiologyReferenceParameter> parameters =
        PhysiologyReferenceParameterSet.parameters,
  ]) => PhysiologyParameterValues._(
    {
      for (final p in parameters)
        if (p.scalar != null) p.id: p.scalar!,
    },
    {
      for (final p in parameters)
        if (p.perAminoAcid != null) p.id: Map.of(p.perAminoAcid!),
    },
  );

  double operator [](String id) =>
      scalars[id] ?? (throw ArgumentError.value(id, 'id', 'not a scalar'));

  Map<String, double> map(String id) =>
      perAminoAcid[id] ??
      (throw ArgumentError.value(id, 'id', 'not per amino acid'));
}

/// Recorded curves. Units are part of each name.
final class PhysiologySeries {
  static const List<String> keys = [
    't',
    'stomach_kcal',
    'stomach_retention_solid',
    'energy_out_kcal_per_min',
    'water_ml',
    'levodopa_mg_per_l',
    'lnaa6_umol_per_l',
    'brain_entry_index',
    'brain_delivery_index',
    'leu_umol_per_l',
    'phe_umol_per_l',
  ];

  final Map<String, List<double>> values;

  PhysiologySeries._(this.values);

  List<double> get t => values['t']!;
  List<double> operator [](String key) =>
      values[key] ?? (throw ArgumentError.value(key, 'key'));

  /// A copy with time shifted so that [origin] becomes zero.
  PhysiologySeries shifted(double origin) => PhysiologySeries._({
    for (final entry in values.entries)
      entry.key: entry.key == 't'
          ? [for (final t in entry.value) t - origin]
          : List.of(entry.value),
  });

  /// Value at the recorded time nearest to [t] (first on ties).
  double at(String key, double t) {
    final ts = this.t;
    var best = 0;
    for (var j = 1; j < ts.length; j++) {
      if ((ts[j] - t).abs() < (ts[best] - t).abs()) best = j;
    }
    return this[key][best];
  }

  /// First maximum within [t0, t1] as (time, value).
  (double, double) peak(String key, [double t0 = 0.0, double t1 = 1e9]) {
    double? bestT;
    var best = double.negativeInfinity;
    final ys = this[key];
    for (var i = 0; i < t.length; i++) {
      if (t0 <= t[i] && t[i] <= t1 && ys[i] > best) {
        bestT = t[i];
        best = ys[i];
      }
    }
    return (bestT ?? double.nan, best);
  }

  /// First minimum within [t0, t1] as (time, value).
  (double, double) trough(String key, [double t0 = 0.0, double t1 = 1e9]) {
    double? bestT;
    var best = double.infinity;
    final ys = this[key];
    for (var i = 0; i < t.length; i++) {
      if (t0 <= t[i] && t[i] <= t1 && ys[i] < best) {
        bestT = t[i];
        best = ys[i];
      }
    }
    return (bestT ?? double.nan, best);
  }

  /// Trapezoid area of [key] over [t0, t1] (unit × min).
  double area(String key, double t0, double t1) {
    final ys = this[key];
    var total = 0.0;
    for (var i = 1; i < t.length; i++) {
      final a = math.max(t[i - 1], t0);
      final b = math.min(t[i], t1);
      if (b > a) total += 0.5 * (ys[i - 1] + ys[i]) * (b - a);
    }
    return total;
  }
}

final class _ComponentState {
  final double e0;
  double s1;
  double s2;
  double p;

  /// µmol of each amino acid, indexed like [physiologyBbbSet].
  final Float64List aaUmol;
  _ComponentState(this.e0, this.s1, this.s2, this.p, this.aaUmol);
}

/// Explicit-Euler integration on a fixed grid. Deterministic.
///
/// Amino acids are indexed in [physiologyBbbSet] order and every sum runs in
/// the reference's order, so results match it to rounding.
PhysiologySeries simulatePhysiology(
  PhysiologyScenario scenario,
  PhysiologyParameterValues v,
) {
  const aminoAcids = physiologyBbbSet;
  const n = 8; // aminoAcids.length
  const leu = 0; // index of 'leu'
  const phe = 3; // index of 'phe'
  const lnaaCount = 6; // physiologyLnaaSix is the first six
  // Typed arrays hold the same doubles as plain lists; they only avoid boxing.
  Float64List indexed(Map<String, double> byName) =>
      Float64List.fromList([for (final a in aminoAcids) byName[a]!]);

  final dt = scenario.dtMin;
  final kT = v['stomach.solid_trituration_rate_per_min'];
  final rMax = v['stomach.energy_delivery_max_kcal_per_min'];
  final e50 = v['stomach.energy_tail_half_kcal'];
  final kFast = math.ln2 / v['stomach.fasted_liquid_half_time_min'];
  final f50 = v['stomach.fed_liquid_slowing_half_kcal'];
  final kDis = math.ln2 / v['levodopa.ir_dissolution_half_time_min'];
  final ka = math.ln2 / v['levodopa.gut_absorption_half_time_min'];
  final cl = v['levodopa.apparent_clearance_l_per_h'] / 60.0; // L/min
  final vd = v['levodopa.apparent_volume_l'];
  final kEl = cl / vd;
  final kDig = math.ln2 / v['aa.digestion_absorption_half_time_min'];
  final vAa = v['aa.plasma_distribution_volume_l'];
  final kOut = math.ln2 / v['aa.plasma_relaxation_half_time_min'];
  final fSys = indexed(v.map('aa.systemic_fraction'));
  final cBase = indexed(v.map('aa.fasting_plasma_umol_per_l'));
  final km = indexed(v.map('bbb.km_umol_per_l'));
  final composition = v.map('aa.mixed_protein_composition_g_per_g');

  final comps = <_ComponentState>[];
  var waterMl = 0.0;
  var tablet = 0.0;
  var dissolved = 0.0;
  var gut = 0.0;
  var plasmaMg = 0.0;
  final gutAa = Float64List(n);
  final conc = Float64List.fromList(cBase);
  final delivery = Float64List(n);
  var baseLoad = 0.0;
  for (var i = 0; i < n; i++) {
    baseLoad += cBase[i] / km[i];
  }
  final denomBase = 1.0 + baseLoad;

  final meals = [...scenario.meals]
    ..sort((x, y) => x.timeMin.compareTo(y.timeMin));
  final doses = [...scenario.doses]
    ..sort((x, y) => x.timeMin.compareTo(y.timeMin));
  var mi = 0;
  var di = 0;

  final out = {for (final key in PhysiologySeries.keys) key: <double>[]};
  var solidE0 = 0.0;
  final steps = (scenario.tEndMin / dt).round();
  final recStride = math.max(1, (scenario.recordEveryMin / dt).round());

  void record(double t, double fed, double outTot) {
    var load = 0.0;
    for (var i = 0; i < n; i++) {
      load += conc[i] / km[i];
    }
    final b = denomBase / (1.0 + load);
    final cLd = plasmaMg / vd;
    var solidLeft = 0.0;
    for (final c in comps) {
      if (c.e0 > 0) solidLeft += c.s1 + c.s2 + c.p;
    }
    var lnaa6 = 0.0;
    for (var i = 0; i < lnaaCount; i++) {
      lnaa6 += conc[i];
    }
    out['t']!.add(t);
    out['stomach_kcal']!.add(fed);
    out['stomach_retention_solid']!.add(
      solidE0 != 0 ? solidLeft / solidE0 : 0.0,
    );
    out['energy_out_kcal_per_min']!.add(outTot);
    out['water_ml']!.add(waterMl);
    out['levodopa_mg_per_l']!.add(cLd);
    out['lnaa6_umol_per_l']!.add(lnaa6);
    out['brain_entry_index']!.add(b);
    out['brain_delivery_index']!.add(cLd * b);
    out['leu_umol_per_l']!.add(conc[leu]);
    out['phe_umol_per_l']!.add(conc[phe]);
  }

  // Before the first meal, dose or infusion every Euler step leaves the
  // state exactly as it is (all amounts are zero and amino acids sit at
  // their fasting values), so those steps are recorded without integrating.
  // The recorded values are the same as integrating them would give.
  var firstEvent = double.infinity;
  if (meals.isNotEmpty) firstEvent = math.min(firstEvent, meals.first.timeMin);
  if (doses.isNotEmpty) firstEvent = math.min(firstEvent, doses.first.timeMin);
  for (final infusion in scenario.infusions) {
    firstEvent = math.min(firstEvent, infusion.startMin);
  }
  var start = 0;
  while (start <= steps && start * dt + 1e-9 < firstEvent) {
    // With nothing in the stomach the loop's stomach energy and emptying
    // rate are both 0.0.
    if (start % recStride == 0) record(start * dt, 0.0, 0.0);
    start++;
  }

  for (var step = start; step <= steps; step++) {
    final t = step * dt;
    while (mi < meals.length && meals[mi].timeMin <= t + 1e-9) {
      for (final c in meals[mi].components) {
        if (c.form == PhysiologyComponentForm.water) {
          waterMl += c.waterMl;
          continue;
        }
        final grams = c.aminoAcidGrams(composition);
        final aa = Float64List.fromList([
          for (final a in aminoAcids)
            grams[a]! / physiologyAminoAcidMolecularWeights[a]! * 1e6,
        ]);
        final kcal = math.max(c.kcal, 1e-9);
        if (c.form == PhysiologyComponentForm.solid ||
            c.form == PhysiologyComponentForm.coagulating) {
          comps.add(_ComponentState(kcal, kcal, 0.0, 0.0, aa));
          solidE0 += kcal;
        } else {
          comps.add(_ComponentState(kcal, 0.0, 0.0, kcal, aa));
        }
        waterMl += c.waterMl;
      }
      mi++;
    }
    while (di < doses.length && doses[di].timeMin <= t + 1e-9) {
      tablet += doses[di].levodopaMg;
      di++;
    }

    var pTot = 0.0;
    var fed = 0.0;
    for (final c in comps) {
      pTot += c.p;
      fed += c.s1 + c.s2 + c.p;
    }
    final outTot = pTot > 0 ? rMax * pTot / (pTot + e50) : 0.0;
    final kLiq = kFast / (1.0 + fed / f50);

    delivery.fillRange(0, n, 0.0);
    for (final c in comps) {
      final outC = pTot > 0 ? outTot * (c.p / pTot) : 0.0;
      final frac = outC / c.e0;
      for (var i = 0; i < n; i++) {
        delivery[i] += frac * c.aaUmol[i];
      }
      final dS1 = -kT * c.s1;
      final dS2 = kT * c.s1 - kT * c.s2;
      final dP = kT * c.s2 - outC;
      c.s1 += dS1 * dt;
      c.s2 += dS2 * dt;
      c.p = math.max(0.0, c.p + dP * dt);
    }

    var infusion = 0.0;
    for (final i in scenario.infusions) {
      if (i.startMin <= t && t < i.endMin) infusion += i.mgPerMin;
    }
    final dTab = -kDis * tablet;
    final dDis = kDis * tablet - kLiq * dissolved;
    final dGut = kLiq * dissolved - ka * gut;
    final dPl = ka * gut - kEl * plasmaMg + infusion;
    tablet += dTab * dt;
    dissolved += dDis * dt;
    gut += dGut * dt;
    plasmaMg += dPl * dt;
    waterMl += -kLiq * waterMl * dt;

    for (var i = 0; i < n; i++) {
      final absorbed = kDig * gutAa[i];
      gutAa[i] += (delivery[i] - absorbed) * dt;
      conc[i] += (fSys[i] * absorbed / vAa - kOut * (conc[i] - cBase[i])) * dt;
    }

    if (step % recStride == 0) record(t, fed, outTot);
  }
  return PhysiologySeries._(out);
}

/// Seeded log-normal draws for parameters that declare a between-person CV.
///
/// Uses [PythonCompatibleRandom], so for a given seed the draws equal the
/// reference's `sample_population` draws. They describe published
/// between-person spread; they are not estimates for any person.
List<PhysiologyParameterValues> samplePhysiologyPopulation(
  int n,
  int seed, [
  List<PhysiologyReferenceParameter> parameters =
      PhysiologyReferenceParameterSet.parameters,
]) {
  final rng = PythonCompatibleRandom(seed);
  final base = PhysiologyParameterValues.central(parameters);
  final draws = <PhysiologyParameterValues>[];
  for (var k = 0; k < n; k++) {
    final scalars = Map.of(base.scalars);
    final perAminoAcid = {
      for (final entry in base.perAminoAcid.entries)
        entry.key: Map.of(entry.value),
    };
    for (final p in parameters) {
      final cv = p.iivCv;
      if (cv == null || cv == 0) continue;
      final sigma = math.sqrt(math.log(1.0 + cv * cv));
      final factor = math.exp(rng.gauss(0.0, sigma) - sigma * sigma / 2);
      if (p.perAminoAcid != null) {
        perAminoAcid[p.id] = {
          for (final entry in p.perAminoAcid!.entries)
            entry.key: entry.value * factor,
        };
      } else {
        scalars[p.id] = p.scalar! * factor;
      }
    }
    draws.add(PhysiologyParameterValues._(scalars, perAminoAcid));
  }
  return draws;
}

/// Linear-interpolated percentile, as in the reference.
double physiologyPercentile(List<double> xs, double q) {
  if (xs.isEmpty) return double.nan;
  final s = [...xs]..sort();
  final k = (s.length - 1) * q;
  final lo = k.floor();
  final hi = k.ceil();
  return s[lo] + (s[hi] - s[lo]) * (k - lo);
}

/// The random stream of CPython's `random.Random(seed)` for a non-negative
/// integer seed below 2^32: MT19937 seeded by `init_by_array`, `random()`
/// with 53-bit resolution and `gauss()` with its cached second value.
///
/// 32-bit products are split into 16-bit halves so the VM and web builds
/// produce the same stream.
final class PythonCompatibleRandom {
  static const int _n = 624;
  static const int _m = 397;
  static const double _twoPi = 2.0 * math.pi;
  final List<int> _mt = List<int>.filled(_n, 0);
  int _mti = _n + 1;
  double? _gaussNext;

  PythonCompatibleRandom(int seed) {
    if (seed < 0 || seed > 0xffffffff) {
      throw ArgumentError.value(seed, 'seed', 'must fit in 32 bits');
    }
    _initByArray([seed]);
  }

  static int _mul32(int a, int b) {
    final high = ((a >> 16) * b) & 0xffff;
    return ((high << 16) + (a & 0xffff) * b) & 0xffffffff;
  }

  void _initGenrand(int s) {
    _mt[0] = s & 0xffffffff;
    for (var i = 1; i < _n; i++) {
      final prev = _mt[i - 1];
      _mt[i] = (_mul32(1812433253, prev ^ (prev >> 30)) + i) & 0xffffffff;
    }
    _mti = _n;
  }

  void _initByArray(List<int> key) {
    _initGenrand(19650218);
    var i = 1;
    var j = 0;
    for (var k = math.max(_n, key.length); k > 0; k--) {
      final prev = _mt[i - 1];
      _mt[i] =
          ((_mt[i] ^ _mul32(prev ^ (prev >> 30), 1664525)) + key[j] + j) &
          0xffffffff;
      i++;
      j++;
      if (i >= _n) {
        _mt[0] = _mt[_n - 1];
        i = 1;
      }
      if (j >= key.length) j = 0;
    }
    for (var k = _n - 1; k > 0; k--) {
      final prev = _mt[i - 1];
      _mt[i] =
          ((_mt[i] ^ _mul32(prev ^ (prev >> 30), 1566083941)) - i) & 0xffffffff;
      i++;
      if (i >= _n) {
        _mt[0] = _mt[_n - 1];
        i = 1;
      }
    }
    _mt[0] = 0x80000000;
  }

  int _nextUint32() {
    if (_mti >= _n) {
      for (var kk = 0; kk < _n; kk++) {
        final y = (_mt[kk] & 0x80000000) | (_mt[(kk + 1) % _n] & 0x7fffffff);
        _mt[kk] =
            _mt[(kk + _m) % _n] ^ (y >> 1) ^ ((y & 1) != 0 ? 0x9908b0df : 0);
      }
      _mti = 0;
    }
    var y = _mt[_mti++];
    y ^= y >> 11;
    y ^= (y << 7) & 0x9d2c5680;
    y ^= (y << 15) & 0xefc60000;
    y ^= y >> 18;
    return y & 0xffffffff;
  }

  /// Uniform in [0, 1) with 53-bit resolution.
  double random() {
    final a = _nextUint32() >> 5;
    final b = _nextUint32() >> 6;
    return (a * 67108864.0 + b) * (1.0 / 9007199254740992.0);
  }

  /// Normal draw (CPython's `random.gauss`, which caches a second value).
  double gauss(double mu, double sigma) {
    var z = _gaussNext;
    _gaussNext = null;
    if (z == null) {
      final x2pi = random() * _twoPi;
      final g2rad = math.sqrt(-2.0 * math.log(1.0 - random()));
      z = math.cos(x2pi) * g2rad;
      _gaussNext = math.sin(x2pi) * g2rad;
    }
    return mu + z * sigma;
  }
}
