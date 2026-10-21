# Fit Fast Interpretable Greedy-Tree Sums (FIGS)

`figs()` fits a Fast Interpretable Greedy-Tree Sums model for regression
or binary classification tasks.

## Usage

``` r
figs(
  formula,
  data,
  max_splits = 10,
  max_trees = NULL,
  min_n = 5,
  mode = "regression",
  subset = NULL,
  na.action = stats::na.omit,
  na_method = c("omit", "mia"),
  ...
)
```

## Arguments

- formula:

  A formula specifying outcome and predictor variables.

- data:

  A data frame containing training data.

- max_splits:

  Integer. Maximum total number of splits across all trees in the sum.
  Default is 10.

- max_trees:

  Integer. Maximum number of trees allowed in the sum. Default is NULL
  (unconstrained up to max_splits).

- min_n:

  Integer. Minimum number of observations required in a node to split.
  Default is 5.

- mode:

  Character. Either `"regression"` or `"classification"`. Only two-class
  outcomes are supported in classification mode. Default is
  `"regression"`.

- subset:

  An optional vector selecting the rows of `data` to fit on, passed to
  [`stats::model.frame()`](https://rdrr.io/r/stats/model.frame.html).

- na.action:

  A function describing what to do with missing values, passed to
  [`stats::model.frame()`](https://rdrr.io/r/stats/model.frame.html).
  Defaults to
  [`stats::na.omit()`](https://rdrr.io/r/stats/na.fail.html). Cannot be
  combined with `na_method = "mia"`.

- na_method:

  Character. How to treat missing predictor values: `"omit"` (the
  default) drops incomplete rows, `"mia"` learns a direction for them at
  every split and can also split on missingness itself. See Details.
  Cannot be combined with `na.action`.

- ...:

  Additional arguments, currently ignored. Case weights are not
  supported and passing `weights` raises an error.

## Value

An object of class `figsr_fit` containing fitted tree structures,
predictions, and metadata.

## Details

Trees are grown one split at a time. At each step every leaf of every
existing tree, plus the root of a possible new tree, competes for the
split that most reduces the residual sum of squares; the single best
candidate is taken and the residuals are recomputed against the whole
sum. Growth stops at `max_splits` splits or when no candidate improves
the fit.

Classification is limited to two classes. A factor outcome with more
than two levels raises an error. The binary case is fitted on the 0/1
encoding of the outcome using the same sum-of-squares criterion, so the
sum of the leaf values already estimates the probability of the second
level; it is clamped to the unit interval at prediction time rather than
passed through a link function.

Predictors are used exactly as supplied: numeric features are split at
midpoints between sorted unique values, capped at 30 sample quantiles,
and factor features are split by enumerating subsets of their levels,
which is skipped above 10 levels. A factor level that was not seen in
training raises an error at prediction time, as it does for the other
model-frame based fitting functions in `stats`.

Missing predictor values are governed by `na_method`. With `"omit"`, the
default, rows with a missing predictor are dropped at fit time by
[`stats::model.frame()`](https://rdrr.io/r/stats/model.frame.html) and
raise an error at prediction time. With `"mia"` (missingness
incorporated in attributes, Twala et al. 2008) every row is kept: for a
predictor with missing values the split search also tries sending them
to the left or to the right of each cutpoint, and splitting on whether
the value is missing at all, and keeps whichever reduces the residual
sum of squares most. The learned direction is used at prediction time. A
missing value in a predictor that was complete in training raises an
error, because no direction was learned; impute such values first, for
example with
[`recipes::step_impute_knn()`](https://recipes.tidymodels.org/reference/step_impute_knn.html).
Even under `"mia"`, a branch of the tree that no missing value reached
during training has not learned a direction, so a missing value reaching
that same branch at prediction time still raises an error. Rows with a
missing outcome are dropped with a warning under `na_method = "mia"`
only; under `"omit"` they are dropped silently by
[`stats::na.omit()`](https://rdrr.io/r/stats/na.fail.html).

## References

Twala, B. E. T. H., Jones, M. C. and Hand, D. J. (2008). Good methods
for coping with missing data in decision trees. *Pattern Recognition
Letters*, 29(7), 950-956.

## Examples

``` r
set.seed(123)
df <- data.frame(
  x1 = rnorm(100),
  x2 = rnorm(100),
  y = rnorm(100)
)
fit <- figs(y ~ x1 + x2, data = df, max_splits = 4)
print(fit)
#> ========================================================
#>   FIGS: Fast Interpretable Greedy-Tree Sums Model
#> ========================================================
#> Mode              : regression
#> Total Trees       : 1
#> Total Splits      : 4 / 4 (max_splits)
#> Predictors        : x1, x2
#> Used in Splits    : x1, x2
#> Missing values    : omit
#> ========================================================
#> 
#> Use `summary(fit)` to display detailed decision rules.
#> Use `plot(fit)` to visualize decision tree structures.
```
