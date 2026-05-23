import '../models/drug_definition.dart';

/// MedicationRepository：
/// 提供内置药物目录（示例）
/// - 你后续可以将其替换为联网目录或外部 JSON，但保持 API 不变
class MedicationRepository {
  List<DrugDefinition> _drugs;

  MedicationRepository._(this._drugs);

  factory MedicationRepository.createDefault() {
    // 这里保留的是当前 App 可直接消费的高相关 PD 药物目录。
    // 未完成：
    // 1. 还不是完整 DailyMed / Drugs@FDA / EMA / DPD / PMDA ETL 结果；
    // 2. 一些 sourceProductCode 仍未回填稳定外部主键，因此显式标注 UNSPECIFIED_*；
    // 3. notes / interactionSummary 是面向产品的摘要，不替代正式标签全文。
    final drugs = <DrugDefinition>[
      DrugDefinition(
        id: 'drug_levodopa_carbidopa',
        genericName: 'Levodopa/Carbidopa',
        brandNames: const ['Sinemet'],
        aliases: const ['carbidopa and levodopa', 'LD/CD'],
        tags: const [DrugTag.levodopaLike],
        notes:
            'Core oral levodopa combination for Parkinson disease. High-protein meals may delay or reduce response, and iron salts may reduce bioavailability.',
        interactionSummary:
            'Protein timing and iron chelation are the main food-related concerns.',
        sourceSystem: 'DAILYMED',
        sourceProductCode: 'UNSPECIFIED_DAILYMED_SETID_CARBIDOPA_LEVODOPA',
        jurisdiction: 'US',
        route: 'oral',
        dosageForm: 'tablet',
        releaseType: 'immediate_release',
      ),
      DrugDefinition(
        id: 'drug_entacapone',
        genericName: 'Entacapone',
        brandNames: const ['Comtan'],
        tags: const [DrugTag.comtInhibitor],
        notes:
            'Peripheral COMT inhibitor used with levodopa to reduce wearing-off.',
        interactionSummary:
            'Usually evaluated together with levodopa timing rather than as a standalone food conflict.',
        sourceSystem: 'DAILYMED',
        sourceProductCode: 'UNSPECIFIED_DAILYMED_SETID_ENTACAPONE',
        jurisdiction: 'US',
        route: 'oral',
        dosageForm: 'tablet',
        releaseType: 'immediate_release',
      ),
      DrugDefinition(
        id: 'drug_tolcapone',
        genericName: 'Tolcapone',
        brandNames: const ['Tasmar'],
        tags: const [DrugTag.comtInhibitor],
        notes:
            'COMT inhibitor with liver toxicity monitoring requirements; typically reserved for selected patients.',
        interactionSummary:
            'Food interaction is not the primary concern; monitoring and levodopa co-therapy context are more important.',
        sourceSystem: 'DAILYMED',
        sourceProductCode: 'UNSPECIFIED_DAILYMED_SETID_TOLCAPONE',
        jurisdiction: 'US',
        route: 'oral',
        dosageForm: 'tablet',
        releaseType: 'immediate_release',
      ),
      DrugDefinition(
        id: 'drug_opicapone',
        genericName: 'Opicapone',
        brandNames: const ['Ongentys'],
        tags: const [DrugTag.comtInhibitor],
        notes:
            'Once-daily COMT inhibitor used as adjunct to levodopa/carbidopa in patients with OFF episodes.',
        interactionSummary:
            'Usually interpreted in the levodopa timing context rather than as a direct food blocker.',
        sourceSystem: 'DAILYMED',
        sourceProductCode: 'a511a531-112e-43f8-a43f-5334b0efe979',
        jurisdiction: 'US',
        route: 'oral',
        dosageForm: 'capsule',
        releaseType: 'immediate_release',
      ),
      DrugDefinition(
        id: 'drug_selegiline',
        genericName: 'Selegiline',
        brandNames: const ['Eldepryl', 'Zelapar'],
        tags: const [DrugTag.maoi],
        notes:
            'MAO-B inhibitor used in Parkinson disease. Most patients do not need routine tyramine restriction at recommended doses, but very high tyramine exposure still matters.',
        interactionSummary:
            'Very high tyramine foods remain the main dietary caution, especially if dose or formulation changes.',
        sourceSystem: 'DAILYMED',
        sourceProductCode: 'UNSPECIFIED_DAILYMED_SETID_SELEGILINE',
        jurisdiction: 'US',
        route: 'oral',
        dosageForm: 'tablet_or_odt',
        releaseType: 'immediate_release',
      ),
      DrugDefinition(
        id: 'drug_rasagiline',
        genericName: 'Rasagiline',
        brandNames: const ['Azilect'],
        tags: const [DrugTag.maoi],
        notes:
            'Selective MAO-B inhibitor. At recommended doses, routine tyramine restriction is not generally required, but foods with very large tyramine loads should be avoided.',
        interactionSummary:
            'Use caution with foods containing very high tyramine loads around 150 mg or more.',
        sourceSystem: 'DAILYMED',
        sourceProductCode: '73efe275-acea-49c0-aa76-fdc4249c424e',
        jurisdiction: 'US',
        route: 'oral',
        dosageForm: 'tablet',
        releaseType: 'immediate_release',
      ),
      DrugDefinition(
        id: 'drug_safinamide',
        genericName: 'Safinamide',
        brandNames: const ['Xadago'],
        tags: const [DrugTag.maoi],
        notes:
            'Adjunct MAO-B inhibitor used with levodopa/carbidopa in patients experiencing OFF episodes.',
        interactionSummary:
            'Routine tyramine restriction is not usually required at recommended doses, but large tyramine loads are still relevant.',
        sourceSystem: 'DAILYMED',
        sourceProductCode: 'c4d65f28-983f-42b4-bb23-023ae0fe81b2',
        jurisdiction: 'US',
        route: 'oral',
        dosageForm: 'tablet',
        releaseType: 'immediate_release',
      ),
      DrugDefinition(
        id: 'drug_iron',
        genericName: 'Iron supplement',
        brandNames: const ['Ferrous sulfate'],
        tags: const [DrugTag.mineralSupplement],
        notes:
            'Supplemental iron is not a PD therapy, but it matters clinically because it may chelate with levodopa/carbidopa and reduce absorption.',
        interactionSummary:
            'Separate from levodopa-containing therapy when possible.',
        sourceSystem: 'DAILYMED',
        sourceProductCode: 'UNSPECIFIED_IRON_SUPPLEMENT',
        jurisdiction: 'US',
        route: 'oral',
        dosageForm: 'tablet_or_capsule',
        releaseType: 'immediate_release',
      ),
      DrugDefinition(
        id: 'drug_pramipexole',
        genericName: 'Pramipexole',
        brandNames: const ['Mirapex', 'Mirapex ER'],
        tags: const [DrugTag.dopamineAgonist],
        notes:
            'Dopamine agonist used as monotherapy or adjunctive therapy in Parkinson disease.',
        interactionSummary:
            'Food conflict is usually limited; sedation, impulse control and orthostatic effects are often more clinically relevant.',
        sourceSystem: 'DAILYMED',
        sourceProductCode: 'UNSPECIFIED_DAILYMED_SETID_PRAMIPEXOLE',
        jurisdiction: 'US',
        route: 'oral',
        dosageForm: 'tablet',
        releaseType: 'immediate_or_extended_release',
      ),
      DrugDefinition(
        id: 'drug_ropinirole',
        genericName: 'Ropinirole',
        brandNames: const ['Requip', 'Requip XL'],
        tags: const [DrugTag.dopamineAgonist],
        notes:
            'Dopamine agonist used in early and adjunctive Parkinson disease treatment.',
        interactionSummary:
            'No major food-triggered hard rule in the current engine; monitor tolerability and dose titration context.',
        sourceSystem: 'DAILYMED',
        sourceProductCode: 'UNSPECIFIED_DAILYMED_SETID_ROPINIROLE',
        jurisdiction: 'US',
        route: 'oral',
        dosageForm: 'tablet',
        releaseType: 'immediate_or_extended_release',
      ),
      DrugDefinition(
        id: 'drug_rotigotine',
        genericName: 'Rotigotine',
        brandNames: const ['Neupro'],
        tags: const [DrugTag.dopamineAgonist],
        notes:
            'Transdermal dopamine agonist useful when oral timing or gastric emptying is difficult.',
        interactionSummary:
            'Food timing is less central because therapy bypasses the gastrointestinal route.',
        sourceSystem: 'DAILYMED',
        sourceProductCode: 'UNSPECIFIED_DAILYMED_SETID_ROTIGOTINE',
        jurisdiction: 'US',
        route: 'transdermal',
        dosageForm: 'patch',
        releaseType: 'continuous',
      ),
      DrugDefinition(
        id: 'drug_apomorphine',
        genericName: 'Apomorphine',
        brandNames: const ['Kynmobi', 'Apokyn'],
        tags: const [DrugTag.dopamineAgonist],
        notes:
            'Rapid-acting dopamine agonist used for rescue or advanced OFF management depending on formulation.',
        interactionSummary:
            'Food interaction is not the main issue; route-specific tolerability and rescue context are more important.',
        sourceSystem: 'DAILYMED',
        sourceProductCode: 'UNSPECIFIED_DAILYMED_SETID_APOMORPHINE',
        jurisdiction: 'US',
        route: 'sublingual_or_subcutaneous',
        dosageForm: 'film_or_injection',
        releaseType: 'rescue',
      ),
      DrugDefinition(
        id: 'drug_amantadine',
        genericName: 'Amantadine',
        brandNames: const ['Gocovri', 'Osmolex ER'],
        tags: const [DrugTag.amantadineLike],
        notes:
            'Amantadine is used for Parkinson symptoms and dyskinesia depending on product and regimen.',
        interactionSummary:
            'Food-triggered rules are limited in the current engine; renal function and formulation context matter more.',
        sourceSystem: 'DAILYMED',
        sourceProductCode: 'UNSPECIFIED_DAILYMED_SETID_AMANTADINE',
        jurisdiction: 'US',
        route: 'oral',
        dosageForm: 'capsule_or_tablet',
        releaseType: 'immediate_or_extended_release',
      ),
      DrugDefinition(
        id: 'drug_istradefylline',
        genericName: 'Istradefylline',
        brandNames: const ['Nourianz'],
        tags: const [DrugTag.adenosineA2aAntagonist],
        notes:
            'Adenosine A2A receptor antagonist used as adjunct to levodopa/carbidopa for OFF episodes.',
        interactionSummary:
            'Current engine does not assign a specific food hard-stop; used mainly as adjunctive OFF management data.',
        sourceSystem: 'DAILYMED',
        sourceProductCode: 'UNSPECIFIED_DAILYMED_SETID_ISTRADEFYLLINE',
        jurisdiction: 'US',
        route: 'oral',
        dosageForm: 'tablet',
        releaseType: 'immediate_release',
      ),
      DrugDefinition(
        id: 'drug_pimavanserin',
        genericName: 'Pimavanserin',
        brandNames: const ['Nuplazid'],
        tags: const [],
        notes: '5-HT2A inverse agonist used for Parkinson disease psychosis.',
        interactionSummary:
            'Not a food-conflict-focused drug in the current engine; included because it is highly relevant to PD care.',
        sourceSystem: 'DAILYMED',
        sourceProductCode: 'UNSPECIFIED_DAILYMED_SETID_PIMAVANSERIN',
        jurisdiction: 'US',
        route: 'oral',
        dosageForm: 'capsule_or_tablet',
        releaseType: 'immediate_release',
      ),
      DrugDefinition(
        id: 'drug_rivastigmine',
        genericName: 'Rivastigmine',
        brandNames: const ['Exelon'],
        tags: const [DrugTag.cholinesteraseInhibitor],
        notes:
            'Cholinesterase inhibitor used for Parkinson disease dementia. Oral formulations are commonly taken with food for tolerability; patch formulations bypass the gut.',
        interactionSummary:
            'Meal timing may matter for oral tolerability, while patch therapy changes the gastrointestinal context.',
        sourceSystem: 'DAILYMED',
        sourceProductCode: 'UNSPECIFIED_DAILYMED_SETID_RIVASTIGMINE',
        jurisdiction: 'US',
        route: 'oral_or_transdermal',
        dosageForm: 'capsule_or_patch',
        releaseType: 'immediate_or_continuous',
      ),
      DrugDefinition(
        id: 'drug_droxidopa',
        genericName: 'Droxidopa',
        brandNames: const ['Northera'],
        tags: const [DrugTag.pressorAgent],
        notes:
            'Norepinephrine precursor used for neurogenic orthostatic hypotension in PD and related disorders.',
        interactionSummary:
            'Same-fed-state consistency can matter clinically; timing relative to meals should be kept consistent.',
        sourceSystem: 'DAILYMED',
        sourceProductCode: 'UNSPECIFIED_DAILYMED_SETID_DROXIDOPA',
        jurisdiction: 'US',
        route: 'oral',
        dosageForm: 'capsule',
        releaseType: 'immediate_release',
      ),
      DrugDefinition(
        id: 'drug_midodrine',
        genericName: 'Midodrine',
        brandNames: const ['ProAmatine'],
        tags: const [DrugTag.pressorAgent],
        notes: 'Alpha-1 agonist used for symptomatic orthostatic hypotension.',
        interactionSummary:
            'Current engine does not use a direct food rule; daytime scheduling and supine hypertension context are more important.',
        sourceSystem: 'DAILYMED',
        sourceProductCode: 'UNSPECIFIED_DAILYMED_SETID_MIDODRINE',
        jurisdiction: 'US',
        route: 'oral',
        dosageForm: 'tablet',
        releaseType: 'immediate_release',
      ),
      DrugDefinition(
        id: 'drug_peg_3350',
        genericName: 'PEG 3350',
        brandNames: const ['MiraLAX'],
        tags: const [DrugTag.laxative],
        notes:
            'Osmotic laxative often used in PD-associated constipation management.',
        interactionSummary:
            'Current hard rule focuses on incompatibility with starch-based thickeners in the swallowing context.',
        sourceSystem: 'DAILYMED',
        sourceProductCode: 'UNSPECIFIED_DAILYMED_SETID_PEG3350',
        jurisdiction: 'US',
        route: 'oral',
        dosageForm: 'powder_for_solution',
        releaseType: 'immediate_release',
      ),
      DrugDefinition(
        id: 'drug_levodopa_entacapone',
        genericName: 'Carbidopa/Levodopa/Entacapone',
        brandNames: const ['Stalevo'],
        aliases: const ['levodopa entacapone combination'],
        tags: const [DrugTag.levodopaLike, DrugTag.comtInhibitor],
        notes:
            'Fixed-dose combination that inherits the core levodopa food-timing concerns while also carrying COMT adjunct context.',
        interactionSummary:
            'Use the same protein-timing and iron-separation caution used for levodopa-containing therapy.',
        sourceSystem: 'DAILYMED',
        sourceProductCode: 'UNSPECIFIED_DAILYMED_SETID_STALEVO',
        jurisdiction: 'US',
        route: 'oral',
        dosageForm: 'tablet',
        releaseType: 'immediate_release',
      ),
      DrugDefinition(
        id: 'drug_levodopa_benserazide',
        genericName: 'Levodopa/Benserazide',
        brandNames: const ['Madopar', 'Prolopa'],
        aliases: const ['benserazide levodopa'],
        tags: const [DrugTag.levodopaLike],
        notes:
            'Levodopa combination widely used outside the U.S.; kept in the catalog because it is important for cross-jurisdiction PD care.',
        interactionSummary:
            'Apply the same high-protein and iron-separation caution used with other levodopa-containing products.',
        sourceSystem: 'HEALTH_CANADA_DPD',
        sourceProductCode: 'UNSPECIFIED_DIN_LEVODOPA_BENSERAZIDE',
        jurisdiction: 'CA',
        route: 'oral',
        dosageForm: 'capsule_or_tablet',
        releaseType: 'immediate_release',
      ),
    ];

    return MedicationRepository._(drugs);
  }

  List<DrugDefinition> get allDrugs => List.unmodifiable(_drugs);

  /// 和 FoodRepository 一样，允许用本地数据库里更完整的目录替换内置 seed。
  void replaceAll(List<DrugDefinition> drugs) {
    if (drugs.isEmpty) return;
    _drugs = List<DrugDefinition>.from(drugs);
  }

  DrugDefinition? getById(String id) {
    try {
      return _drugs.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }
}
