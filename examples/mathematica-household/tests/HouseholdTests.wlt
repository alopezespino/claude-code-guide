(* HouseholdTests.wlt: checks for src/Household.wl.
   Run from the example folder:  wolframscript -file tests/run.wls *)

ratios = {0.5, 0.8, 1., 1.25, 2.};

VerificationTest[
  AllTrue[Flatten[{#h1, #h2} & /@ Join[
      sweepRelativeWage[ratios], sweepRelativeWage[ratios, "Kappa" -> 2]]],
    0 <= # <= 1 &],
  True,
  TestID -> "time-constraint: market hours lie in [0, 1]"
]

VerificationTest[
  Max @ Abs[(#c - (1. #h1 + #Ratio #h2)) & /@
    sweepRelativeWage[ratios, "Kappa" -> 2]] < 10^-12,
  True,
  TestID -> "budget: c equals w1 h1 + w2 h2"
]

VerificationTest[
  (* The closed form is a stationary point of the unbiased utility. *)
  Module[{h = unbiasedSolution[1., 1.25], x1, x2},
    Max @ Abs[
      D[Log[x1 + 1.25 x2] + 0.5 Log[1 - x1] + 0.5 Log[1 - x2],
        {{x1, x2}}] /. {x1 -> h[[1]], x2 -> h[[2]]}] < 10^-10],
  True,
  TestID -> "closed form: first-order conditions hold"
]

VerificationTest[
  (* A global numerical search finds the same optimum as the closed form. *)
  Module[{x1, x2, sol},
    sol = Last @ NMaximize[{householdUtility[x1, x2, 1., 1.25],
        0 <= x1 <= 0.999, 0 <= x2 <= 0.999}, {x1, x2}];
    Norm[({x1, x2} /. sol) - unbiasedSolution[1., 1.25]] < 10^-5],
  True,
  TestID -> "closed form: agrees with NMaximize"
]

VerificationTest[
  (* With a high enough wife's wage the husband specializes at home. *)
  solveHousehold[1., 5.]["h1"],
  0.,
  TestID -> "corner: husband at h1 = 0 when w2/w1 = 5"
]

VerificationTest[
  Module[{s = sweepRelativeWage[ratios]},
    {Min[Differences[#h2 & /@ s]] > 0, Max[Differences[#h1 & /@ s]] < 0}],
  {True, True},
  TestID -> "comparative statics: h2 rises and h1 falls in w2/w1"
]

VerificationTest[
  (* The bias binds only when the wife would earn more than half. *)
  Module[{a = solveHousehold[1., 0.8], b = solveHousehold[1., 0.8, "Kappa" -> 2],
      c = solveHousehold[1., 1.5], d = solveHousehold[1., 1.5, "Kappa" -> 2]},
    {Abs[a["h2"] - b["h2"]] < 10^-6, d["WifeShare"] < c["WifeShare"],
      d["h1"] > c["h1"]}],
  {True, True, True},
  TestID -> "bias: no effect below equal earnings, lowers the wife's share above"
]
