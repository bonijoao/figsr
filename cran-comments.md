## Resubmission

This is a patch release of a package already on CRAN (0.1.0, published
2026-08-31).

It fixes correctness bugs in prediction that were present in 0.1.0: leaves
created by splitting an existing leaf did not carry the parent's contribution,
so predictions from any tree deeper than one split were wrong, and
classification probabilities were passed through a logistic function although
the engine already estimates them directly. `bagging_figs()` on a factor
outcome returned numeric scores instead of class predictions. These affect every
user of the package, which is why the update follows the first release so
closely; NEWS.md lists the full set.

It also applies the change requested on acceptance of 0.1.0: single quotes in
the Description field are now used only around software names ('parsnip',
'tidymodels'), not around acronyms. FIGS and CART are no longer quoted.

## Test environments

* Local Windows 11, R 4.5.3
* win-builder, R-devel
* GitHub Actions: macOS, Windows and Ubuntu, R release; Ubuntu, R-devel and
  R oldrel-1
* R-hub v2: linux, windows, macos, macos-arm64 (R-devel), ubuntu-next and
  nosuggests

## R CMD check results

0 errors | 0 warnings | 0 notes

The incoming feasibility check may still report "Days since last update", since
0.1.0 was published very recently. The reason for the short interval is the
prediction bug described above.

The words "et", "al" and "ensembling", flagged as possibly misspelled in
earlier checks, are spelled correctly: "et al." comes from the reference to the
paper describing the implemented method, and "ensembling" is the standard term
for combining models into an ensemble, which is what bagging_figs() does.

## Notes for the reviewer

The DOI in the Description field, <doi:10.1073/pnas.2310151122>, refers to the
paper describing the method the package implements (Tan et al., 2023). It is not
a reference to the package itself.
