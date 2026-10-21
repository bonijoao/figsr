# Bagging-FIGS: Ensemble of FIGS Models

`bagging_figs()` fits an ensemble of FIGS models using bootstrap
resampling to increase stability and predictive performance on noisy
datasets.

## Usage

``` r
bagging_figs(
  formula,
  data,
  n_estimators = 10,
  max_splits = 6,
  min_n = 5,
  mode = "regression",
  na_method = c("omit", "mia"),
  ...
)
```

## Arguments

- formula:

  A formula.

- data:

  A data frame.

- n_estimators:

  Integer. Number of bootstrap FIGS models to train. Default is 10.

- max_splits:

  Integer. Maximum splits per individual FIGS model. Default is 6.

- min_n:

  Integer. Minimum node size. Default is 5.

- mode:

  Character. `"regression"` or `"classification"`; classification
  supports two-class outcomes only.

- na_method:

  Character. `"omit"` or `"mia"`, passed to every member fit; see
  [`figs()`](https://bonijoao.github.io/figsr/reference/figs.md).

- ...:

  Additional arguments passed to
  [`figs()`](https://bonijoao.github.io/figsr/reference/figs.md).

## Value

An object of class `bagging_figs_fit`.

## Examples

``` r
set.seed(42)
df <- data.frame(x1 = rnorm(50), x2 = rnorm(50), y = rnorm(50))
bag_fit <- bagging_figs(y ~ x1 + x2, data = df, n_estimators = 3)
```
