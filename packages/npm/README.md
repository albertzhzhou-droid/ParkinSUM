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

Version **0.2.0** accompanies [GitHub Release v0.2.0](https://github.com/albertzhzhou-droid/ParkinSUM/releases/tag/v0.2.0).
At publication on 2026-09-29, this is the **Latest** release and the package
version selected by the npm `latest` tag. App version remains `0.2.0+2`.

## Install

This package lives on the GitHub Packages npm registry. Add an `.npmrc` that
points the scope at GitHub Packages and authenticate with a token that has the
`read:packages` scope:

```ini
@albertzhzhou-droid:registry=https://npm.pkg.github.com
//npm.pkg.github.com/:_authToken=${GITHUB_TOKEN}
```

```sh
npm install @albertzhzhou-droid/parkinsum-companion@latest
```

## Usage

```js
const release = require('@albertzhzhou-droid/parkinsum-companion');

console.log(release.release);     // "v0.2.0"
console.log(release.appVersion);  // "0.2.0+2"
console.log(release.safetyBoundary.isMedicalDevice); // false
```

## Links

- [Repository](https://github.com/albertzhzhou-droid/ParkinSUM)
- [Release notes](https://github.com/albertzhzhou-droid/ParkinSUM/blob/v0.2.0/docs/release/v0.2.0-notes.md)
- [Changelog](https://github.com/albertzhzhou-droid/ParkinSUM/blob/v0.2.0/CHANGELOG.md)
- [Capability matrix](https://github.com/albertzhzhou-droid/ParkinSUM/blob/v0.2.0/docs/CAPABILITY_MATRIX.md)
- [Apache-2.0 license](LICENSE)
