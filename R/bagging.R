#' Bagging-FIGS: Ensemble of FIGS Models
#'
#' @description
#' `bagging_figs()` fits an ensemble of FIGS models using bootstrap resampling
#' to increase stability and predictive performance on noisy datasets.
#'
#' @param formula A formula.
#' @param data A data frame.
#' @param n_estimators Integer. Number of bootstrap FIGS models to train. Default is 10.
#' @param max_splits Integer. Maximum splits per individual FIGS model. Default is 6.
#' @param min_n Integer. Minimum node size. Default is 5.
#' @param mode Character. `"regression"` or `"classification"`; classification
#'   supports two-class outcomes only.
#' @param ... Additional arguments passed to [figs()].
#'
#' @return An object of class `bagging_figs_fit`.
#' @export
#'
#' @examples
#' set.seed(42)
#' df <- data.frame(x1 = rnorm(50), x2 = rnorm(50), y = rnorm(50))
#' bag_fit <- bagging_figs(y ~ x1 + x2, data = df, n_estimators = 3)
bagging_figs <- function(formula, data, n_estimators = 10, max_splits = 6, min_n = 5, mode = "regression", ...) {
  if (!is.data.frame(data)) stop("`data` must be a data frame.", call. = FALSE)
  
  n <- nrow(data)
  models <- vector("list", n_estimators)
  
  for (b in seq_len(n_estimators)) {
    boot_indices <- sample.int(n, size = n, replace = TRUE)
    boot_data <- data[boot_indices, , drop = FALSE]
    
    models[[b]] <- figs(
      formula = formula,
      data = boot_data,
      max_splits = max_splits,
      min_n = min_n,
      mode = mode,
      ...
    )
  }
  
  res <- list(
    models = models,
    n_estimators = n_estimators,
    formula = formula,
    mode = mode
  )
  
  class(res) <- "bagging_figs_fit"
  return(res)
}

#' Predict Method for `bagging_figs_fit` Models
#'
#' @param object A fitted `bagging_figs_fit` object.
#' @param new_data A data frame of predictor values.
#' @param ... Additional arguments.
#'
#' @return A `tibble` containing averaged ensemble predictions.
#' @export
#' @method predict bagging_figs_fit
predict.bagging_figs_fit <- function(object, new_data, ...) {
  n_models <- object$n_estimators
  all_preds <- vector("list", n_models)
  
  for (b in seq_len(n_models)) {
    all_preds[[b]] <- stats::predict(object$models[[b]], new_data = new_data, ...)
  }
  
  # Average predictions
  if (object$mode == "regression") {
    mat <- do.call(cbind, lapply(all_preds, function(df) df$.pred))
    mean_preds <- rowMeans(mat)
    res <- tibble::tibble(.pred = mean_preds)
  } else {
    mat <- do.call(cbind, lapply(all_preds, function(df) as.numeric(df$.pred_class) - 1))
    mean_prob <- rowMeans(mat)
    class_levels <- object$models[[1]]$classes
    if (is.null(class_levels)) class_levels <- c("0", "1")
    pred_class <- ifelse(mean_prob >= 0.5, class_levels[2], class_levels[1])
    res <- tibble::tibble(.pred_class = factor(pred_class, levels = class_levels))
  }
  
  return(res)
}
