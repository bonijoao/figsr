# Dials Parameter for Maximum Splits

Dials Parameter for Maximum Splits

## Usage

``` r
max_splits(range = c(2L, 20L), trans = NULL)
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
max_splits()
#> Maximum Total Tree Splits (quantitative)
#> Range: [2, 20]
max_splits(range = c(2L, 40L))
#> Maximum Total Tree Splits (quantitative)
#> Range: [2, 40]
```
