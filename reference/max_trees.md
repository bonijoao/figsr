# Dials Parameter for Maximum Trees

Dials Parameter for Maximum Trees

## Usage

``` r
max_trees(range = c(1L, 10L), trans = NULL)
```

## Arguments

- range:

  A numeric vector of length 2 for lower and upper limits.

- trans:

  A trans object.

## Value

A `dials` parameter object.

## Examples

``` r
max_trees()
#> Maximum Number of Trees in Sum (quantitative)
#> Range: [1, 10]
max_trees(range = c(1L, 5L))
#> Maximum Number of Trees in Sum (quantitative)
#> Range: [1, 5]
```
