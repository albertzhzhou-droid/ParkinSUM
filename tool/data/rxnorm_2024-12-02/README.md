# NLM RxNorm — release of 2 December 2024 (Current Prescribable Content)

Courtesy of the U.S. National Library of Medicine. Current Prescribable
Content is distributed without a UMLS license. Retrieved through the Hugging
Face dataset mirror `OnDeviceMedNotes/nih-rxnorm-dec-2-2024` (`RXNCONSO.RRF`),
because the environment's network policy blocks `rxnav.nlm.nih.gov` and
`download.nlm.nih.gov`.

`RXNCONSO_parkinson_reference_subset.RRF` holds complete concept blocks
(every atom NLM lists for the RxCUI), copied byte-for-byte from 60 KB windows
of the source file by a script. No line was typed by hand; a block is kept only
when it lies wholly inside a window. Selected concepts:

- Ingredients (IN, with FDA UNII atoms): acetaminophen 161, amantadine 620,
  apomorphine 1043, aspirin 1191, benztropine 1424, bromocriptine 1760,
  carbidopa 2019, levodopa 6375, metformin 6809, midodrine 6963,
  selegiline 9639, trihexyphenidyl 10811, ferrous sulfate 24947,
  entacapone 60307, ropinirole 72302, tolcapone 72937, rasagiline 134748,
  rivastigmine 183379, polyethylene glycol 3350 221147.
- Clinical drugs (SCD, with linked NDC products): bromocriptine 2.5 mg
  tablet 197411, bromocriptine 5 mg capsule 197412, carbidopa/levodopa
  10/100, 25/100 and 25/250 mg tablets (197443, 197444, 197445) and 25/100
  and 50/200 mg extended-release tablets (308988, 308989).

Identity data only; nothing here is a dose, schedule or recommendation.
`lib/core/constants/rxnorm_reference_table.dart` is generated from this file
(`dart run tool/generate_rxnorm_reference_table.dart`) and checked by
`test/rxnorm_reference_table_test.dart`.
