class FirebaseUserDataPaths {
  final String uid;

  const FirebaseUserDataPaths(this.uid);

  String get profile => 'users/$uid/profile/current';
  String meal(String mealId) => 'users/$uid/meals/$mealId';
  String intake(String intakeId) => 'users/$uid/intakes/$intakeId';
  String activeDrug(String drugId) => 'users/$uid/active_drugs/$drugId';
  String appMeta(String key) => 'users/$uid/app_meta/$key';
  String clinicalAudit(String auditId) => 'users/$uid/clinical_audits/$auditId';
  String recordHistory(String historyId) =>
      'users/$uid/record_history/$historyId';
  String cdssRow(String table, String rowId) =>
      'users/$uid/cdss_tables/$table/rows/$rowId';

  String collection(String table) => 'users/$uid/$table';
  String cdssRowsCollection(String table) =>
      'users/$uid/cdss_tables/$table/rows';
}
