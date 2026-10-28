## Update

This is an update of a package already on CRAN (0.1.1). It adds handling of
missing predictor values (`na_method = "mia"`), a rewritten split search that
makes fitting about 25 to 60 times faster with the same fitted models, a new
'ggplot2' plotting function, `ggfigs()`, and a small example data set,
`pima_diabetes`. NEWS.md lists the full set of changes.

'ggplot2' (>= 4.0.0) is a new entry in Imports; it was already a dependency
through 'parsnip'. 'ggiraph' is a new entry in Suggests and is used only
conditionally.

## Test environments

* Local Windows 11, R 4.5.3
* win-builder, R-release
* GitHub Actions: macOS, Windows and Ubuntu, R release; Ubuntu, R-devel and
  R oldrel-1

## R CMD check results

0 errors | 0 warnings | 0 notes

## Notes for the reviewer

The DOI in the Description field, <doi:10.1073/pnas.2310151122>, refers to the
paper describing the method the package implements (Tan et al., 2023). It is not
a reference to the package itself. The publisher's site may answer automated
requests for that DOI with HTTP 403; the DOI is valid and resolves in a browser.
