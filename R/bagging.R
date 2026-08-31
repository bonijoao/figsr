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
  if (length(n_estimators) != 1 || is.na(n_estimators) || n_estimators < 1) {
    stop("`n_estimators` must be a single integer of at least 1.", call. = FALSE)
  }

  # A character outcome becomes a factor inside each member fit, so a bootstrap
  # sample that happens to miss the minority class would be seen as one-class.
  # Converting once, up front, fixes the level set for every resample.
  response <- all.vars(formula)[1]
  if (!is.null(data[[response]]) && is.character(data[[response]])) {
    data[[response]] <- as.factor(data[[response]])
  }

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
  
  # `figs()` promotes the mode to classification whenever the outcome is a
  # factor, whatever `mode` says, so the ensemble must record what was actually
  # fitted rather than what was asked for.
  res <- list(
    models = models,
    n_estimators = n_estimators,
    formula = formula,
    mode = models[[1]]$mode
  )
  
  class(res) <- "bagging_figs_fit"
  return(res)
}

#' Predict Method for `bagging_figs_fit` Models
#'
#' @param object A fitted `bagging_figs_fit` object.
#' @param new_data A data frame of predictor values.
#' @param type Character. For classification, either `"class"` (the default) or
#'   `"prob"`; ignored for regression, which always returns `.pred`.
#' @param ... Additional arguments.
#'
#' @return A `tibble` containing averaged ensemble predictions.
#' @export
#' @method predict bagging_figs_fit
#'
#' @examples
#' set.seed(42)
#' df <- data.frame(x1 = rnorm(60), x2 = rnorm(60))
#' df$y <- 2 * (df$x1 > 0) + rnorm(60, sd = 0.2)
#' bag_fit <- bagging_figs(y ~ x1 + x2, data = df, n_estimators = 3)
#' predict(bag_fit, new_data = df)
predict.bagging_figs_fit <- function(object, new_data, type = NULL, ...) {
  n_models <- object$n_estimators

  if (object$mode == "regression") {
    all_preds <- vector("list", n_models)
    for (b in seq_len(n_models)) {
      all_preds[[b]] <- stats::predict(object$models[[b]], new_data = new_data,
                                       type = "numeric", ...)
    }
    mat <- do.call(cbind, lapply(all_preds, function(df) df$.pred))
    return(tibble::tibble(.pred = rowMeans(mat)))
  }

  if (is.null(type)) type <- "class"

  class_levels <- object$models[[1]]$classes
  if (is.null(class_levels)) class_levels <- c("0", "1")

  # Average member probabilities, not hard labels: averaging labels discards
  # the confidence of each member and cannot produce a probability output.
  all_probs <- vector("list", n_models)
  for (b in seq_len(n_models)) {
    pb <- stats::predict(object$models[[b]], new_data = new_data,
                         type = "prob", ...)
    all_probs[[b]] <- pb[[paste0(".pred_", class_levels[2])]]
  }
  mean_prob <- rowMeans(do.call(cbind, all_probs))

  if (type == "class") {
    pred_class <- ifelse(mean_prob >= 0.5, class_levels[2], class_levels[1])
    return(tibble::tibble(.pred_class = factor(pred_class, levels = class_levels)))
  }

  if (type == "prob") {
    res_list <- list()
    res_list[[paste0(".pred_", class_levels[1])]] <- 1 - mean_prob
    res_list[[paste0(".pred_", class_levels[2])]] <- mean_prob
    return(tibble::as_tibble(res_list))
  }

  stop("Unsupported prediction type for classification.", call. = FALSE)
}
