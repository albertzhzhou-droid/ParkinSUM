# Descriptive blood-pressure sequence in the timeline

The timeline chart is a view of user-entered `PersonalObservation` records. It
does not classify readings, show guideline thresholds, calculate averages,
interpolate elapsed time, link readings to meals or medication, or recommend a
change in care.

## Projection contract

- The view keeps the 12 most recent blood-pressure observations, ordered by
  occurrence time from older to newer. Ties use recording time and then record
  ID. Earlier observations remain visible in the main timeline.
- Horizontal positions show event order, not time intervals. The vertical
  axis is automatically scaled to the values in the displayed window and
  labelled in mmHg; it contains no normal or alert bands.
- Only `recorded` observations contribute systolic and diastolic points.
  `unknown` and `notMeasured` records remain counted and break both lines;
  missing values are never drawn as zero or interpolated.
- The expandable details preserve occurrence and recording instants as
  separate values, the original timezone label, source, posture, and the
  recorded/unknown/not-measured status. Free-text notes are not added to the
  chart projection.
- The display is account-local and read-only. It adds no persistence or
  network path.

The [American Heart Association's home-monitoring guidance](https://www.heart.org/en/health-topics/high-blood-pressure/understanding-blood-pressure-readings/monitoring-your-blood-pressure-at-home)
recommends recording multiple readings and explains that records over time
provide a fuller picture than a single measurement. ParkinSUM's chart only
visualizes observations already entered by the user; it does not implement a
measurement protocol or determine what the readings mean.

`test/blood_pressure_trend_projection_test.dart` checks ordering, the bounded
window, and missing-value preservation. The timeline widget test checks the
chart's accessible summary, displayed counts, expanded details, and the
absence of clinical thresholds.
