# Update a FIGS Model Specification

[`update()`](https://rdrr.io/r/stats/update.html) changes the arguments
of a
[`figs_tree()`](https://bonijoao.github.io/figsr/reference/figs_tree.md)
specification in place, the way `tidymodels` users expect of any model
specification.

## Usage

``` r
# S3 method for class 'figs_tree'
update(
  object,
  max_splits = NULL,
  max_trees = NULL,
  min_n = NULL,
  fresh = FALSE,
  ...
)
```

## Arguments

- object:

  A
  [`figs_tree()`](https://bonijoao.github.io/figsr/reference/figs_tree.md)
  specification.

- max_splits:

  An integer for the maximum total splits across all trees.

- max_trees:

  An integer for the maximum number of trees.

- min_n:

  An integer for the minimum number of data points in a node to split.

- fresh:

  Logical. Should the arguments be replaced rather than merged?

- ...:

  Not used.

## Value

An updated
[`figs_tree()`](https://bonijoao.github.io/figsr/reference/figs_tree.md)
specification.

## Examples

``` r
spec <- figs_tree(max_splits = 4)
update(spec, max_splits = 8)
#> figs tree Model Specification (regression)
#> 
#> Main Arguments:
#>   max_splits = 8
#> 
#> Computational engine: figsr 
#> 
```
