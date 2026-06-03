# @albertzhzhou-droid/parkinsum-companion

Release-metadata package for the **ParkinSUM Companion** educational prototype
showcase, published to **GitHub Packages** (npm registry).

> **Educational/research prototype. Not a clinical product.** Synthetic/sample
> data only. This is **not a medical device**, is **not clinically-validated**,
> and provides **no** medical advice, diagnosis, dosing, timing, or dietary
> instructions. It must not be used for patient care or emergency support.

This package ships **release metadata only** (version, links, and the project's
safety boundary). It is not the application runtime and contains no medical
logic or patient data. It exists so the public release is discoverable through
GitHub Packages alongside the GitHub Release.

## Install

This package lives on the GitHub Packages npm registry. Add an `.npmrc` that
points the scope at GitHub Packages and authenticate with a token that has the
`read:packages` scope:

```ini
@albertzhzhou-droid:registry=https://npm.pkg.github.com
//npm.pkg.github.com/:_authToken=${GITHUB_TOKEN}
```

```sh
npm install @albertzhzhou-droid/parkinsum-companion
```

## Usage

```js
const release = require('@albertzhzhou-droid/parkinsum-companion');

console.log(release.release);     // "v0.2.0-beta"
console.log(release.appVersion);  // "0.2.0+2"
console.log(release.safetyBoundary.isMedicalDevice); // false
```

## Links

- Repository: https://github.com/albertzhzhou-droid/ParkinSUM
- Release notes: `docs/release/v0.2.0-beta-notes.md`
- Changelog: `CHANGELOG.md`
- Capability matrix: `docs/CAPABILITY_MATRIX.md`
