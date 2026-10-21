# FIGS Model Specification for Parsnip

`figs_tree()` defines a Fast Interpretable Greedy-Tree Sums model for
use with the `parsnip` and `tidymodels` ecosystem.

## Usage

``` r
figs_tree(
  mode = "regression",
  engine = "figsr",
  max_splits = NULL,
  max_trees = NULL,
  min_n = NULL
)
```

## Arguments

- mode:

  A single character string for the prediction outcome mode:
  `"regression"` or `"classification"`. Classification supports
  two-class outcomes only; a factor with more than two levels raises an
  error at fit time.

- engine:

  A single character string for the computational engine. Only `"figsr"`
  is available.

- max_splits:

  An integer for the maximum total splits across all trees. `NULL` (the
  default) leaves the engine default of 10 in place.

- max_trees:

  An integer for the maximum number of trees. `NULL` (the default)
  leaves the number of trees unconstrained.

- min_n:

  An integer for the minimum number of data points in a node to split.
  `NULL` (the default) leaves the engine default of 5 in place.

## Value

A `parsnip` model specification object.

## Examples

``` r
library(parsnip)
spec <- figs_tree(max_splits = 8) |>
  set_engine("figsr") |>
  set_mode("regression")
spec
#> figs tree Model Specification (regression)
#> 
#> Main Arguments:
#>   max_splits = 8
#> 
#> Computational engine: figsr 
#> 
```
