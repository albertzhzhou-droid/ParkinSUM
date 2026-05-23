class UserProfileRuntimeContext {
  final String patientId;
  final String registrationRegion;
  final String displayLocale;
  final List<String> contentJurisdictionOverride;
  final String? dietProfileRegion;
  final String timezone;

  const UserProfileRuntimeContext({
    required this.patientId,
    required this.registrationRegion,
    required this.displayLocale,
    required this.contentJurisdictionOverride,
    required this.dietProfileRegion,
    required this.timezone,
  });

  Map<String, dynamic> toJson() => {
        'patient_id': patientId,
        'registration_region': registrationRegion,
        'display_locale': displayLocale,
        'content_jurisdiction_override': contentJurisdictionOverride,
        'diet_profile_region': dietProfileRegion,
        'timezone': timezone,
      };
}

class DrugRuntimeContext {
  final String id;
  final String genericName;
  final String? brandName;
  final List<String> activeIngredients;
  final List<String> substanceTags;
  final String formulation;
  final String dosageForm;
  final String route;
  final String releaseType;
  final double? dailyDoseMg;
  final String? jurisdiction;

  const DrugRuntimeContext({
    required this.id,
    required this.genericName,
    required this.brandName,
    required this.activeIngredients,
    required this.substanceTags,
    required this.formulation,
    required this.dosageForm,
    required this.route,
    required this.releaseType,
    required this.dailyDoseMg,
    required this.jurisdiction,
  });
}

class MealRuntimeContext {
  final String id;
  final double totalProteinG;
  final double tyramineMgEstimate;
  final bool highFatHighCalorie;
  final List<String> itemIds;

  const MealRuntimeContext({
    required this.id,
    required this.totalProteinG,
    required this.tyramineMgEstimate,
    required this.highFatHighCalorie,
    required this.itemIds,
  });
}

class CoeventRuntimeContext {
  final List<String> substanceTags;
  final Map<String, dynamic> supplements;
  final String? thickenerType;

  const CoeventRuntimeContext({
    required this.substanceTags,
    required this.supplements,
    required this.thickenerType,
  });
}

class EnteralFeedRuntimeContext {
  final String mode;
  final String? formula;
  final double? proteinGPerDay;

  const EnteralFeedRuntimeContext({
    required this.mode,
    required this.formula,
    required this.proteinGPerDay,
  });
}

class TimestampRuntimeContext {
  final DateTime? drugTime;
  final DateTime? mealTime;
  final DateTime? coeventTime;

  const TimestampRuntimeContext({
    required this.drugTime,
    required this.mealTime,
    required this.coeventTime,
  });
}

class UnifiedRuntimeContext {
  final UserProfileRuntimeContext userProfile;
  final DrugRuntimeContext drug;
  final MealRuntimeContext? meal;
  final CoeventRuntimeContext? coevent;
  final EnteralFeedRuntimeContext? enteralFeed;
  final TimestampRuntimeContext timestamps;

  const UnifiedRuntimeContext({
    required this.userProfile,
    required this.drug,
    required this.meal,
    required this.coevent,
    required this.enteralFeed,
    required this.timestamps,
  });

  Map<String, dynamic> toJson() => {
        'user_profile': userProfile.toJson(),
        'drug': {
          'id': drug.id,
          'generic_name': drug.genericName,
          'brand_name': drug.brandName,
          'active_ingredients': drug.activeIngredients,
          'substance_tags': drug.substanceTags,
          'formulation': drug.formulation,
          'dosage_form': drug.dosageForm,
          'route': drug.route,
          'release_type': drug.releaseType,
          'daily_dose_mg': drug.dailyDoseMg,
          'jurisdiction': drug.jurisdiction,
        },
        'meal': meal == null
            ? null
            : {
                'id': meal!.id,
                'protein_g': meal!.totalProteinG,
                'tyramine_mg_est': meal!.tyramineMgEstimate,
                'high_fat_high_calorie': meal!.highFatHighCalorie,
                'item_ids': meal!.itemIds,
              },
        'coevent': coevent == null
            ? null
            : {
                'substance_tags': coevent!.substanceTags,
                'supplements': coevent!.supplements,
                'thickener_type': coevent!.thickenerType,
              },
        'enteral_feed': enteralFeed == null
            ? null
            : {
                'mode': enteralFeed!.mode,
                'formula': enteralFeed!.formula,
                'protein_g_per_day': enteralFeed!.proteinGPerDay,
              },
        'timestamps': {
          'drug_time': timestamps.drugTime?.toIso8601String(),
          'meal_time': timestamps.mealTime?.toIso8601String(),
          'coevent_time': timestamps.coeventTime?.toIso8601String(),
        },
      };
}
