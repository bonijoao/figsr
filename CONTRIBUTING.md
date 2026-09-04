# Contributing to figsr

Thanks for your interest in **figsr**.

This document explains how the package is organised, how the algorithm was
built, how it is tested, and what a contribution has to satisfy before it can be
merged. Read "How FIGS is implemented" before touching anything under `R/` --
the data structures are unusual enough that a change made on intuition alone is
likely to break a consumer somewhere else.

- Source: [https://github.com/bonijoao/figsr](https://github.com/bonijoao/figsr)
- Bugs and feature requests: [https://github.com/bonijoao/figsr/issues](https://github.com/bonijoao/figsr/issues)
- Released on CRAN: [https://CRAN.R-project.org/package=figsr](https://CRAN.R-project.org/package=figsr)

---

## 1. Getting set up

You need R >= 4.1, the usual development toolchain (`devtools`, `roxygen2`,
`testthat`, `spelling`, `urlchecker`, `rcmdcheck`) and **pandoc** for the
vignette. From the package root:

```r
devtools::load_all()      # interactive iteration
devtools::document()      # regenerate man/ and NAMESPACE from roxygen
devtools::test()          # full test suite
devtools::check()         # R CMD check
```

The `parsnip` model is registered from `.onLoad()`. The registration is guarded
against being applied twice, so calling `load_all()` repeatedly is safe -- but a
*changed* registration only takes effect in a **fresh R session**. If an edit to
`R/figs_tree.R` seems to have no effect, restart R before debugging further.

## 2. Reporting a bug

Please include a **minimal reproducible example** on simulated data with an
explicit seed, the full error message, and `sessionInfo()`. For a prediction
bug, `summary(fit)` -- which prints the whole tree sum as IF-THEN rules -- makes
diagnosis much faster.

## 3. Proposing a change

1. Open an issue first for anything larger than a typo.
2. Branch off `main` as `fix/<short-description>` or `feat/<short-description>`.
3. Write the test **before** the fix. Every bug fixed in 0.1.1 has a test that
   fails on the previous commit; that is the standard for new work.
4. Update the roxygen documentation and `NEWS.md`.
5. Run the gate in section 6, then open a pull request saying what was wrong,
   why the fix is correct, and which test covers it.

Commit subjects are short and imperative with a conventional prefix -- `fix:`,
`feat:`, `docs:`, `test:`, `ci:`.

## 4. How FIGS is implemented

The package is a **from-scratch implementation**: it does not wrap `rpart` or
any other tree backend. It has two layers.

### 4.1 The engine -- `R/fit_engine.R`

`figs()` parses the formula with `model.frame()` and delegates to
`fit_figs_engine(X, y, ...)`. The fit stores the `terms` object and the training
`.getXlevels()`, so `predict()` **rebuilds the model frame** instead of looking
predictors up by column name -- that is what makes `y ~ log(x)` predictable.
Matrix-valued terms such as `poly(x, 2)` are rejected at fit time.

The greedy loop:

1. `residuals` starts as `y`; a two-class factor outcome is 0/1-encoded, and
   more than two classes is an error.
2. Each of at most `max_splits` iterations evaluates **one global pool of
   candidates**: a new root split on the full sample (unless `max_trees` is
   reached), plus a split at every leaf of every existing tree.
3. The single candidate with the highest reduction in the residual sum of
   squares wins. Growing a new tree and deepening an existing one compete in the
   same pool -- that "whichever helps most" choice is the whole point of FIGS.
4. After each accepted split all trees are re-predicted and `residuals`
   recomputed, so **every tree is always fit against the others' residuals**.
5. The loop halts when the best gain falls to `<= 1e-6`.

If no split is ever accepted there is no leaf to absorb the outcome mean, so the
fit carries an `intercept` of `mean(y)`; once a tree exists the intercept is 0.

**Splitting rules.** Both modes use SSE reduction on the residuals. Numeric
predictors split at midpoints between sorted unique values, capped at 30
quantiles *of the sample* (not of its distinct values). Factor predictors
enumerate **all** non-empty proper subsets of the levels *present in the node*
(after `droplevels()`), and are skipped above 10 such levels -- the enumeration
is exponential and is the main performance cliff.

**Classification has no link function.** The squared-error criterion is applied
to the 0/1 encoding, so the summed leaf values *already* estimate
`P(y = classes[2])`; `predict()` only clamps them into
`[PROB_EPS, 1 - PROB_EPS]`. Reintroducing a sigmoid would double-transform the
scores -- that was a real bug, fixed in 0.1.1.

**The tree data structure.** Know this before touching any consumer:

> A tree is a **flat `list` of node lists indexed by position, where
> `id == index`**. `left_child` / `right_child` are integer indices into that
> same list, not nested nodes. The root is always `tree[[1]]`.

Every node comes from the `make_node()` constructor and so carries an identical
field set -- `is_leaf`, `feature`, `is_factor`, `split_val` (a numeric cutpoint,
or a character vector of the levels going left), `left_child`, `right_child`,
`gain`, `value`, `sample_indices`. Consumers rely on that and never test for a
missing component, so **build new nodes only through `make_node()`**. `gain` is
the SSE reduction the split achieved, and is what `figsr_importance()` sums.

`predict_trees()` is the shared scorer: it sums leaf values across all trees by
routing **index sets** down one node at a time, not observation by observation.
It is the hot path -- the engine re-predicts the whole sample after every
accepted split -- so keep it vectorised. There are no surrogate splits: a
missing value reaching a split raises an error there.

### 4.2 The parsnip / tidymodels bridge -- `R/figs_tree.R`

This is the fragile part. `.onLoad()` calls `make_figs_tree_parsnip()`, which
registers the model with `parsnip` as a **load-time side effect**.

- The fit interface is `"data.frame"` with `protect = c("x", "y")`, so `parsnip`
  calls `fit_figs(x =, y =)`, which rebuilds an outcome-plus-predictors data
  frame and calls `figs()`. The outcome column is named through `make.unique()`,
  so a predictor genuinely called `.outcome` is not clobbered. `fit_figs()` also
  accepts `formula` / `data` for direct use.
- `figs_tree()` defaults to `engine = "figsr"` and has an `update()` method, so
  specifications behave like the rest of `parsnip`.
- `predict_figs()` is the exported prediction bridge; `predict.figsr_fit()` is a
  thin S3 wrapper over it. Both return tidymodels-shaped tibbles (`.pred`,
  `.pred_class`, `.pred_<level>`).
- `max_splits()` and `max_trees()` in `R/dials.R` give `tune_grid()` parameter
  objects for the registered arguments; `min_n` reuses `dials::min_n()`.

### 4.3 The rest of `R/`

| File           | Responsibility                                                              |
| -------------- | --------------------------------------------------------------------------- |
| `fit_engine.R` | the greedy loop, split search, node constructor, scorer                     |
| `figs_tree.R`  | `parsnip` registration and the fit/predict bridge                           |
| `predict.R`    | S3 `predict()` methods and prediction-time validation                       |
| `summary.R`    | `print()` / `summary()` -- ASCII IF-THEN rules                              |
| `plot.R`       | base-graphics tree renderer; styles `"scientific"`, `"modern"`, `"classic"` |
| `importance.R` | `figsr_importance()` -- total SSE reduction per predictor                   |
| `bagging.R`    | `bagging_figs()`, a bootstrap ensemble with its own class                   |

## 5. How the package is tested

Tests use **testthat edition 3** and live in `tests/testthat/`. Run the suite
with `devtools::test()`, or one file with
`testthat::test_file("tests/testthat/test-figs_regression.R")`. It is currently
**108 tests across nine files** and must stay green.

| File                                  | What it covers                                                                                                                                     |
| ------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| `test-figs_regression.R`              | the regression path on simulated additive data                                                                                                     |
| `test-figs_classification.R`          | the two-class path, class labels and probabilities                                                                                                 |
| `test-classification-probabilities.R` | scores are on the probability scale, are clamped, and agree with `fitted_values`                                                                   |
| `test-deep-node-values.R`             | a leaf created by splitting a leaf inherits the parent value -- trees deeper than one split predict correctly                                      |
| `test-formula-interface.R`            | transformed terms (`y ~ log(x)`), `subset`, `na.action`, rejected `weights`, rejected matrix terms                                                 |
| `test-edge-cases.R`                   | no split accepted (intercept fallback), missing values at prediction time, unseen factor levels, integer overflow in the cutpoints, invalid `type` |
| `test-parsnip.R`                      | registration, `figs_tree()`, `update()`, fitting through a workflow, tibble-shaped predictions                                                     |
| `test-print-plot.R`                   | `print()`, `summary()` and all three plot styles, plus argument validation                                                                         |
| `test-importance.R`                   | importance ranks the predictors that actually drive the outcome                                                                                    |

Conventions new tests should follow:

- **Simulated data with an explicit `set.seed()`** -- no test depends on an
  external dataset or on a network.
- **Assert behaviour, not internals.** The regression test checks that the
  correlation between fitted values and outcome exceeds a threshold rather than
  pinning exact split points, so a legitimate refactoring does not break it.
- **Every bug gets a regression test** that fails without the fix. The files
  `test-deep-node-values.R`, `test-classification-probabilities.R` and
  `test-edge-cases.R` were written against the bugs listed under 0.1.1 in
  `NEWS.md`.
- **Error paths are tested as first-class behaviour** (`expect_error()` with a
  message pattern), because a clear error is part of the interface.
- Plot tests assert only that rendering completes and that bad arguments are
  rejected; base-graphics output is not stable enough across platforms to
  snapshot.

CI (`.github/workflows/R-CMD-check.yaml`) runs `R CMD check` on macOS, Windows
and Ubuntu on R release, plus Ubuntu on R-devel and oldrel-1, on every push and
on pull requests to `main`. `.github/workflows/rhub.yaml` runs the R-hub v2
checks and is manual-dispatch only (it needs the `RHUB_TOKEN` secret).

## 6. The gate a pull request has to pass

`figsr` is on CRAN, so `R CMD check --as-cran` must stay at **0 errors,
0 warnings, 0 notes**:

```r
devtools::check(cran = TRUE)

# devtools::check() skips the CRAN incoming feasibility step; for the real
# submission gate:
Sys.setenv("_R_CHECK_CRAN_INCOMING_" = "TRUE",
           "_R_CHECK_CRAN_INCOMING_REMOTE_" = "TRUE")
rcmdcheck::rcmdcheck(args = "--as-cran", error_on = "never")

spelling::spell_check_package()
urlchecker::url_check()
```

## 7. Coding standards

These keep the check clean and are easy to break by accident:

- **`man/` and `NAMESPACE` are generated.** Run `devtools::document()` after any
  roxygen change; never hand-edit them. Roxygen blocks are markdown.
- **All R code must be pure ASCII.** The tree rules in `R/summary.R` and the
  `dy = ...` plot labels exist for this reason: a literal Greek delta fails
  `strwidth()` under a non-UTF-8 Windows locale, which is an example **error**,
  not a warning.
- **Call every external function with `::`.** `NAMESPACE` carries no
  `importFrom` directives, so a bare `predict()` or `setNames()` becomes an
  "undefined global function" note.
- **Keep `Imports` minimal and actually used** -- `dials`, `graphics`,
  `parsnip`, `rlang`, `stats`, `tibble`. Never add a dependency for one call.
- **Every exported function needs `@return` and a runnable `@examples` block.**
- **User-facing errors use `stop(..., call. = FALSE)`** and say what to do.
- **`LazyData` stays out of `DESCRIPTION`** while there is no `data/` directory.
- **The `Description` field quotes software names only** (`'parsnip'`,
  `'tidymodels'`), never acronyms -- CRAN asked for this when accepting 0.1.0,
  so FIGS and CART are deliberately unquoted.
- **All user-facing text is in English**, `Language: en-US`. New proper nouns go
  into `inst/WORDLIST` rather than being reworded away.
- The method paper is **Tan et al., 2023**; `DESCRIPTION`, `README.md` and the
  vignette must keep saying 2023.
- A new top-level file that is not part of an R package (this one included) must
  be listed in `.Rbuildignore`, or the check reports a non-standard file at the
  top level.
