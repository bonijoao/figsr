# Plot Method for `figsr_fit` Models

`plot.figsr_fit()` visualizes individual decision trees comprising the
Fast Interpretable Greedy-Tree Sums (FIGS) model using 100% Base R
graphics (zero external package dependencies).

Nodes are spaced from the width of their own labels, so boxes and branch
conditions never overlap, and each tree gets a panel width proportional
to the room it needs. When a tree does not fit its panel, the whole
drawing is scaled down – text included – rather than clipped; enlarge
the device to get larger text.

## Usage

``` r
# S3 method for class 'figsr_fit'
plot(
  x,
  tree_idx = NULL,
  style = c("scientific", "modern", "classic"),
  main = NULL,
  tree_names = NULL,
  ...
)
```

## Arguments

- x:

  A fitted `figsr_fit` model object.

- tree_idx:

  Optional integer vector specifying indices of trees to plot. Default
  is `NULL` (plots all trees).

- style:

  Character string specifying the visual style: `"scientific"` (default,
  scientific/editorial notation), `"modern"` (rounded pastel boxes), or
  `"classic"` (high-contrast minimalist statistical style).

- main:

  Optional character string. An overall title drawn once above every
  tree panel. Default is `NULL` (no overall title, the previous
  behavior).

- tree_names:

  Optional character vector overriding the per-tree panel titles
  (`"Subtree f_1(x)"`, `"Tree 1"`, ...). Either a single string, applied
  to every plotted tree, or a vector with one entry per tree in
  `x$trees` – indexed by each tree's position in the fit, not by
  plotting order, so it stays correct when `tree_idx` only plots some of
  them. `NA` in a given position falls back to the default title for
  that tree only. Default is `NULL` (the previous, automatic titles).

- ...:

  Additional arguments, currently ignored.

## Value

Invisible `NULL`.

## Examples

``` r
set.seed(42)
df <- data.frame(x1 = rnorm(50), x2 = rnorm(50), y = rnorm(50))
fit <- figs(y ~ x1 + x2, data = df, max_splits = 3)
plot(fit)

plot(fit, style = "scientific")
plot(fit, tree_idx = 1)
plot(fit, main = "FIGS tree sum", tree_names = "one tree of the sum")
```
