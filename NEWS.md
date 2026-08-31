# figsr 0.1.1

## Bug fixes

* `figs()` now carries the parent leaf's value into the two leaves created by
  splitting it. Predictions from any tree deeper than one split were wrong
  before this fix.

* Classification probabilities are no longer passed through a logistic
  function. The engine fits squared error on the 0/1 encoding of the outcome,
  so the sum of the leaf values already estimates the probability of the second
  level; it is now clamped to the unit interval instead. `fitted_values` is
  clamped the same way, so it agrees with `predict()`.

* `predict()` now rebuilds the model frame from the fitted terms, so a formula
  with a transformed term such as `y ~ log(x)` can be predicted from. It
  previously failed with a missing-predictor error.

* A matrix-valued term such as `poly(x, 2)` raised a cryptic
  "missing value where TRUE/FALSE needed" during fitting; it is now rejected
  with a clear message.

* `figs()` gained `subset` and `na.action` arguments, which were previously
  swallowed by `...` and silently ignored. Passing `weights` now raises an
  error rather than fitting an unweighted model in silence.

* A model that accepts no split at all predicts the outcome mean instead of
  zero. In classification this was a probability of zero for every observation.

* Integer predictors with large values no longer overflow when the candidate
  cutpoints are computed.

* Numeric cutpoints above the 30-candidate cap are now quantiles of the sample
  rather than of its distinct values, so they follow the density of the data.

* Factor predictors are judged by the levels present in a node rather than by
  the declared level set, so a factor carrying many unused levels is no longer
  skipped as if it had too many levels.

* A missing value in a predictor at prediction time raises a clear error, and a
  factor level unseen in training is rejected the way other `stats` model
  functions reject it, instead of failing deep inside the tree traversal.

* `predict()` rejects an unsupported `type` instead of quietly returning
  numeric predictions.

* `bagging_figs()` records the mode that was actually fitted. A factor outcome
  with the default `mode = "regression"` produced an ensemble that returned
  numeric scores instead of class predictions. Bagged classification also
  averages member probabilities rather than hard labels, and supports
  `type = "prob"`. A character outcome is converted to a factor once, so a
  bootstrap resample that misses the minority class no longer aborts the fit.

* `fit_figs()` no longer drops a predictor genuinely named `.outcome`.

* `plot()` validates `style` and `tree_idx` instead of rendering the wrong
  style silently or failing with an internal error on `NA`. The `"classic"`
  style labels leaves `dy =`, like the other styles, because a leaf holds one
  tree's contribution rather than the prediction.

* Registering the `parsnip` model is now idempotent, so reloading the package in
  a live session no longer errors.

## New features

* `figs_tree()` gained an `engine` argument defaulting to `"figsr"`, and an
  `update()` method, so specifications behave like the rest of `parsnip`.

* `print()` reports which predictors actually carry a split, and `summary()`
  states that classification leaf values are contributions to the probability
  of the second class.

## Documentation

* The `Description` field no longer quotes acronyms, following the request from CRAN.
* Help pages are rendered from markdown, so inline code and cross-references
  appear as such.
* The introductory vignette covers prediction, importance, plotting,
  classification, `parsnip` integration and bagging, and its example data no
  longer draws the outcome independently of the predictors.

# figsr 0.1.0

* First release.

* `figs()` fits Fast Interpretable Greedy-Tree Sums for regression and two-class
  classification, growing a sum of shallow trees by greedily taking the split
  that most reduces residual impurity, whether that split opens a new tree or
  deepens an existing one.

* `figs_tree()` registers the model with `parsnip`, so FIGS can be used inside
  `tidymodels` workflows. `max_splits()` and `max_trees()` provide `dials`
  parameter objects for tuning; `min_n` reuses `dials::min_n()`.

* `summary()` prints the tree sum as IF-THEN decision rules and `plot()` draws
  the trees, in a `"scientific"`, `"modern"` or `"classic"` style.

* `figsr_importance()` ranks predictors by the total residual sum-of-squares
  reduction attributable to each of them.

* `bagging_figs()` fits a bootstrap ensemble of FIGS models.
