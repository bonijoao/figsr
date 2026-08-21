## Test environments

* Local Windows 11, R 4.5.3
* win-builder, R-devel (2026-08-12 r90394 ucrt)
* GitHub Actions: macOS, Windows and Ubuntu, R release; Ubuntu, R-devel and
  R oldrel-1
* R-hub v2: linux, windows, macos, macos-arm64 (R-devel), ubuntu-next and
  nosuggests

## R CMD check results

0 errors | 0 warnings | 1 note

The only NOTE is the one CRAN's incoming feasibility check raises for a first
submission. On win-builder (R-devel) it reads:

```
Maintainer: 'Joao Paulo Assis Bonifacio <jpab.27@hotmail.com>'

New submission

Possibly misspelled words in DESCRIPTION:
  al (20:67)
  ensembling (19:27)
  et (20:64)
```

This is the first submission of this package to CRAN.

The flagged words are spelled correctly. "et" and "al" come from the
abbreviation "et al." in the reference to the paper describing the implemented
method, and "ensembling" is the standard term for combining models into an
ensemble, which is what bagging_figs() does.

## Notes for the reviewer

The DOI in the Description field, <doi:10.1073/pnas.2310151122>, refers to the
paper describing the method the package implements (Tan et al., 2023). It is not
a reference to the package itself.
