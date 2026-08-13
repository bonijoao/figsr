#' Plot Method for `figsr_fit` Models
#'
#' @description
#' `plot.figsr_fit()` visualizes individual decision trees comprising the
#' Fast Interpretable Greedy-Tree Sums (FIGS) model using 100% Base R graphics
#' (zero external package dependencies).
#'
#' @param x A fitted `figsr_fit` model object.
#' @param tree_idx Optional integer vector specifying indices of trees to plot. Default is `NULL` (plots all trees).
#' @param style Character string specifying the visual style: `"scientific"` (default, scientific/editorial notation), `"modern"` (rounded pastel boxes), or `"classic"` (high-contrast minimalist statistical style).
#' @param ... Additional graphical parameters passed to base graphics.
#'
#' @return Invisible `NULL`.
#' @export
#' @method plot figsr_fit
#'
#' @examples
#' set.seed(42)
#' df <- data.frame(x1 = rnorm(50), x2 = rnorm(50), y = rnorm(50))
#' fit <- figs(y ~ x1 + x2, data = df, max_splits = 3)
#' plot(fit)
#' plot(fit, style = "scientific")
#' plot(fit, tree_idx = 1)
plot.figsr_fit <- function(x, tree_idx = NULL, style = "scientific", ...) {
  if (length(x$trees) == 0) {
    message("Model contains no trees to plot.")
    return(invisible(NULL))
  }
  
  target_trees <- if (is.null(tree_idx)) seq_along(x$trees) else tree_idx
  target_trees <- target_trees[target_trees >= 1 & target_trees <= length(x$trees)]
  
  if (length(target_trees) == 0) {
    stop("Invalid `tree_idx` specified.", call. = FALSE)
  }
  
  n_trees <- length(target_trees)
  
  # Save user's original par settings and restore on exit
  old_par <- graphics::par(no.readonly = TRUE)
  on.exit(graphics::par(old_par))
  
  n_cols <- min(n_trees, 3)
  n_rows <- ceiling(n_trees / n_cols)
  
  graphics::par(mfrow = c(n_rows, n_cols), mar = c(1.5, 1.5, 3, 1.5))
  
  for (t_idx in target_trees) {
    tree <- x$trees[[t_idx]]
    plot_single_tree_base(tree, t_idx, style = style, mode = x$mode)
  }
  
  return(invisible(NULL))
}

# Base R tree renderer supporting multiple visual styles
plot_single_tree_base <- function(tree, tree_num, style = "scientific", mode = "regression") {
  node_map <- list()
  for (n in tree) {
    node_map[[as.character(n$id)]] <- n
  }
  
  leaf_counter <- 0
  coords <- list()
  edges <- list()
  
  assign_coords <- function(node_id, depth) {
    node <- node_map[[as.character(node_id)]]
    if (is.null(node)) return(NULL)
    
    if (isTRUE(node$is_leaf)) {
      leaf_counter <<- leaf_counter + 1
      x_val <- as.numeric(leaf_counter)
      y_val <- as.numeric(-depth)
      
      coords[[length(coords) + 1]] <<- list(
        id = node$id, x = x_val, y = y_val, val = node$value, type = "leaf"
      )
      return(c(x = x_val, y = y_val))
    } else {
      left_pos  <- assign_coords(node$left_child, depth + 1)
      right_pos <- assign_coords(node$right_child, depth + 1)
      
      x_val <- as.numeric((left_pos["x"] + right_pos["x"]) / 2)
      y_val <- as.numeric(-depth)
      
      coords[[length(coords) + 1]] <<- list(
        id = node$id, x = x_val, y = y_val, feature = as.character(node$feature), type = "split"
      )
      
      if (isTRUE(node$is_factor)) {
        lbl_left  <- paste(node$split_val, collapse = ",")
        lbl_right <- "other"
      } else {
        lbl_left  <- sprintf("<= %.1f", node$split_val)
        lbl_right <- sprintf("> %.1f", node$split_val)
      }
      
      edges[[length(edges) + 1]] <<- list(
        x1 = x_val, y1 = y_val, x2 = as.numeric(left_pos["x"]), y2 = as.numeric(left_pos["y"]), label = lbl_left
      )
      edges[[length(edges) + 1]] <<- list(
        x1 = x_val, y1 = y_val, x2 = as.numeric(right_pos["x"]), y2 = as.numeric(right_pos["y"]), label = lbl_right
      )
      
      return(c(x = x_val, y = y_val))
    }
  }
  
  assign_coords(1, 0)
  
  xs <- sapply(coords, function(item) item$x)
  ys <- sapply(coords, function(item) item$y)
  
  x_min <- min(xs) - 0.5
  x_max <- max(xs) + 0.5
  y_min <- min(ys) - 0.6
  y_max <- max(ys) + 0.5
  
  graphics::plot(1, type = "n", xlim = c(x_min, x_max), ylim = c(y_min, y_max),
                 axes = FALSE, xlab = "", ylab = "")
  
  # Configure theme palettes based on style
  if (style == "scientific") {
    main_title <- sprintf("Subtree f_%d(x)", tree_num)
    col_title  <- "#0E6655"
    col_line   <- "#5D6D7E"
    lwd_line   <- 2
    bg_tag     <- "#FEF9E7"; border_tag <- "#F5B041"; text_tag <- "#7D6608"
    bg_split   <- "#EBF5FB"; border_split <- "#2E86C1"; text_split <- "#1B4F72"
    bg_leaf    <- "#E8F8F5"; border_leaf  <- "#16A085"; text_leaf  <- "#0E6655"
  } else if (style == "classic") {
    main_title <- sprintf("Tree %d", tree_num)
    col_title  <- "#2C3E50"
    col_line   <- "#34495E"
    lwd_line   <- 1.5
    bg_tag     <- "#F4F6F6"; border_tag <- "#A6ACAF"; text_tag <- "#2C3E50"
    bg_split   <- "#FFFFFF"; border_split <- "#2C3E50"; text_split <- "#2C3E50"
    bg_leaf    <- "#EAEDED"; border_leaf  <- "#7F8C8D"; text_leaf  <- "#17202A"
  } else { # "modern"
    main_title <- sprintf("Tree %d", tree_num)
    col_title  <- "#1B4F72"
    col_line   <- "#85929E"
    lwd_line   <- 2
    bg_tag     <- "#FFFFFF"; border_tag <- "#BDC3C7"; text_tag <- "#2C3E50"
    bg_split   <- "#EBF5FB"; border_split <- "#2980B9"; text_split <- "#1B4F72"
    bg_leaf    <- "#E8F8F5"; border_leaf  <- "#27AE60"; text_leaf  <- "#117A65"
  }
  
  graphics::title(main = main_title, col.main = col_title, font.main = 2, cex.main = 1.1)
  
  # 1. Connecting branch lines
  for (e in edges) {
    graphics::lines(c(e$x1, e$x2), c(e$y1, e$y2), col = col_line, lwd = lwd_line)
  }
  
  # 2. Branch condition tags
  for (e in edges) {
    mx <- (e$x1 + e$x2) / 2
    my <- (e$y1 + e$y2) / 2
    
    tw <- max(graphics::strwidth(e$label, cex = 0.8) * 0.60 + 0.08, 0.18)
    th <- max(graphics::strheight(e$label, cex = 0.8) * 0.60 + 0.05, 0.09)
    
    graphics::rect(mx - tw, my - th, mx + tw, my + th, col = bg_tag, border = border_tag, lwd = 1)
    graphics::text(mx, my, labels = e$label, cex = 0.8, col = text_tag, font = if(style == "scientific") 2 else 1)
  }
  
  # 3. Node boxes
  for (nd in coords) {
    if (nd$type == "split") {
      lbl <- if (style == "scientific") sprintf("[%s]", nd$feature) else nd$feature
      tw <- max(graphics::strwidth(lbl, cex = 0.9, font = 2) * 0.60 + 0.12, 0.25)
      th <- max(graphics::strheight(lbl, cex = 0.9, font = 2) * 0.60 + 0.08, 0.11)
      
      graphics::rect(nd$x - tw, nd$y - th, nd$x + tw, nd$y + th, col = bg_split, border = border_split, lwd = 2)
      graphics::text(nd$x, nd$y, labels = lbl, cex = 0.9, col = text_split, font = 2)
    } else {
      sign_str <- if (nd$val >= 0) "+" else ""
      if (style == "scientific") {
        lbl <- sprintf("dy = %s%.2f", sign_str, nd$val)
      } else if (style == "classic") {
        lbl <- sprintf("y = %.2f", nd$val)
      } else {
        lbl <- sprintf("%s%.2f", sign_str, nd$val)
      }
      
      tw <- max(graphics::strwidth(lbl, cex = 0.85, font = 2) * 0.60 + 0.10, 0.22)
      th <- max(graphics::strheight(lbl, cex = 0.85, font = 2) * 0.60 + 0.08, 0.11)
      
      graphics::rect(nd$x - tw, nd$y - th, nd$x + tw, nd$y + th, col = bg_leaf, border = border_leaf, lwd = if(style == "classic") 1 else 2)
      graphics::text(nd$x, nd$y, labels = lbl, cex = 0.85, col = text_leaf, font = if(style == "classic") 1 else 2)
    }
  }
}
