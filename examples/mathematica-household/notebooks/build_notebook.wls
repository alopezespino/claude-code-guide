#!/usr/bin/env wolframscript
(* build_notebook.wls: write notebooks/Household.nb from the cell list below.
   The notebook is generated, not hand-edited: change this script and rerun
     wolframscript -file notebooks/build_notebook.wls
   Every input string is syntax-checked before the file is written, and the
   notebook is saved without outputs, so its git diff stays small. *)

dir = DirectoryName[$InputFileName];

inC[code_String] := If[SyntaxQ[code], Cell[code, "Input"],
  Print["syntax error in input cell:\n", code]; Exit[1]];

cells = {
  Cell["Couple's time allocation", "Title"],
  Cell["Explore the model in ../src/Household.wl. The model code lives in \
that package; this notebook only loads it, explores it, and plots. After \
editing the package, rerun the first input cell to reload it.", "Text"],

  Cell["Load the package", "Section"],
  inC["SetDirectory[NotebookDirectory[]];\n\
ClearAll[\"Household`*\", \"Household`Private`*\"];\n\
Get[FileNameJoin[{ParentDirectory[], \"src\", \"Household.wl\"}]];\n\
?solveHousehold"],

  Cell["One solution", "Section"],
  Cell["The husband earns w1 = 1 and the wife earns w2 = 1.5. Compare the \
allocation without bias (kappa = 0) and with bias (kappa = 2).", "Text"],
  inC["Dataset[<|\"kappa = 0\" -> solveHousehold[1, 1.5],\n\
  \"kappa = 2\" -> solveHousehold[1, 1.5, \"Kappa\" -> 2]|>]"],

  Cell["Relative wages and bias", "Section"],
  Cell["Move the relative wage w2/w1 and the bias parameter kappa. The bars \
show market hours; the label shows the wife's share of market income.",
    "Text"],
  inC["Manipulate[\n\
  With[{s = solveHousehold[1, r, \"Kappa\" -> k, \"Gamma\" -> g]},\n\
    BarChart[{s[\"h1\"], s[\"h2\"]},\n\
      ChartLabels -> {\"husband\", \"wife\"}, ChartStyle -> {Blue, Red},\n\
      PlotRange -> {0, 1}, AxesLabel -> {None, \"market hours\"},\n\
      PlotLabel -> StringForm[\"wife's share of income = ``\",\n\
        NumberForm[s[\"WifeShare\"], 3]],\n\
      ImageSize -> 300]],\n\
  {{r, 1, \"w2/w1\"}, 0.3, 3, Appearance -> \"Labeled\"},\n\
  {{k, 0, \"kappa (bias)\"}, 0, 5, Appearance -> \"Labeled\"},\n\
  {{g, 1, \"gamma (home good)\"}, 0.2, 3, Appearance -> \"Labeled\"}]"],

  Cell["Market hours against w2/w1", "Section"],
  Cell["Solid lines: no bias. Dashed lines: kappa = 2. Above equal wages \
the bias keeps the wife's market hours close to the husband's.", "Text"],
  inC["ratios = Range[0.4, 2.5, 0.05];\n\
curves[k_] := With[{s = sweepRelativeWage[ratios, \"Kappa\" -> k]},\n\
  {Transpose[{ratios, #h1 & /@ s}], Transpose[{ratios, #h2 & /@ s}]}];\n\
ListLinePlot[Join[curves[0], curves[2]],\n\
  PlotStyle -> {{Blue}, {Red}, {Blue, Dashed}, {Red, Dashed}},\n\
  PlotLegends -> {\"husband, no bias\", \"wife, no bias\",\n\
    \"husband, kappa = 2\", \"wife, kappa = 2\"},\n\
  AxesLabel -> {\"w2/w1\", \"market hours\"}, GridLines -> {{1}, None},\n\
  PlotRange -> {0, 1}]"]
};

nb = Notebook[cells, StyleDefinitions -> "Default.nb"];
file = FileNameJoin[{dir, "Household.nb"}];
Put[nb, file];
Print["wrote ", file, " (", Length[Cases[cells, Cell[_, "Input"]]],
  " input cells)"];
