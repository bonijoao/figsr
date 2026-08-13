## Test environments

* Local Windows 11, R 4.5.3
* win-builder (devel)
* macOS builder (release)
* GitHub Actions: ubuntu-latest (devel, release, oldrel-1), macOS-latest (release),
  windows-latest (release)

## R CMD check results

0 errors | 0 warnings | 0 notes

With `_R_CHECK_CRAN_INCOMING_` enabled there is one NOTE:

```
Maintainer: 'Joao Paulo Assis Bonifacio <jpab.27@hotmail.com>'
New submission
```

This is the first submission of this package to CRAN.

## Notes for the reviewer

The DOI in the Description field, <doi:10.1073/pnas.2310151122>, refers to the
paper describing the method the package implements (Tan et al., 2023). It is not
a reference to the package itself.
