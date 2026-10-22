(* ::Package:: *)

(* Household.wl: a couple's time-allocation problem (teaching version).

   Two spouses, a husband (spouse 1, wage w1) and a wife (spouse 2, wage w2),
   each have one unit of time. Spouse i works hi hours in the market and
   spends 1 - hi on home production.

     consumption        c = w1 h1 + w2 h2
     wife's share       s = w2 h2 / c
     household utility  U = Log[c] + gamma theta Log[1 - h1]
                              + gamma (1 - theta) Log[1 - h2]
                              - kappa Max[0, s - 1/2]^2

   gamma  weight on the home good relative to consumption
   theta  husband's weight in home production (1/2 = symmetric)
   kappa  gender-role bias: a utility cost that is zero while the wife earns
          at most half of market income and grows with her excess share

   With kappa = 0 the problem has a closed form (unbiasedSolution). With
   kappa > 0 solveHousehold maximizes U numerically, starting from that
   closed form. *)

BeginPackage["Household`"];

householdUtility::usage =
  "householdUtility[h1, h2, w1, w2, opts] is the couple's utility when the \
husband works h1 and the wife works h2 market hours. Options: \"Gamma\", \
\"Theta\", \"Kappa\".";

unbiasedSolution::usage =
  "unbiasedSolution[w1, w2, opts] returns the closed-form optimum {h1, h2} \
when \"Kappa\" is 0, including the corner where one spouse works full time \
in the market.";

solveHousehold::usage =
  "solveHousehold[w1, w2, opts] maximizes householdUtility and returns an \
Association with keys \"h1\", \"h2\", \"Home1\", \"Home2\", \"c\", \
\"WifeShare\" and \"Utility\".";

sweepRelativeWage::usage =
  "sweepRelativeWage[ratios, opts] solves the problem for w1 = 1 and \
w2 = each ratio, returning a list of Associations with an added \
\"Ratio\" key.";

$HouseholdDefaults::usage =
  "$HouseholdDefaults holds the default parameter values.";

Begin["`Private`"];

$HouseholdDefaults = {"Gamma" -> 1., "Theta" -> 0.5, "Kappa" -> 0.};

Options[householdUtility] = $HouseholdDefaults;
Options[unbiasedSolution] = $HouseholdDefaults;
Options[solveHousehold] = $HouseholdDefaults;
Options[sweepRelativeWage] = $HouseholdDefaults;

(* Parameters are read through OptionValue so every function shares the same
   names and defaults. *)
par[f_, opts_, name_] := N @ OptionValue[f, opts, name];

householdUtility[h1_?NumericQ, h2_?NumericQ, w1_?NumericQ, w2_?NumericQ,
    opts : OptionsPattern[]] :=
  Module[{g, th, k, c, s},
    {g, th, k} = par[householdUtility, {opts}, #] & /@
      {"Gamma", "Theta", "Kappa"};
    c = w1 h1 + w2 h2;
    s = If[c > 0, w2 h2 / c, 0.];
    Log[c] + g th Log[1 - h1] + g (1 - th) Log[1 - h2] -
      k Max[0., s - 0.5]^2
  ];

(* Closed form for kappa = 0. First-order conditions give
   c = (w1 + w2)/(1 + gamma), home time 1 - h1 = gamma theta c / w1 and
   1 - h2 = gamma (1 - theta) c / w2. If a spouse's home time would be
   negative or above 1, that spouse is at a corner and the other spouse's
   condition is re-solved with the corner imposed. *)
unbiasedSolution[w1_?NumericQ, w2_?NumericQ, opts : OptionsPattern[]] :=
  Module[{g, th, c, h1, h2},
    {g, th} = par[unbiasedSolution, {opts}, #] & /@ {"Gamma", "Theta"};
    c = (w1 + w2) / (1 + g);
    h1 = 1 - g th c / w1;
    h2 = 1 - g (1 - th) c / w2;
    Which[
      h1 < 0, (* husband does no market work *)
        h1 = 0.;
        h2 = 1 / (1 + g (1 - th)),
      h2 < 0, (* wife does no market work *)
        h2 = 0.;
        h1 = 1 / (1 + g th),
      True, Null
    ];
    {h1, h2}
  ];

solveHousehold[w1_?NumericQ, w2_?NumericQ, opts : OptionsPattern[]] :=
  Module[{start, x1, x2, u, sol, h1, h2, c, k},
    k = par[solveHousehold, {opts}, "Kappa"];
    start = unbiasedSolution[w1, w2, opts];
    {h1, h2} = If[k == 0.,
      start,
      (* Start inside the box so Log[1 - h] is finite. *)
      start = Clip[start, {0.01, 0.98}];
      {u, sol} = Quiet @ FindMaximum[
        {householdUtility[x1, x2, w1, w2, opts],
          0 <= x1 <= 0.999, 0 <= x2 <= 0.999},
        {{x1, start[[1]]}, {x2, start[[2]]}}];
      {x1, x2} /. sol
    ];
    c = w1 h1 + w2 h2;
    <|"h1" -> h1, "h2" -> h2, "Home1" -> 1 - h1, "Home2" -> 1 - h2,
      "c" -> c, "WifeShare" -> If[c > 0, w2 h2 / c, 0.],
      "Utility" -> householdUtility[h1, h2, w1, w2, opts]|>
  ];

sweepRelativeWage[ratios_List, opts : OptionsPattern[]] :=
  Prepend[solveHousehold[1., N[#], opts], "Ratio" -> N[#]] & /@ ratios;

End[];

EndPackage[];
