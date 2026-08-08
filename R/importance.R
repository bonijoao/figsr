#' Calculate Variable Importance for a `figsr_fit` Model
#'
#' @description
#' `figsr_importance()` computes the total reduction in residual impurity (Sum of Squares gain)
#' attributable to each predictor feature across all trees in the fitted FIGS model.
#'
#' @param object A fitted `figsr_fit` model object.
#' @param relative Logical. If `TRUE` (default), returns importance scaled relative to the total gain (percentages).
#'
#' @return A `tibble` containing feature names, raw gain, and relative importance score.
#' @export
#'
#' @examples
#' set.seed(42)
#' df <- data.frame(x1 = rnorm(50), x2 = rnorm(50), y = rnorm(50))
#' fit <- figs(y ~ x1 + x2, data = df)
#' figsr_importance(fit)
figsr_importance <- function(object, relative = TRUE) {
  if (!inherits(object, "figsr_fit")) {
    stop("`object` must be a fitted `figsr_fit` model.", call. = FALSE)
  }
  
  feats <- object$feature_names
  importance_scores <- setNames(numeric(length(feats)), feats)
  
  for (tree in object$trees) {
    for (node in tree) {
      if (!node$is_leaf && !is.null(node$feature)) {
        feat_name <- node$feature
        # Calculate gain contribution from non-leaf nodes
        if (feat_name %in% feats) {
          importance_scores[feat_name] <- importance_scores[feat_name] + 1
        }
      }
    }
  }
  
  tot <- sum(importance_scores)
  if (relative && tot > 0) {
    rel_scores <- (importance_scores / tot) * 100
  } else {
    rel_scores <- importance_scores
  }
  
  res <- tibble::tibble(
    feature = names(importance_scores),
    gain = as.numeric(importance_scores),
    importance = as.numeric(rel_scores)
  ) |>
    dplyr::arrange(dplyr::desc(.data$importance))
  
  return(res)
}
