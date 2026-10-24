"""Published-experiment scenarios for the reference physiology model.

Each builder reconstructs a study setting from what its abstract reports. Where
the abstract is silent (meal composition, schedules, body weight) the builder
states the assumption in its docstring; assumptions are part of the evidence
boundary of every check that uses them.
"""

from __future__ import annotations

from typing import List

from model import Component, Dose, Infusion, Meal, Scenario

BODY_WEIGHT_KG = 70.0  # assumption where a study reports doses per kg


def tougas_meal() -> Scenario:
    """Tougas 2000 standardized low-fat egg-substitute meal (solid label).

    Assumes the consensus composition of ~255 kcal with ~20 g protein plus
    120 mL water; retention is of the labelled solid.
    """
    return Scenario(
        meals=[Meal(0.0, [
            Component("egg-substitute meal", "solid", kcal=255.0, protein_g=20.0),
            Component("water", "water", water_ml=120.0),
        ])],
        t_end_min=300.0,
    )


def glucose_drink() -> Scenario:
    """Brener 1983: 300 mL of 0.25 g/mL glucose (75 g, 300 kcal)."""
    return Scenario(
        meals=[Meal(0.0, [Component("glucose 0.25 g/mL", "liquid", kcal=300.0, water_ml=300.0,
                                    carbohydrate_g=75.0)])],
        t_end_min=240.0,
    )


def nutt_meal_scenarios(dose_mg: float = 100.0):
    """Nutt 1984 meal effect: the same oral dose fasting versus with a meal.

    The abstract does not report the meal. Assumed: a ~500 kcal mixed
    breakfast (400 kcal solid with 16 g protein, 100 kcal juice, 200 mL water)
    eaten at the time of the dose.
    """
    fasting = Scenario(doses=[Dose(0.0, dose_mg)], t_end_min=360.0)
    fed = Scenario(
        meals=[Meal(0.0, [
            Component("mixed breakfast", "solid", kcal=400.0, protein_g=16.0),
            Component("juice", "liquid", kcal=100.0, protein_g=1.0, water_ml=200.0),
            Component("water", "water", water_ml=200.0),
        ])],
        doses=[Dose(0.0, dose_mg)],
        t_end_min=360.0,
    )
    return fasting, fed


def nutt_infusion_amino_acid_load(amino_acid: str = "phe"):
    """Nutt 1984 infusion arm: steady intravenous levodopa, then an oral load
    of 100 mg/kg of one amino acid (phenylalanine, leucine or isoleucine had
    an effect; glycine and lysine did not). Load given at 240 min.

    Infusion rate assumed to hold plasma levodopa near 1.5 mg/L.
    """
    grams = 0.100 * BODY_WEIGHT_KG
    aa = {} if amino_acid in ("gly", "lys") else {amino_acid: grams}
    return Scenario(
        meals=[Meal(240.0, [Component(f"oral {amino_acid} load", "liquid",
                                      kcal=4.0 * grams, amino_acids_g=aa, water_ml=250.0)])],
        infusions=[Infusion(0.0, 600.0, 0.75)],
        t_end_min=600.0,
        dt_min=0.5,
    )


def carter_day(diet: str) -> Scenario:
    """Carter 1989 diets over two days; the check samples day two hourly.

    Assumed: 70 kg body weight; meals at 08:00, 12:00 and 17:30 with 450, 650
    and 700 kcal on every diet; levodopa 100 mg at 07:00, 10:00, 13:00, 16:00
    and 19:00 on every diet. Diets (protein g per meal):
      high     1.6 g/kg/day evenly  -> 37.3 / 37.3 / 37.3
      even     0.8 g/kg/day evenly  -> 18.7 / 18.7 / 18.7
      evening  0.8 g/kg/day, day meals near protein-free -> 3 / 3 / 50
    Assumed: each diet was kept long enough for its daily protein to act as
    the habitual intake that sets fasting levels. Carbohydrate is the default
    share of non-protein energy.
    """
    per_day = {"high": (37.33, 37.33, 37.33), "even": (18.67, 18.67, 18.67),
               "evening": (3.0, 3.0, 50.0)}[diet]
    meals: List[Meal] = []
    doses: List[Dose] = []
    for day in range(2):
        base = day * 1440.0
        for (clock, kcal), protein in zip(((480.0, 450.0), (720.0, 650.0), (1050.0, 700.0)), per_day):
            meals.append(Meal(base + clock, [
                Component("meal", "solid", kcal=kcal * 0.85, protein_g=protein * 0.85),
                Component("drink", "liquid", kcal=kcal * 0.15, protein_g=protein * 0.15, water_ml=250.0),
            ]))
        for clock in (420.0, 600.0, 780.0, 960.0, 1140.0):
            doses.append(Dose(base + clock, 100.0))
    return Scenario(meals=meals, doses=doses, t_end_min=2880.0, dt_min=0.5, record_every_min=5.0,
                    habitual_protein_g_per_kg_day=CARTER_HABITUAL_PROTEIN[diet])


CARTER_HABITUAL_PROTEIN = {"high": 1.6, "even": 0.8, "evening": 0.8}


CARTER_SAMPLE_TIMES = [1440.0 + h * 60.0 for h in range(8, 22)]  # 08:00-21:00, day two


def boirie_proteins():
    """Boirie 1997: one meal of whey or casein with identical leucine intake
    (380 umol/kg). Assumed ~30 g protein, 120 kcal, in 300 mL, no
    carbohydrate other than the default share. Whey stays liquid; casein clots
    in gastric acid, so it takes the solid path. Each carries its protein
    type's digestion rate.
    """
    leucine_g = 380e-6 * BODY_WEIGHT_KG * 131.17
    profile = {"leu": leucine_g, "ile": 1.6, "val": 1.8, "phe": 1.0, "tyr": 1.0,
               "trp": 0.5, "met": 0.7, "his": 0.6}
    whey = Scenario(meals=[Meal(0.0, [Component("whey", "liquid", kcal=120.0, protein_g=30.0,
                                                amino_acids_g=profile, water_ml=300.0,
                                                protein_type="whey")])],
                    t_end_min=420.0)
    casein = Scenario(meals=[Meal(0.0, [Component("casein", "coagulating", kcal=120.0, protein_g=30.0,
                                                  amino_acids_g=profile, water_ml=300.0,
                                                  protein_type="casein")])],
                      t_end_min=420.0)
    return whey, casein


def shaham_glucose() -> Scenario:
    """Shaham 2008 oral glucose challenge: 75 g glucose in 296 mL after an
    overnight fast, plasma sampled to 120 min. No protein."""
    return Scenario(
        meals=[Meal(0.0, [Component("glucose 75 g", "liquid", kcal=300.0, carbohydrate_g=75.0,
                                    water_ml=296.0)])],
        t_end_min=240.0,
    )


def wurtman_breakfasts():
    """Wurtman 2003: carbohydrate-rich (69.9 g carbohydrate, 5.2 g protein)
    and protein-rich (15.4 g carbohydrate, 46.8 g protein) breakfasts after an
    overnight fast; sampled at 40, 80, 120 and 240 min.

    Assumed: both are solid meals; fat supplies 10 g in the carbohydrate meal
    and 15 g in the protein meal (not reported in the abstract).
    """
    def meal(carb, protein, fat):
        kcal = 4.0 * carb + 4.0 * protein + 9.0 * fat
        return Scenario(meals=[Meal(0.0, [Component("breakfast", "solid", kcal=kcal, protein_g=protein,
                                                    carbohydrate_g=carb),
                                          Component("water", "water", water_ml=250.0)])],
                        t_end_min=300.0)
    return meal(69.9, 5.2, 10.0), meal(15.4, 46.8, 15.0)


WURTMAN_SAMPLE_TIMES = (40.0, 80.0, 120.0, 240.0)


def tang_drinks():
    """Tang 2009: drinks with 10 g essential amino acids as whey hydrolysate,
    soy isolate or micellar casein. Assumed: 22 g protein (whey, casein) or
    26 g (soy, lower essential-amino-acid share), ~4 kcal/g, 300 mL; leucine
    10.8 / 8.0 / 9.2% of protein for whey / soy / casein."""
    def drink(kind, protein, leu_share, form):
        aa = {"leu": protein * leu_share, "ile": protein * 0.05, "val": protein * 0.055, "phe": protein * 0.04,
              "tyr": protein * 0.035, "trp": protein * 0.013, "met": protein * 0.02, "his": protein * 0.022}
        return Scenario(meals=[Meal(0.0, [Component(kind, form, kcal=4.0 * protein, protein_g=protein,
                                                    amino_acids_g=aa, water_ml=300.0, carbohydrate_g=0.0,
                                                    protein_type=kind)])], t_end_min=300.0)
    return drink("whey", 22.0, 0.108, "liquid"), drink("soy", 26.0, 0.080, "liquid"), \
        drink("casein", 22.0, 0.092, "coagulating")


def blackburn_glucose() -> Scenario:
    """Blackburn 1984 control drink: 250 mL with 200 g/L glucose (50 g,
    200 kcal), radio-labelled, after an overnight fast."""
    return Scenario(meals=[Meal(0.0, [Component("glucose 200 g/L", "liquid", kcal=200.0, carbohydrate_g=50.0,
                                                water_ml=250.0)])], t_end_min=300.0)


def moore_meal(kcal: float) -> Scenario:
    """Moore 1984: 300 g lettuce-and-water meal with salad oil to 68, 208
    or 633 kcal. Assumed: lettuce 150 g (solid, its own ~20 kcal), the oil's
    energy in a liquid fat layer, 150 mL water; no protein."""
    lettuce = 20.0
    return Scenario(meals=[Meal(0.0, [Component("lettuce", "solid", kcal=lettuce, protein_g=1.5, fat_g=0.2),
                                      Component("salad oil", "liquid", kcal=kcal - lettuce,
                                                fat_g=(kcal - lettuce) / 9.0, carbohydrate_g=0.0),
                                      Component("water", "water", water_ml=150.0)])], t_end_min=300.0)


def bos_mixed_meals():
    """Bos 2003: a mixed single meal of 46 kJ/kg (~770 kcal at 70 kg) with
    15N-soy or 15N-milk protein. Assumed: 30 g test protein mixed into the
    meal (soy as part of the solid; milk protein as 80% casein curd and 20%
    whey in the solid), plus ~650 kcal of other solid food with 5 g protein.
    """
    rest = Component("rest of meal", "solid", kcal=650.0, protein_g=5.0)
    soy = Scenario(meals=[Meal(0.0, [Component("soy protein", "solid", kcal=120.0, protein_g=30.0,
                                               protein_type="soy", carbohydrate_g=0.0), rest])], t_end_min=480.0)
    milk = Scenario(meals=[Meal(0.0, [Component("casein", "coagulating", kcal=96.0, protein_g=24.0,
                                                protein_type="casein", carbohydrate_g=0.0),
                                      Component("whey", "solid", kcal=24.0, protein_g=6.0, protein_type="whey",
                                                carbohydrate_g=0.0), rest])], t_end_min=480.0)
    return soy, milk
