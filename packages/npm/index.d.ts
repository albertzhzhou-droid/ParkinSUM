export interface SafetyBoundary {
  isMedicalDevice: boolean;
  isClinicallyValidated: boolean;
  providesMedicalAdvice: boolean;
  dataPolicy: string;
  summary: string;
}

export interface ParkinSumReleaseManifest {
  name: string;
  release: string;
  appPackage: string;
  appVersion: string;
  releaseType: string;
  prerelease: boolean;
  repository: string;
  releaseNotes: string;
  changelog: string;
  capabilityMatrix: string;
  safetyBoundary: SafetyBoundary;
}

declare const manifest: Readonly<ParkinSumReleaseManifest>;
export = manifest;
