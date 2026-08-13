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
