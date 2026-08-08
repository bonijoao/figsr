#' Plot Method for `figsr_fit` Models
#'
#' @description
#' `plot.figsr_fit()` creates visual diagrams of the individual decision trees comprising
#' the FIGS sum model using `ggplot2` and `patchwork`.
#'
#' @param x A fitted `figsr_fit` model object.
#' @param ... Additional graphical arguments.
#'
#' @return A `ggplot` or `patchwork` combined object.
#' @export
#' @method plot figsr_fit
#'
#' @examples
#' set.seed(42)
#' df <- data.frame(x1 = rnorm(50), x2 = rnorm(50), y = rnorm(50))
#' fit <- figs(y ~ x1 + x2, data = df, max_splits = 3)
#' plot(fit)
plot.figsr_fit <- function(x, ...) {
  if (length(x$trees) == 0) {
    message("Model contains no trees to plot.")
    return(invisible(NULL))
  }
  
  plots <- list()
  for (t_idx in seq_along(x$trees)) {
    tree <- x$trees[[t_idx]]
    plots[[t_idx]] <- plot_single_tree(tree, t_idx)
  }
  
  if (length(plots) == 1) {
    return(plots[[1]])
  } else {
    combined <- patchwork::wrap_plots(plots, ncol = min(length(plots), 3))
    return(combined)
  }
}

# Helper to plot a single tree object with ggplot2
plot_single_tree <- function(tree, tree_num) {
  # Build simple node summary table
  nodes_df <- list()
  for (n_idx in seq_along(tree)) {
    node <- tree[[n_idx]]
    if (node$is_leaf) {
      lbl <- sprintf("Leaf\nval: %.2f", node$value)
    } else {
      if (isTRUE(node$is_factor)) {
        lbl <- sprintf("Split: %s\nin (%s)", node$feature, paste(node$split_val, collapse = ","))
      } else {
        lbl <- sprintf("Split: %s\n<= %.2f", node$feature, node$split_val)
      }
    }
    nodes_df[[n_idx]] <- data.frame(id = node$id, is_leaf = node$is_leaf, label = lbl)
  }
  df <- do.call(rbind, nodes_df)
  df$x <- seq_len(nrow(df))
  df$y <- ifelse(df$is_leaf, 1, 2)
  
  p <- ggplot2::ggplot(df, ggplot2::aes(x = .data$x, y = .data$y, label = .data$label)) +
    ggplot2::geom_point(ggplot2::aes(color = .data$is_leaf), size = 8, alpha = 0.7) +
    ggplot2::geom_text(size = 3, vjust = 0.5) +
    ggplot2::scale_color_manual(values = c("FALSE" = "#2b5c8f", "TRUE" = "#27a066")) +
    ggplot2::labs(
      title = sprintf("Tree %d", tree_num),
      x = "", y = ""
    ) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      axis.text = ggplot2::element_blank(),
      axis.ticks = ggplot2::element_blank(),
      panel.grid = ggplot2::element_blank(),
      legend.position = "none"
    )
  
  return(p)
}
