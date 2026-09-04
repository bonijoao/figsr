# Contributing to figsr

Thanks for your interest in **figsr**, an R implementation of Fast
Interpretable Greedy-Tree Sums (FIGS; Tan et al., 2023,
<doi:10.1073/pnas.2310151122>).

This document explains how the package is organised, how the algorithm was
built, how it is tested, and what a contribution has to satisfy before it can be
merged. Read "How FIGS is implemented" before touching anything under `R/` --
the data structures are unusual enough that a change made on intuition alone is
likely to break a consumer somewhere else.

- Source: <https://github.com/bonijoao/figsr>
- Bugs and feature requests: <https://github.com/bonijoao/figsr/issues>
- Released on CRAN: <https://CRAN.R-project.org/package=figsr>

---

## 1. Getting set up

You need R >= 4.1 and the usual development toolchain:

```r
install.packages(c("devtools", "roxygen2", "testthat", "spelling",
                   "urlchecker", "rcmdcheck", "knitr", "rmarkdown",
                   "parsnip", "dials", "rlang", "tibble"))
```

Building the vignette also requires **pandoc** (bundled with RStudio and with
Quarto; otherwise install it separately).

Everyday commands, run from the package root:

```r
devtools::load_all()      # interactive iteration
devtools::document()      # regenerate man/ and NAMESPACE from roxygen
devtools::test()          # full test suite
devtools::check()         # R CMD check
devtools::build()         # source tarball
```

> **Note on the parsnip registration.** The model is registered with `parsnip`
> from `.onLoad()`. The registration is guarded against being applied twice, so
> calling `load_all()` repeatedly in one session is safe -- but a *changed*
> registration only takes effect in a **fresh R session**. If an edit to
> `R/figs_tree.R` seems to have no effect, restart R before debugging further.

## 2. Reporting a bug

A useful report contains:

1. A **minimal reproducible example** -- simulated data is preferred over a
   private dataset, and please set a seed.
2. What you expected and what actually happened (the full error message, not a
   paraphrase).
3. The output of `sessionInfo()` or `sessioninfo::session_info()`.

Prediction bugs are much easier to diagnose if you include `summary(fit)`,
which prints the whole tree sum as IF-THEN rules.

## 3. Proposing a change

1. Open an issue first for anything larger than a typo, so the design can be
   agreed before you write code.
2. Fork the repository and branch off `main`. Branch names follow the pattern
   `fix/<short-description>` or `feat/<short-description>`.
3. Write the test **before** the fix. Every bug fixed in 0.1.1 has a test that
   fails on the previous commit; that is the standard for new work.
4. Update the roxygen documentation and `NEWS.md`.
5. Run the full gate in section 6 and open a pull request describing what was
   wrong, why the fix is correct, and which test covers it.

Commits use short imperative subjects with a conventional prefix -- `fix:`,
`feat:`, `docs:`, `test:`, `ci:` -- as in `fix: repair prediction, validation
and the split search`.

## 4. How FIGS is implemented

The package is a **from-scratch implementation**. It does not wrap `rpart` or
any other tree backend, so every part of the algorithm lives in this repository
and is open to inspection. It has two layers.

### 4.1 The engine -- `R/fit_engine.R`

`figs()` parses the formula with `model.frame()` and delegates to
`fit_figs_engine(X, y, ...)`. The fitted object stores the `terms` object and
the training `.getXlevels()`, so `predict()` **rebuilds the model frame**
instead of looking predictors up by column name -- that is what makes a formula
such as `y ~ log(x)` predictable from new data. Matrix-valued terms such as
`poly(x, 2)` are rejected at fit time rather than failing obscurely later.

The greedy loop is the heart of the method:

1. A `residuals` vector is initialised to `y`. A two-class factor outcome is
   0/1-encoded; more than two classes is an error.
2. On each of at most `max_splits` iterations, **one global pool of candidates**
   is evaluated: a new root split on the full sample (unless `max_trees` has
   been reached), plus a candidate split at every leaf of every tree that
   already exists.
3. The single candidate with the highest reduction in the residual sum of
   squares wins. Growing a new tree and deepening an existing one compete in the
   same pool -- this "whichever helps most" choice is the whole point of FIGS,
   and what separates it from boosting a fixed number of trees.
4. After a split is accepted, all trees are re-predicted and `residuals` is
   recomputed, so **every tree is always fit against the residuals of the
   others**.
5. The loop halts when the best available gain falls to `<= 1e-6`.

If no split is ever accepted there is no leaf to absorb the outcome mean, so the
fit carries an `intercept` equal to `mean(y)`. As soon as one tree exists the
intercept is 0.

**Splitting rules.** Both modes use reduction in the residual sum of squares.
Numeric predictors are split at midpoints between sorted unique values, capped
at 30 quantiles *of the sample* (not of its distinct values, so the candidates
follow the density of the data). Factor predictors enumerate **all** non-empty
proper subsets of the levels *present in the node* (after `droplevels()`), and
are skipped entirely above 10 such levels -- the enumeration is exponential and
is the main performance cliff in the package.

**Classification has no link function.** The squared-error criterion is applied
to the 0/1 encoding, so the summed leaf values *already* estimate
`P(y = classes[2])`. `predict()` clamps them into `[PROB_EPS, 1 - PROB_EPS]`.
There is no sigmoid anywhere, and reintroducing one would double-transform the
scores -- that was an actual bug, fixed in 0.1.1.

**The tree data structure.** Know this before touching any consumer:

> A tree is a **flat `list` of node lists indexed by position, where
> `id == index`**. `left_child` / `right_child` are integer indices into that
> same list, not nested nodes. The root is always `tree[[1]]`.

Every node is built by the `make_node()` constructor and therefore carries an
identical field set -- `is_leaf`, `feature`, `is_factor`, `split_val` (a numeric
cutpoint, or a character vector of the levels that go left), `left_child`,
`right_child`, `gain`, `value`, `sample_indices`. Consumers rely on that and
never test for a missing component, so **build new nodes only through
`make_node()`**. `gain` is the SSE reduction the split achieved when it was
chosen, and is exactly what `figsr_importance()` sums per predictor.

`predict_trees()` is the shared scorer: it sums leaf values across all trees by
routing **index sets** down one node at a time, rather than looping observation
by observation. It is the hot path -- the engine re-predicts the whole sample
after every accepted split -- so keep it vectorised. There are no surrogate
splits: a missing value reaching a split raises an error there.

### 4.2 The parsnip / tidymodels bridge -- `R/figs_tree.R`

This is the fragile part of the package. `.onLoad()` calls
`make_figs_tree_parsnip()`, which registers the model with `parsnip`
(`set_new_model`, modes, the `"figsr"` engine, encodings, args, fit and pred
modules) as a **load-time side effect**.

- The fit interface is `"data.frame"` with `protect = c("x", "y")`, so `parsnip`
  calls `fit_figs(x =, y =)`. That function rebuilds an outcome-plus-predictors
  data frame and calls `figs()`. The outcome column is named through
  `make.unique()`, so a predictor genuinely called `.outcome` is not clobbered.
  `fit_figs()` also accepts `formula` / `data` for direct use.
- `figs_tree()` defaults to `engine = "figsr"` and has an `update()` method via
  `parsnip::update_spec`, so specifications behave like the rest of `parsnip`.
- `predict_figs()` is the exported prediction bridge; `predict.figsr_fit()` is a
  thin S3 wrapper over it. Both return tidymodels-shaped tibbles (`.pred`,
  `.pred_class`, `.pred_<level>`).
- `max_splits()` and `max_trees()` in `R/dials.R` exist so that `tune_grid()`
  can find `dials` parameter objects for the registered arguments; `min_n`
  reuses `dials::min_n()`.

### 4.3 The rest of `R/`

| File | Responsibility |
|---|---|
| `fit_engine.R` | the greedy loop, split search, node constructor, scorer |
| `figs_tree.R` | `parsnip` registration and the fit/predict bridge |
| `predict.R` | S3 `predict()` methods and prediction-time validation |
| `summary.R` | `print()` / `summary()` -- ASCII IF-THEN rules |
| `plot.R` | base-graphics tree renderer; styles `"scientific"`, `"modern"`, `"classic"` |
| `importance.R` | `figsr_importance()` -- total SSE reduction per predictor |
| `bagging.R` | `bagging_figs()`, a bootstrap ensemble with its own class |

## 5. How the package is tested

Tests use **testthat edition 3** and live in `tests/testthat/`. Run them with
`devtools::test()`, or one file at a time:

```r
testthat::test_file("tests/testthat/test-figs_regression.R")
```

The suite is currently **108 tests across nine files**, and it must stay green.

| File | What it covers |
|---|---|
| `test-figs_regression.R` | the regression path on simulated additive data |
| `test-figs_classification.R` | the two-class path, class labels and probabilities |
| `test-classification-probabilities.R` | scores are on the probability scale, are clamped, and agree with `fitted_values` |
| `test-deep-node-values.R` | a leaf created by splitting a leaf inherits the parent value -- trees deeper than one split predict correctly |
| `test-formula-interface.R` | transformed terms (`y ~ log(x)`), `subset`, `na.action`, rejected `weights`, rejected matrix terms |
| `test-edge-cases.R` | no split accepted (intercept fallback), missing values at prediction time, unseen factor levels, integer overflow in the cutpoints, invalid `type` |
| `test-parsnip.R` | registration, `figs_tree()`, `update()`, fitting through a workflow, tibble-shaped predictions |
| `test-print-plot.R` | `print()`, `summary()` and all three plot styles, plus argument validation |
| `test-importance.R` | importance ranks the predictors that actually drive the outcome |

Conventions the suite follows, and that new tests should follow too:

- **Simulated data with an explicit `set.seed()`.** No test depends on an
  external dataset or on a network.
- **Assert behaviour, not internals**, wherever possible: the regression test
  checks that the correlation between the fitted values and the outcome exceeds
  a threshold rather than pinning exact split points, so a legitimate
  refactoring of the search does not break it.
- **Every bug gets a regression test** that fails without the fix. The files
  `test-deep-node-values.R`, `test-classification-probabilities.R` and
  `test-edge-cases.R` exist for exactly this reason, and were written against
  the bugs listed under 0.1.1 in `NEWS.md`.
- **Error paths are tested as first-class behaviour** (`expect_error()` with a
  message pattern), because a clear error is part of the interface.
- Plot tests assert only that rendering completes and that bad arguments are
  rejected. There is no snapshot of the graphics output, since base-graphics
  output is not stable enough across platforms to compare.

Continuous integration (`.github/workflows/R-CMD-check.yaml`) runs `R CMD check`
on **macOS, Windows and Ubuntu on R release, plus Ubuntu on R-devel and
oldrel-1**, triggered by a push to any branch and by pull requests to `main`.
`.github/workflows/rhub.yaml` runs the R-hub v2 checks and is manual-dispatch
only (it needs the `RHUB_TOKEN` secret).

## 6. The gate a pull request has to pass

`figsr` is on CRAN, and `R CMD check --as-cran` must stay at **0 errors,
0 warnings, 0 notes**:

```r
devtools::check(cran = TRUE)

# devtools::check() skips the CRAN incoming feasibility step; to run the real
# submission gate:
Sys.setenv("_R_CHECK_CRAN_INCOMING_" = "TRUE",
           "_R_CHECK_CRAN_INCOMING_REMOTE_" = "TRUE")
rcmdcheck::rcmdcheck(args = "--as-cran", error_on = "never")

spelling::spell_check_package()
urlchecker::url_check()
```

## 7. Coding standards

These are the rules that keep the check clean, and they are easy to break by
accident:

- **`man/` and `NAMESPACE` are generated.** Run `devtools::document()` after any
  roxygen change; never hand-edit them. `DESCRIPTION` sets
  `Roxygen: list(markdown = TRUE)`, so roxygen blocks are markdown.
- **All R code must be pure ASCII**, for CRAN portability. The tree rules in
  `R/summary.R` use `|--` and a backtick-dash prefix, and plot leaves are
  labelled `dy = ...`, for exactly this reason: a literal Greek delta fails
  `strwidth()` under a non-UTF-8 Windows locale, which is an example **error**,
  not a warning.
- **Call every external function with `::`.** `NAMESPACE` carries no
  `importFrom` directives, so a bare call to `predict()` or `setNames()` becomes
  an "undefined global function" note.
- **Keep `Imports` minimal and actually used** -- currently `dials`, `graphics`,
  `parsnip`, `rlang`, `stats`, `tibble`. Do not add a dependency for one call.
- **Every exported function needs `@return` and a runnable `@examples` block**,
  or the check flags missing Rd tags.
- **User-facing errors use `stop(..., call. = FALSE)`** and say what to do about
  the problem.
- **`LazyData` stays out of `DESCRIPTION`** while there is no `data/` directory.
- **The `Description` field quotes software names only** (`'parsnip'`,
  `'tidymodels'`) and never acronyms -- CRAN asked for this when accepting
  0.1.0, so FIGS and CART are deliberately unquoted.
- **All user-facing text is in English**, with `Language: en-US` (American
  spelling: "modeled", not "modelled"). New proper nouns go into
  `inst/WORDLIST` rather than being reworded away.
- The method paper is **Tan et al., 2023**. `DESCRIPTION`, `README.md` and the
  vignette must keep saying 2023.
- New top-level files that are not part of an R package (this file included)
  must be listed in `.Rbuildignore`, or `R CMD check` reports a non-standard
  file at the top level.

## 8. Roadmap

Survival analysis is planned for **0.2.0**. If you would like to work on it,
please comment on the corresponding issue first, so the design can be discussed
before implementation.

## 9. Conduct and licence

Please be respectful and constructive in issues and pull requests.

By contributing you agree that your contribution is licensed under the
project's MIT licence.
