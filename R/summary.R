#' Print Method for `figsr_fit` Models
#'
#' @param x A `figsr_fit` object.
#' @param ... Additional arguments, currently ignored.
#'
#' @return `x`, invisibly. Called for the side effect of printing a summary of
#'   the fitted tree sum to the console.
#' @export
#' @method print figsr_fit
#'
#' @examples
#' set.seed(42)
#' df <- data.frame(x1 = rnorm(60), x2 = rnorm(60))
#' df$y <- 2 * (df$x1 > 0) + rnorm(60, sd = 0.2)
#' print(figs(y ~ x1 + x2, data = df, max_splits = 3))
print.figsr_fit <- function(x, ...) {
  cat("========================================================\n")
  cat("  FIGS: Fast Interpretable Greedy-Tree Sums Model\n")
  cat("========================================================\n")
  cat(sprintf("Mode              : %s\n", x$mode))
  cat(sprintf("Total Trees       : %d\n", length(x$trees)))
  cat(sprintf("Total Splits      : %d / %d (max_splits)\n", x$total_splits, x$max_splits))
  cat(sprintf("Predictors Used   : %s\n", paste(x$feature_names, collapse = ", ")))
  cat("========================================================\n\n")
  cat("Use `summary(fit)` to display detailed decision rules.\n")
  cat("Use `plot(fit)` to visualize decision tree structures.\n")
  invisible(x)
}

#' Summary Method for `figsr_fit` Models
#'
#' @description
#' `summary.figsr_fit()` prints human-readable decision rules for each tree in the sum.
#'
#' @param object A `figsr_fit` object.
#' @param ... Additional arguments, currently ignored.
#'
#' @return `object`, invisibly. Called for the side effect of printing the
#'   IF-THEN decision rules of each tree to the console.
#' @export
#' @method summary figsr_fit
#'
#' @examples
#' set.seed(42)
#' df <- data.frame(x1 = rnorm(60), x2 = rnorm(60))
#' df$y <- 2 * (df$x1 > 0) + rnorm(60, sd = 0.2)
#' summary(figs(y ~ x1 + x2, data = df, max_splits = 3))
summary.figsr_fit <- function(object, ...) {
  cat("========================================================\n")
  cat("  FIGS Model Summary: Tree Sum Decision Rules\n")
  cat("========================================================\n\n")
  
  if (length(object$trees) == 0) {
    cat("No splits performed (empty tree model).\n")
    return(invisible(object))
  }
  
  for (t_idx in seq_along(object$trees)) {
    tree <- object$trees[[t_idx]]
    cat(sprintf("--- Tree %d ---\n", t_idx))
    print_tree_rules(tree[[1]], tree, indent = "  ")
    cat("\n")
  }
  
  invisible(object)
}

# Recursive helper to print tree rules
print_tree_rules <- function(node, tree, indent = "") {
  if (node$is_leaf) {
    cat(sprintf("%s`-- Leaf Value: %+.4f\n", indent, node$value))
    return()
  }
  
  if (isTRUE(node$is_factor)) {
    cond_left  <- sprintf("IF %s IN (%s)", node$feature, paste(node$split_val, collapse = ", "))
    cond_right <- sprintf("IF %s NOT IN (%s)", node$feature, paste(node$split_val, collapse = ", "))
  } else {
    cond_left  <- sprintf("IF %s <= %.3f", node$feature, node$split_val)
    cond_right <- sprintf("IF %s >  %.3f", node$feature, node$split_val)
  }
  
  cat(sprintf("%s|-- %s\n", indent, cond_left))
  print_tree_rules(tree[[node$left_child]], tree, indent = paste0(indent, "|   "))

  cat(sprintf("%s`-- %s\n", indent, cond_right))
  print_tree_rules(tree[[node$right_child]], tree, indent = paste0(indent, "   "))
}
