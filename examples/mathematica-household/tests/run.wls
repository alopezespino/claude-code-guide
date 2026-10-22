#!/usr/bin/env wolframscript
(* run.wls: load the package, run tests/HouseholdTests.wlt, print one line
   per test, and exit with status 1 if any test fails.
   Usage, from the example folder:  wolframscript -file tests/run.wls *)

root = ParentDirectory[DirectoryName[$InputFileName]];
Get[FileNameJoin[{root, "src", "Household.wl"}]];

report = TestReport[FileNameJoin[{root, "tests", "HouseholdTests.wlt"}]];

Scan[
  Print[If[#["Outcome"] === "Success", "PASS  ", "FAIL  "], #["TestID"]] &,
  Values[report["TestResults"]]
];
Print[report["TestsSucceededCount"], " passed, ",
  report["TestsFailedCount"], " failed"];

Exit[If[report["AllTestsSucceeded"], 0, 1]];
