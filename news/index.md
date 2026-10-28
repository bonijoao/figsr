# Changelog

## figsr 0.2.0

CRAN release: 2026-10-28

### New features

- [`figs()`](https://bonijoao.github.io/figsr/reference/figs.md),
  [`fit_figs()`](https://bonijoao.github.io/figsr/reference/fit_figs.md)
  and
  [`bagging_figs()`](https://bonijoao.github.io/figsr/reference/bagging_figs.md)
  gained `na_method`. The default `"omit"` is the previous behavior.
  `"mia"` (missingness incorporated in attributes, Twala et al. 2008)
  keeps every row: at each split the search also tries sending missing
  values left or right of the cutpoint, and splitting on missingness
  itself, and uses the learned direction at prediction time.
  [`summary()`](https://rdrr.io/r/base/summary.html) prints these as
  `IS MISSING` clauses,
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html) labels the
  edge missing values take, and
  [`figsr_importance()`](https://bonijoao.github.io/figsr/reference/figsr_importance.md)
  reports a split on missingness on its own `missing(<predictor>)` row.

- [`ggfigs()`](https://bonijoao.github.io/figsr/reference/ggfigs.md)
  draws a fitted model with ‘ggplot2’, in five views: `"tree"`
  (node-link diagram of every tree), `"rules"` (every tree as a
  horizontal rule list, with `+` between trees), `"waterfall"` (where
  the prediction for one observation comes from), `"cuts"` (the numeric
  cutpoints drawn over the data) and `"profile"` (exact partial
  dependence). It returns a `ggplot`; with `interactive = TRUE` it
  returns a ‘ggiraph’ widget whose tooltips show the rule behind each
  node, leaf or cut. ‘ggiraph’ is only suggested.
  [`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html)
  gives the same `ggplot`s.

- [`plot()`](https://rdrr.io/r/graphics/plot.default.html) gained
  `main`, an overall title drawn once above every tree panel, and
  `tree_names`, overriding the automatic per-tree panel titles (a single
  string applies to every tree; a vector is indexed by each tree’s
  position in the fit, so it stays correct when `tree_idx` only plots
  some of them; `NA` in a position keeps that tree’s default title). In
  the `"scientific"` and `"modern"` styles, a leaf’s background, border
  and text now depend on the sign of its contribution – green for
  positive, red for negative; `"classic"` stays monochromatic by design.

### Performance

- The split search was rewritten and fitting is about 25 to 60 times
  faster (for example, 12.6 s to 0.33 s with 32,000 rows, 10 numeric
  predictors and `max_splits = 10`), allocating about 30 times less
  memory. Everything that depends on the predictors alone (row order,
  cutpoints, level groups) is computed once per node instead of once per
  iteration, every cutpoint of a predictor is scored from a single
  cumulative sum of the residuals instead of one pass per cutpoint, and
  a leaf whose residuals did not change since the last iteration keeps
  its previous best split. The fitted model is unchanged: the same
  splits, cutpoints, missing-value directions and sample indices as the
  previous search, which a new regression test checks on fourteen data
  sets.

### Bug fixes

- The `parsnip` engine now fits through the formula interface. The
  previous data.frame interface ran
  [`model.frame()`](https://rdrr.io/r/stats/model.frame.html) with
  `na.omit` before the engine, so
  [`fit()`](https://generics.r-lib.org/reference/fit.html) silently
  dropped rows with a missing predictor.

- [`plot()`](https://rdrr.io/r/graphics/plot.default.html) no longer
  draws boxes on top of each other. Nodes used to sit on a fixed grid,
  so in deeper trees neighboring leaves and branch conditions overlapped
  and their labels were cut off. Each split now places its subtrees from
  the width of their labels, every tree gets a panel width proportional
  to the room it needs, and all trees share one vertical scale, so their
  roots line up. A drawing too large for its panel is scaled down, text
  included, instead of clipped.

### New data

- `pima_diabetes`: the Pima Indians Diabetes Database (Smith et
  al. 1988), 768 patients, ships lazily loaded like `iris`. Its five
  physiologically impossible zeros (`Glucose`, `BloodPressure`,
  `SkinThickness`, `Insulin`, `BMI`) are already recoded to `NA`, so it
  is ready to demonstrate `na_method = "mia"` without an internet
  connection or preprocessing.

### Documentation

- A new vignette,
  [`vignette("missing-values")`](https://bonijoao.github.io/figsr/articles/missing-values.md),
  works through `na_method = "mia"` on the real Pima Indians Diabetes
  Database, where missingness is informative but modest, and shows
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html)’s new `main`,
  `tree_names` and sign-colored leaves on it.

## figsr 0.1.1

CRAN release: 2026-08-31

### Bug fixes

- [`figs()`](https://bonijoao.github.io/figsr/reference/figs.md) now
  carries the parent leaf’s value into the two leaves created by
  splitting it. Predictions from any tree deeper than one split were
  wrong before this fix.

- Classification probabilities are no longer passed through a logistic
  function. The engine fits squared error on the 0/1 encoding of the
  outcome, so the sum of the leaf values already estimates the
  probability of the second level; it is now clamped to the unit
  interval instead. `fitted_values` is clamped the same way, so it
  agrees with [`predict()`](https://rdrr.io/r/stats/predict.html).

- [`predict()`](https://rdrr.io/r/stats/predict.html) now rebuilds the
  model frame from the fitted terms, so a formula with a transformed
  term such as `y ~ log(x)` can be predicted from. It previously failed
  with a missing-predictor error.

- A matrix-valued term such as `poly(x, 2)` raised a cryptic “missing
  value where TRUE/FALSE needed” during fitting; it is now rejected with
  a clear message.

- [`figs()`](https://bonijoao.github.io/figsr/reference/figs.md) gained
  `subset` and `na.action` arguments, which were previously swallowed by
  `...` and silently ignored. Passing `weights` now raises an error
  rather than fitting an unweighted model in silence.

- A model that accepts no split at all predicts the outcome mean instead
  of zero. In classification this was a probability of zero for every
  observation.

- Integer predictors with large values no longer overflow when the
  candidate cutpoints are computed.

- Numeric cutpoints above the 30-candidate cap are now quantiles of the
  sample rather than of its distinct values, so they follow the density
  of the data.

- Factor predictors are judged by the levels present in a node rather
  than by the declared level set, so a factor carrying many unused
  levels is no longer skipped as if it had too many levels.

- A missing value in a predictor at prediction time raises a clear
  error, and a factor level unseen in training is rejected the way other
  `stats` model functions reject it, instead of failing deep inside the
  tree traversal.

- [`predict()`](https://rdrr.io/r/stats/predict.html) rejects an
  unsupported `type` instead of quietly returning numeric predictions.

- [`bagging_figs()`](https://bonijoao.github.io/figsr/reference/bagging_figs.md)
  records the mode that was actually fitted. A factor outcome with the
  default `mode = "regression"` produced an ensemble that returned
  numeric scores instead of class predictions. Bagged classification
  also averages member probabilities rather than hard labels, and
  supports `type = "prob"`. A character outcome is converted to a factor
  once, so a bootstrap resample that misses the minority class no longer
  aborts the fit.

- [`fit_figs()`](https://bonijoao.github.io/figsr/reference/fit_figs.md)
  no longer drops a predictor genuinely named `.outcome`.

- [`plot()`](https://rdrr.io/r/graphics/plot.default.html) validates
  `style` and `tree_idx` instead of rendering the wrong style silently
  or failing with an internal error on `NA`. The `"classic"` style
  labels leaves `dy =`, like the other styles, because a leaf holds one
  tree’s contribution rather than the prediction.

- Registering the `parsnip` model is now idempotent, so reloading the
  package in a live session no longer errors.

### New features

- [`figs_tree()`](https://bonijoao.github.io/figsr/reference/figs_tree.md)
  gained an `engine` argument defaulting to `"figsr"`, and an
  [`update()`](https://rdrr.io/r/stats/update.html) method, so
  specifications behave like the rest of `parsnip`.

- [`print()`](https://rdrr.io/r/base/print.html) reports which
  predictors actually carry a split, and
  [`summary()`](https://rdrr.io/r/base/summary.html) states that
  classification leaf values are contributions to the probability of the
  second class.

### Documentation

- The `Description` field no longer quotes acronyms, following the
  request from CRAN.
- Help pages are rendered from markdown, so inline code and
  cross-references appear as such.
- The introductory vignette covers prediction, importance, plotting,
  classification, `parsnip` integration and bagging, and its example
  data no longer draws the outcome independently of the predictors.

## figsr 0.1.0

CRAN release: 2026-08-31

- First release.

- [`figs()`](https://bonijoao.github.io/figsr/reference/figs.md) fits
  Fast Interpretable Greedy-Tree Sums for regression and two-class
  classification, growing a sum of shallow trees by greedily taking the
  split that most reduces residual impurity, whether that split opens a
  new tree or deepens an existing one.

- [`figs_tree()`](https://bonijoao.github.io/figsr/reference/figs_tree.md)
  registers the model with `parsnip`, so FIGS can be used inside
  `tidymodels` workflows.
  [`max_splits()`](https://bonijoao.github.io/figsr/reference/max_splits.md)
  and
  [`max_trees()`](https://bonijoao.github.io/figsr/reference/max_trees.md)
  provide `dials` parameter objects for tuning; `min_n` reuses
  [`dials::min_n()`](https://dials.tidymodels.org/reference/trees.html).

- [`summary()`](https://rdrr.io/r/base/summary.html) prints the tree sum
  as IF-THEN decision rules and
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html) draws the
  trees, in a `"scientific"`, `"modern"` or `"classic"` style.

- [`figsr_importance()`](https://bonijoao.github.io/figsr/reference/figsr_importance.md)
  ranks predictors by the total residual sum-of-squares reduction
  attributable to each of them.

- [`bagging_figs()`](https://bonijoao.github.io/figsr/reference/bagging_figs.md)
  fits a bootstrap ensemble of FIGS models.
