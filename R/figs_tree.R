#' FIGS Model Specification for Parsnip
#'
#' @description
#' `figs_tree()` defines a Fast Interpretable Greedy-Tree Sums model for use with
#' the `parsnip` and `tidymodels` ecosystem.
#'
#' @param mode A single character string for the prediction outcome mode:
#'   `"regression"` or `"classification"`.
#' @param max_splits An integer for the maximum total splits across all trees. Default is 10.
#' @param max_trees An integer for the maximum number of trees. Default is NULL.
#' @param min_n An integer for the minimum number of data points in a node to split. Default is 5.
#'
#' @return A `parsnip` model specification object.
#' @export
#'
#' @examples
#' library(parsnip)
#' spec <- figs_tree(max_splits = 8) |>
#'   set_engine("figsr") |>
#'   set_mode("regression")
#' spec
figs_tree <- function(mode = "regression", max_splits = NULL, max_trees = NULL, min_n = NULL) {
  args <- list(
    max_splits = rlang::enquo(max_splits),
    max_trees  = rlang::enquo(max_trees),
    min_n      = rlang::enquo(min_n)
  )
  
  parsnip::new_model_spec(
    "figs_tree",
    args = args,
    eng_args = NULL,
    mode = mode,
    method = NULL,
    engine = NULL
  )
}

#' @export
figs_tree.default <- function(mode = "regression", max_splits = NULL, max_trees = NULL, min_n = NULL) {
  figs_tree(mode = mode, max_splits = max_splits, max_trees = max_trees, min_n = min_n)
}

# Register parsip engine environment on load
.onLoad <- function(libname, pkgname) {
  make_figs_tree_parsnip()
}

make_figs_tree_parsnip <- function() {
  if (!requireNamespace("parsnip", quietly = TRUE)) return(invisible(NULL))
  
  # Register model and modes
  parsnip::set_new_model("figs_tree")
  parsnip::set_model_mode("figs_tree", mode = "regression")
  parsnip::set_model_mode("figs_tree", mode = "classification")
  
  parsnip::set_model_engine("figs_tree", mode = "regression", eng = "figsr")
  parsnip::set_model_engine("figs_tree", mode = "classification", eng = "figsr")
  
  parsnip::set_dependency("figs_tree", eng = "figsr", pkg = "figsr")
  
  parsnip::set_encoding(
    model = "figs_tree",
    eng = "figsr",
    mode = "regression",
    options = list(
      predictor_indicators = "none",
      compute_intercept = FALSE,
      remove_intercept = FALSE,
      allow_sparse_x = FALSE
    )
  )
  
  parsnip::set_encoding(
    model = "figs_tree",
    eng = "figsr",
    mode = "classification",
    options = list(
      predictor_indicators = "none",
      compute_intercept = FALSE,
      remove_intercept = FALSE,
      allow_sparse_x = FALSE
    )
  )
  
  # Register arguments
  parsnip::set_model_arg(
    model = "figs_tree",
    eng = "figsr",
    parsnip = "max_splits",
    original = "max_splits",
    func = list(pkg = "figsr", fun = "max_splits"),
    has_submodel = FALSE
  )
  
  parsnip::set_model_arg(
    model = "figs_tree",
    eng = "figsr",
    parsnip = "max_trees",
    original = "max_trees",
    func = list(pkg = "figsr", fun = "max_trees"),
    has_submodel = FALSE
  )
  
  parsnip::set_model_arg(
    model = "figs_tree",
    eng = "figsr",
    parsnip = "min_n",
    original = "min_n",
    func = list(pkg = "dials", fun = "min_n"),
    has_submodel = FALSE
  )
  
  # Fit interface for regression
  parsnip::set_fit(
    model = "figs_tree",
    eng = "figsr",
    mode = "regression",
    value = list(
      interface = "data.frame",
      protect = c("x", "y"),
      func = c(pkg = "figsr", fun = "fit_figs"),
      defaults = list(mode = "regression")
    )
  )
  
  # Fit interface for classification
  parsnip::set_fit(
    model = "figs_tree",
    eng = "figsr",
    mode = "classification",
    value = list(
      interface = "data.frame",
      protect = c("x", "y"),
      func = c(pkg = "figsr", fun = "fit_figs"),
      defaults = list(mode = "classification")
    )
  )
  
  # Predictions for regression
  parsnip::set_pred(
    model = "figs_tree",
    eng = "figsr",
    mode = "regression",
    type = "numeric",
    value = list(
      pre = NULL,
      post = NULL,
      func = c(pkg = "figsr", fun = "predict_figs"),
      args = list(
        object = quote(object$fit),
        new_data = quote(new_data),
        type = "numeric"
      )
    )
  )
  
  # Predictions for classification class
  parsnip::set_pred(
    model = "figs_tree",
    eng = "figsr",
    mode = "classification",
    type = "class",
    value = list(
      pre = NULL,
      post = NULL,
      func = c(pkg = "figsr", fun = "predict_figs"),
      args = list(
        object = quote(object$fit),
        new_data = quote(new_data),
        type = "class"
      )
    )
  )
  
  # Predictions for classification prob
  parsnip::set_pred(
    model = "figs_tree",
    eng = "figsr",
    mode = "classification",
    type = "prob",
    value = list(
      pre = NULL,
      post = NULL,
      func = c(pkg = "figsr", fun = "predict_figs"),
      args = list(
        object = quote(object$fit),
        new_data = quote(new_data),
        type = "prob"
      )
    )
  )
}

#' Fit S3 generic for Parsnip interface
#' @param formula A formula or predictor matrix/data.frame.
#' @param data A data frame or outcome vector.
#' @param x Predictors matrix/data.frame.
#' @param y Outcome vector.
#' @param max_splits Integer. Maximum splits.
#' @param max_trees Integer. Maximum trees.
#' @param min_n Integer. Minimum node size.
#' @param mode Character. "regression" or "classification".
#' @param ... Additional arguments.
#' @export
fit_figs <- function(formula = NULL, data = NULL, x = NULL, y = NULL, max_splits = 10, max_trees = NULL, min_n = 5, mode = "regression", ...) {
  if (!is.null(formula) && !is.null(data)) {
    return(figs(formula = formula, data = data, max_splits = max_splits, max_trees = max_trees, min_n = min_n, mode = mode, ...))
  }
  
  if (!is.null(x) && !is.null(y)) {
    df <- as.data.frame(x)
    df$.outcome <- y
    f <- stats::as.formula(".outcome ~ .")
    return(figs(formula = f, data = df, max_splits = max_splits, max_trees = max_trees, min_n = min_n, mode = mode, ...))
  }
  
  # Fallback if positional args provided
  if (inherits(formula, "formula") && is.data.frame(data)) {
    return(figs(formula = formula, data = data, max_splits = max_splits, max_trees = max_trees, min_n = min_n, mode = mode, ...))
  }
  
  stop("Invalid input to fit_figs: expected formula and data, or x and y.", call. = FALSE)
}
