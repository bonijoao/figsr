#' Calculate Variable Importance for a `figsr_fit` Model
#'
#' @description
#' `figsr_importance()` computes the total reduction in residual impurity (Sum of Squares gain)
#' attributable to each predictor feature across all trees in the fitted FIGS model.
#'
#' @details
#' Each split node stores the reduction in residual sum of squares it achieved at
#' the moment it was chosen. Importance for a feature is the sum of those gains
#' over every split made on that feature, across all trees in the sum. Features
#' never selected receive a gain of zero.
#'
#' @param object A fitted `figsr_fit` model object.
#' @param relative Logical. If `TRUE` (default), the `importance` column is
#'   rescaled to percentages of the total gain; otherwise it repeats the raw gain.
#'
#' @return A `tibble` with one row per predictor and columns `feature`, `gain`
#'   (raw sum-of-squares reduction) and `importance`, sorted by decreasing
#'   importance.
#' @export
#'
#' @examples
#' set.seed(42)
#' df <- data.frame(x1 = rnorm(50), x2 = rnorm(50))
#' df$y <- 2 * (df$x1 > 0) + rnorm(50, sd = 0.2)
#' fit <- figs(y ~ x1 + x2, data = df, max_splits = 3)
#' figsr_importance(fit)
figsr_importance <- function(object, relative = TRUE) {
  if (!inherits(object, "figsr_fit")) {
    stop("`object` must be a fitted `figsr_fit` model.", call. = FALSE)
  }

  feats <- object$feature_names
  importance_scores <- stats::setNames(numeric(length(feats)), feats)

  for (tree in object$trees) {
    for (node in tree) {
      if (isTRUE(node$is_leaf) || is.null(node$feature)) next
      feat_name <- node$feature
      if (feat_name %in% feats) {
        importance_scores[feat_name] <-
          importance_scores[feat_name] + max(node$gain, 0)
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
  )

  res[order(res$importance, decreasing = TRUE), , drop = FALSE]
}
