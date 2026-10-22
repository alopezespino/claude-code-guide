#!/usr/bin/env wolframscript
(* sweep.wls: solve the couple's problem over a grid of relative wages
   w2/w1, with and without gender-role bias, and write
     results/sweep.csv        one row per (kappa, ratio)
     results/market_hours.png each spouse's market hours against w2/w1
   Usage, from the example folder:  wolframscript -file scripts/sweep.wls *)

root = ParentDirectory[DirectoryName[$InputFileName]];
Get[FileNameJoin[{root, "src", "Household.wl"}]];
out = FileNameJoin[{root, "results"}];
If[!DirectoryQ[out], CreateDirectory[out]];

ratios = Range[0.4, 2.5, 0.05];
kappas = {0., 2.};

rows = Flatten[Table[
  With[{s = solveHousehold[1., r, "Kappa" -> k]},
    {k, r, s["h1"], s["h2"], s["WifeShare"], s["Utility"]}],
  {k, kappas}, {r, ratios}], 1];

Export[FileNameJoin[{out, "sweep.csv"}],
  Prepend[rows, {"kappa", "w2_over_w1", "h1", "h2", "wife_share", "utility"}]];
Print["wrote ", FileNameJoin[{out, "sweep.csv"}], " (", Length[rows], " rows)"];

curve[k_, col_] := Select[rows, #[[1]] == k &][[All, {2, col}]];
fig = ListLinePlot[
  {curve[0., 3], curve[0., 4], curve[2., 3], curve[2., 4]},
  PlotStyle -> {{Blue}, {Red}, {Blue, Dashed}, {Red, Dashed}},
  PlotLegends -> {"husband, no bias", "wife, no bias",
    "husband, kappa = 2", "wife, kappa = 2"},
  AxesLabel -> {"w2/w1", "market hours"}, GridLines -> {{1}, None},
  PlotRange -> {0, 1}, ImageSize -> 500];
Export[FileNameJoin[{out, "market_hours.png"}], fig];
Print["wrote ", FileNameJoin[{out, "market_hours.png"}]];
