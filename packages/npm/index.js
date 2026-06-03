'use strict';

// Release-metadata package for the ParkinSUM Companion educational prototype
// showcase. This package ships release metadata only; it is NOT the application
// runtime and contains no medical logic, advice, or patient data.
//
// Educational/research prototype. Not a clinical product. Synthetic/sample data
// only. Not a medical device; not clinically-validated; provides no medical
// advice, diagnosis, dosing, timing, or dietary instructions.

const manifest = require('./manifest.json');

module.exports = Object.freeze({
  ...manifest,
});
