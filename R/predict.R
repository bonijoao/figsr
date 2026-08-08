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
predict_figs <- function(object, new_data, type = "numeric", ...) {
  new_df <- as.data.frame(new_data)
  
  # Ensure all feature names exist in new_data
  missing_vars <- setdiff(object$feature_names, colnames(new_df))
  if (length(missing_vars) > 0) {
    stop(paste("The following predictor variables are missing in `new_data`:", 
               paste(missing_vars, collapse = ", ")), call. = FALSE)
  }
  
  X_new <- new_df[, object$feature_names, drop = FALSE]
  raw_preds <- predict_trees(object$trees, X_new)
  
  if (object$mode == "regression" || type == "numeric") {
    res <- tibble::tibble(.pred = raw_preds)
  } else if (object$mode == "classification") {
    # Logistic sigmoid mapping for binary probabilities
    probs_class2 <- 1 / (1 + exp(-raw_preds))
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
