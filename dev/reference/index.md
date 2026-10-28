# Package index

## Package

The figsr package.

- [`figsr`](https://bonijoao.github.io/figsr/dev/reference/figsr-package.md)
  [`figsr-package`](https://bonijoao.github.io/figsr/dev/reference/figsr-package.md)
  : figsr: Fast Interpretable Greedy-Tree Sums for Tree Ensembles

## Fitting

Fit a sum of trees from a formula, or a bootstrap ensemble of them.

- [`figs()`](https://bonijoao.github.io/figsr/dev/reference/figs.md) :
  Fit Fast Interpretable Greedy-Tree Sums (FIGS)
- [`bagging_figs()`](https://bonijoao.github.io/figsr/dev/reference/bagging_figs.md)
  : Bagging-FIGS: Ensemble of FIGS Models

## Prediction

Tidy predictions from a fitted model.

- [`predict(`*`<figsr_fit>`*`)`](https://bonijoao.github.io/figsr/dev/reference/predict.figsr_fit.md)
  :

  Predict Method for `figsr_fit` Models

- [`predict(`*`<bagging_figs_fit>`*`)`](https://bonijoao.github.io/figsr/dev/reference/predict.bagging_figs_fit.md)
  :

  Predict Method for `bagging_figs_fit` Models

- [`predict_figs()`](https://bonijoao.github.io/figsr/dev/reference/predict_figs.md)
  :

  Internal / Parsnip Predict Bridge Function for `figsr_fit`

## Rules and importance

Read a fit as IF-THEN rules and rank its predictors.

- [`print(`*`<figsr_fit>`*`)`](https://bonijoao.github.io/figsr/dev/reference/print.figsr_fit.md)
  :

  Print Method for `figsr_fit` Models

- [`summary(`*`<figsr_fit>`*`)`](https://bonijoao.github.io/figsr/dev/reference/summary.figsr_fit.md)
  :

  Summary Method for `figsr_fit` Models

- [`figsr_importance()`](https://bonijoao.github.io/figsr/dev/reference/figsr_importance.md)
  :

  Calculate Variable Importance for a `figsr_fit` Model

## Plotting

Draw a fit with ‘ggplot2’ or base graphics.

- [`ggfigs()`](https://bonijoao.github.io/figsr/dev/reference/ggfigs.md)
  [`autoplot(`*`<figsr_fit>`*`)`](https://bonijoao.github.io/figsr/dev/reference/ggfigs.md)
  :

  'ggplot2' Graphics for `figsr_fit` Models

- [`plot(`*`<figsr_fit>`*`)`](https://bonijoao.github.io/figsr/dev/reference/plot.figsr_fit.md)
  :

  Plot Method for `figsr_fit` Models

## tidymodels integration

The ‘parsnip’ model specification, its engine bridge and tuning
parameters.

- [`figs_tree()`](https://bonijoao.github.io/figsr/dev/reference/figs_tree.md)
  : FIGS Model Specification for Parsnip
- [`update(`*`<figs_tree>`*`)`](https://bonijoao.github.io/figsr/dev/reference/update.figs_tree.md)
  : Update a FIGS Model Specification
- [`fit_figs()`](https://bonijoao.github.io/figsr/dev/reference/fit_figs.md)
  : Fitting Bridge for the Parsnip Interface
- [`max_splits()`](https://bonijoao.github.io/figsr/dev/reference/max_splits.md)
  : Dials Parameter for Maximum Splits
- [`max_trees()`](https://bonijoao.github.io/figsr/dev/reference/max_trees.md)
  : Dials Parameter for Maximum Trees

## Data

Data sets used in the examples and articles.

- [`pima_diabetes`](https://bonijoao.github.io/figsr/dev/reference/pima_diabetes.md)
  : Pima Indians Diabetes Database
