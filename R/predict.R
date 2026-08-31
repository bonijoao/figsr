#' Predict Method for `figsr_fit` Models
#'
#' @param object A fitted `figsr_fit` object.
#' @param new_data A data frame of new predictor observations.
#' @param type Character. Either `"numeric"`, `"class"`, or `"prob"`. Default depends on model mode.
#' @param ... Additional arguments.
#'
#' @return A `tibble` with predictions in standardized `tidymodels` format.
#' @export
#' @method predict figsr_fit
#'
#' @examples
#' set.seed(42)
#' df <- data.frame(x1 = rnorm(50), y = rnorm(50))
#' fit <- figs(y ~ x1, data = df)
#' predict(fit, new_data = df)
predict.figsr_fit <- function(object, new_data, type = NULL, ...) {
  if (missing(new_data) || is.null(new_data)) {
    stop("`new_data` must be provided for predictions.", call. = FALSE)
  }
  
  new_df <- as.data.frame(new_data)
  
  if (is.null(type)) {
    type <- if (object$mode == "classification") "class" else "numeric"
  }
  
  predict_figs(object = object, new_data = new_df, type = type, ...)
}

#' Internal / Parsnip Predict Bridge Function for `figsr_fit`
#'
#' @param object A fitted `figsr_fit` object.
#' @param new_data A data frame of new predictor observations.
#' @param type Character. `"numeric"`, `"class"`, or `"prob"`.
#' @param ... Additional arguments.
#'
#' @return A `tibble` of predictions.
#' @export
#'
#' @examples
#' set.seed(42)
#' df <- data.frame(x1 = rnorm(60))
#' df$y <- 2 * (df$x1 > 0) + rnorm(60, sd = 0.2)
#' fit <- figs(y ~ x1, data = df, max_splits = 3)
#' predict_figs(fit, new_data = df, type = "numeric")
predict_figs <- function(object, new_data, type = "numeric", ...) {
  valid_types <- if (object$mode == "classification") {
    c("class", "prob", "numeric")
  } else {
    "numeric"
  }
  if (length(type) != 1 || !type %in% valid_types) {
    stop(paste0("`type` must be one of ",
                paste0("\"", valid_types, "\"", collapse = ", "),
                " for a ", object$mode, " model."), call. = FALSE)
  }

  new_df <- as.data.frame(new_data)

  # Rebuild the model frame from the stored terms so that transformed terms
  # such as `log(x)` are recomputed instead of being looked up as column names.
  if (!is.null(object$terms)) {
    predictors <- stats::delete.response(object$terms)
    missing_vars <- setdiff(all.vars(predictors), colnames(new_df))
    if (length(missing_vars) > 0) {
      stop(paste("The following predictor variables are missing in `new_data`:",
                 paste(missing_vars, collapse = ", ")), call. = FALSE)
    }
    X_new <- stats::model.frame(predictors, new_df, na.action = stats::na.pass,
                                xlev = object$xlevels)
  } else {
    missing_vars <- setdiff(object$feature_names, colnames(new_df))
    if (length(missing_vars) > 0) {
      stop(paste("The following predictor variables are missing in `new_data`:",
                 paste(missing_vars, collapse = ", ")), call. = FALSE)
    }
    X_new <- new_df[, object$feature_names, drop = FALSE]
  }
  # Fits made before the intercept was introduced carry no such element; they
  # always had at least one tree, where the intercept is zero anyway.
  intercept <- if (is.null(object$intercept)) 0 else object$intercept
  raw_preds <- intercept + predict_trees(object$trees, X_new)
  
  if (object$mode == "regression" || type == "numeric") {
    res <- tibble::tibble(.pred = raw_preds)
  } else if (object$mode == "classification") {
    # The engine encodes the outcome as 0/1 and fits squared error on the
    # running residuals, so the sum of leaf values already estimates
    # P(y = second level). Residual fitting can push that sum slightly outside
    # the unit interval, so it is clamped rather than passed through a link.
    probs_class2 <- pmin(pmax(raw_preds, PROB_EPS), 1 - PROB_EPS)
    probs_class1 <- 1 - probs_class2
    
    classes <- object$classes
    if (is.null(classes)) classes <- c("0", "1")
    
    if (type == "class") {
      pred_levels <- ifelse(probs_class2 >= 0.5, classes[2], classes[1])
      res <- tibble::tibble(.pred_class = factor(pred_levels, levels = classes))
    } else if (type == "prob") {
      col1 <- paste0(".pred_", classes[1])
      col2 <- paste0(".pred_", classes[2])
      
      res_list <- list()
      res_list[[col1]] <- probs_class1
      res_list[[col2]] <- probs_class2
      res <- tibble::as_tibble(res_list)
    } else {
      stop("Unsupported prediction type for classification.", call. = FALSE)
    }
  } else {
    res <- tibble::tibble(.pred = raw_preds)
  }
  
  return(res)
}

# Residual fitting can push the summed leaf values slightly outside the unit
# interval; probabilities are clamped this far from 0 and 1.
PROB_EPS <- 1e-6
