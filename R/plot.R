#' Plot Method for `figsr_fit` Models
#'
#' @description
#' `plot.figsr_fit()` visualizes individual decision trees comprising the
#' Fast Interpretable Greedy-Tree Sums (FIGS) model using 100% Base R graphics
#' (zero external package dependencies).
#'
#' Nodes are spaced from the width of their own labels, so boxes and branch
#' conditions never overlap, and each tree gets a panel width proportional to
#' the room it needs. When a tree does not fit its panel, the whole drawing is
#' scaled down -- text included -- rather than clipped; enlarge the device to
#' get larger text.
#'
#' @param x A fitted `figsr_fit` model object.
#' @param tree_idx Optional integer vector specifying indices of trees to plot. Default is `NULL` (plots all trees).
#' @param style Character string specifying the visual style: `"scientific"`
#'   (default, scientific/editorial notation), `"modern"` (rounded pastel boxes),
#'   or `"classic"` (high-contrast minimalist statistical style).
#' @param main Optional character string. An overall title drawn once above
#'   every tree panel. Default is `NULL` (no overall title, the previous
#'   behavior).
#' @param tree_names Optional character vector overriding the per-tree panel
#'   titles (`"Subtree f_1(x)"`, `"Tree 1"`, ...). Either a single string,
#'   applied to every plotted tree, or a vector with one entry per tree in
#'   `x$trees` -- indexed by each tree's position in the fit, not by plotting
#'   order, so it stays correct when `tree_idx` only plots some of them. `NA`
#'   in a given position falls back to the default title for that tree only.
#'   Default is `NULL` (the previous, automatic titles).
#' @param ... Additional arguments, currently ignored.
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
#' plot(fit, main = "FIGS tree sum", tree_names = "one tree of the sum")
plot.figsr_fit <- function(x, tree_idx = NULL, style = c("scientific", "modern", "classic"),
                           main = NULL, tree_names = NULL, ...) {
  style <- match.arg(style)

  if (length(x$trees) == 0) {
    message("Model contains no trees to plot.")
    return(invisible(NULL))
  }

  target_trees <- if (is.null(tree_idx)) seq_along(x$trees) else tree_idx
  # `NA` and fractional indices would otherwise reach `x$trees[[.]]` and fail
  # with an internal error instead of the message below.
  target_trees <- suppressWarnings(as.integer(target_trees))
  target_trees <- target_trees[!is.na(target_trees) &
                                 target_trees >= 1 &
                                 target_trees <= length(x$trees)]

  if (length(target_trees) == 0) {
    stop("Invalid `tree_idx` specified.", call. = FALSE)
  }

  if (!is.null(main) && (length(main) != 1L || is.na(main))) {
    stop("`main` must be a single string.", call. = FALSE)
  }

  # Resolved once per tree in the fit, indexed by that tree's own position,
  # so it stays correct however `tree_idx` subsets what actually gets drawn.
  tree_titles <- rep(NA_character_, length(x$trees))
  if (!is.null(tree_names)) {
    if (length(tree_names) == 1L) {
      tree_titles[] <- tree_names
    } else if (length(tree_names) == length(x$trees)) {
      tree_titles <- as.character(tree_names)
    } else {
      stop(paste0("`tree_names` must be NULL, a single string, or a character ",
                  "vector of length ", length(x$trees),
                  " (one per tree in the fit)."), call. = FALSE)
    }
  }

  n_trees <- length(target_trees)

  # Save user's original par settings and restore on exit
  old_par <- graphics::par(no.readonly = TRUE)
  on.exit(graphics::par(old_par))

  n_cols <- min(n_trees, 3)
  n_rows <- ceiling(n_trees / n_cols)
  panel_mar <- c(1.5, 1.5, 3, 1.5)

  # Each column is as wide as the widest tree drawn in it (or its title), so
  # a deep tree is not squeezed into the same width as a single split.
  # Widths only matter relative to each other, so measuring at the current
  # `cex` is fine even though the layout may shrink it afterwards.
  lays <- lapply(target_trees, function(t_idx) layout_tree_base(x$trees[[t_idx]], style))
  need_w <- vapply(seq_len(n_trees), function(i) {
    ttl <- panel_title(style, target_trees[i], tree_titles[target_trees[i]])
    max(max(lays[[i]]$right) - min(lays[[i]]$left),
        graphics::strwidth(ttl, units = "inches", cex = 1.1, font = 2))
  }, numeric(1))
  # Every panel spans the depth of the deepest tree, so all trees share one
  # vertical scale and their roots line up.
  n_levels <- max(vapply(lays, function(lay) max(lay$nodes$depth), numeric(1)))
  need_w <- need_w + sum(panel_mar[c(2, 4)]) * graphics::par("csi")
  need_w <- matrix(c(need_w, rep(0, n_rows * n_cols - n_trees)),
                   nrow = n_rows, ncol = n_cols, byrow = TRUE)

  panels <- matrix(c(seq_len(n_trees), rep(0L, n_rows * n_cols - n_trees)),
                   nrow = n_rows, ncol = n_cols, byrow = TRUE)
  graphics::layout(panels, widths = apply(need_w, 2, max))

  # An overall title needs room reserved in the outer margin; without one,
  # the layout is exactly what it was before this argument existed.
  outer_margin <- if (is.null(main)) c(0, 0, 0, 0) else c(0, 0, 3, 0)
  graphics::par(mar = panel_mar, oma = outer_margin)

  for (t_idx in target_trees) {
    tree <- x$trees[[t_idx]]
    plot_single_tree_base(tree, t_idx, style = style, mode = x$mode,
                          title_override = tree_titles[t_idx], n_levels = n_levels)
  }

  if (!is.null(main)) {
    graphics::mtext(main, outer = TRUE, side = 3, line = 0.5, cex = 1.3, font = 2)
  }

  return(invisible(NULL))
}

# Panel title for tree `tree_num`: `title_override` when not NA, otherwise the
# style's default.
panel_title <- function(style, tree_num, title_override = NA_character_) {
  if (!is.na(title_override)) return(title_override)
  if (style == "scientific") sprintf("Subtree f_%d(x)", tree_num) else sprintf("Tree %d", tree_num)
}

# Branch condition labels of a split node, left then right.
edge_labels <- function(node) {
  if (isTRUE(node$split_on_missing)) {
    return(c("missing", "observed"))
  }
  if (isTRUE(node$is_factor)) {
    lbl <- c(paste(node$split_val, collapse = ","), "other")
  } else {
    lbl <- c(sprintf("<= %.1f", node$split_val), sprintf("> %.1f", node$split_val))
  }
  # Edge labels stay ASCII: "NA" marks the side missing values take.
  na_dir <- node$na_dir
  if (!is.null(na_dir) && !is.na(na_dir)) {
    side <- if (na_dir == "left") 1L else 2L
    lbl[side] <- paste0(lbl[side], ", NA")
  }
  lbl
}

# Lays a tree out in inches at the current `par("cex")`, so that no two boxes
# or branch tags overlap. Each split places its right subtree just far enough
# from its left one that their contours -- the outermost box edge at every
# level, branch tags included -- clear each other by `gap`, and far enough
# that its own two branch tags clear each other too.
#
# Levels count in half steps: a node at depth `d` sits on level `2 * d`, the
# tags of its branches on level `2 * d + 1`. Returns `nodes` and `edges` data
# frames (x relative to the root, half-widths `hw` and half-heights `hh` of
# each box) and the `left`/`right` contours, named by level.
layout_tree_base <- function(tree, style) {
  gap <- 0.08
  font_tag  <- if (style == "scientific") 2 else 1
  font_leaf <- if (style == "classic") 1 else 2

  box_size <- function(lbl, cex, font, pad_x, pad_y) {
    c(hw = graphics::strwidth(lbl, units = "inches", cex = cex, font = font) / 2 + pad_x,
      hh = graphics::strheight(lbl, units = "inches", cex = cex, font = font) / 2 + pad_y)
  }
  merge_contour <- function(a, b, f) {
    lv <- union(names(a), names(b))
    vapply(lv, function(k) f(a[k], b[k], na.rm = TRUE), numeric(1))
  }
  shift <- function(sub, dx) {
    sub$nodes$x <- sub$nodes$x + dx
    sub$edges[c("x1", "x2", "tx")] <- sub$edges[c("x1", "x2", "tx")] + dx
    sub$left  <- sub$left + dx
    sub$right <- sub$right + dx
    sub
  }

  place <- function(node_id, depth) {
    # Nodes are stored at the index equal to their id.
    node <- tree[[node_id]]
    level <- as.character(2 * depth)

    if (isTRUE(node$is_leaf)) {
      sign_str <- if (node$value >= 0) "+" else ""
      # A leaf holds this tree's contribution to the sum, not the prediction.
      lbl <- if (style == "modern") sprintf("%s%.2f", sign_str, node$value)
             else sprintf("dy = %s%.2f", sign_str, node$value)
      sz <- box_size(lbl, 0.85, font_leaf, 0.06, 0.04)
      return(list(
        nodes = data.frame(type = "leaf", label = lbl, x = 0, depth = depth,
                           hw = sz[["hw"]], hh = sz[["hh"]], value = node$value),
        edges = data.frame(x1 = numeric(0), x2 = numeric(0), tx = numeric(0),
                           depth = numeric(0), label = character(0),
                           hw = numeric(0), hh = numeric(0)),
        left  = stats::setNames(-sz[["hw"]], level),
        right = stats::setNames(sz[["hw"]], level)
      ))
    }

    lsub <- place(node$left_child, depth + 1)
    rsub <- place(node$right_child, depth + 1)

    lbl <- if (style == "scientific") sprintf("[%s]", node$feature) else as.character(node$feature)
    sz <- box_size(lbl, 0.9, 2, 0.08, 0.05)
    tag_lbl <- edge_labels(node)
    tag_l <- box_size(tag_lbl[1], 0.8, font_tag, 0.05, 0.03)
    tag_r <- box_size(tag_lbl[2], 0.8, font_tag, 0.05, 0.03)

    # Distance between the two child roots. Each tag sits halfway along its
    # branch, so the tags are half as far apart as the children.
    shared <- intersect(names(lsub$right), names(rsub$left))
    d <- max(lsub$right[shared] - rsub$left[shared] + gap,
             2 * (tag_l[["hw"]] + tag_r[["hw"]] + gap))

    lsub <- shift(lsub, -d / 2)
    rsub <- shift(rsub, d / 2)

    tag_level <- as.character(2 * depth + 1)
    list(
      nodes = rbind(
        data.frame(type = "split", label = lbl, x = 0, depth = depth,
                   hw = sz[["hw"]], hh = sz[["hh"]], value = NA_real_),
        lsub$nodes, rsub$nodes
      ),
      edges = rbind(
        data.frame(x1 = 0, x2 = c(-d / 2, d / 2), tx = c(-d / 4, d / 4),
                   depth = depth, label = tag_lbl,
                   hw = c(tag_l[["hw"]], tag_r[["hw"]]),
                   hh = c(tag_l[["hh"]], tag_r[["hh"]])),
        lsub$edges, rsub$edges
      ),
      left = merge_contour(
        merge_contour(lsub$left, rsub$left, min),
        stats::setNames(c(-sz[["hw"]], -d / 4 - tag_l[["hw"]]), c(level, tag_level)),
        min
      ),
      right = merge_contour(
        merge_contour(lsub$right, rsub$right, max),
        stats::setNames(c(sz[["hw"]], d / 4 + tag_r[["hw"]]), c(level, tag_level)),
        max
      )
    )
  }

  place(1L, 0)
}

# Base R tree renderer supporting multiple visual styles. `title_override`,
# when not NA, replaces the default per-style panel title text; the style's
# own title color and font still apply. `n_levels` is the depth the panel
# spans, at least the tree's own; trees shallower than that hang from the top.
plot_single_tree_base <- function(tree, tree_num, style = "scientific", mode = "regression",
                                  title_override = NA_character_, n_levels = NULL) {
  lay <- layout_tree_base(tree, style)
  nodes <- lay$nodes
  edges <- lay$edges

  graphics::plot.new()
  pin <- graphics::par("pin")

  # Scale the whole drawing (text included) by `s` so that it fits the panel
  # both across and down; never enlarge it past its natural size. Down the
  # panel, a node box and the branch tag below it must fit in half a level.
  pad <- 0.05
  x_lo <- min(lay$left)
  x_hi <- max(lay$right)
  n_depth <- max(nodes$depth, n_levels)
  hh_node <- max(nodes$hh)
  hh_tag  <- max(edges$hh)
  s <- min(1,
           pin[1] / (x_hi - x_lo),
           (pin[2] - 2 * pad) / (2 * n_depth * (hh_node + hh_tag + 0.03) + 2 * hh_node))
  s <- max(s, 0.1)
  level_in <- max((pin[2] - 2 * (hh_node * s + pad)) / n_depth, 1e-3)
  y_pad <- (hh_node * s + pad) / level_in

  # One x unit is `s` inches, so the inch half-widths from the layout are
  # already in x units; heights are converted through `level_in`.
  half_w <- pin[1] / (2 * s)
  graphics::plot.window(xlim = (x_lo + x_hi) / 2 + c(-half_w, half_w),
                        ylim = c(-n_depth - y_pad, y_pad), xaxs = "i", yaxs = "i")
  to_y <- s / level_in

  # Configure theme palettes based on style. Leaves get a positive- and a
  # negative-value palette in "scientific" and "modern" -- green for a
  # positive contribution, red for a negative one; "classic" stays
  # monochromatic by design, so its single leaf palette serves both signs.
  if (style == "scientific") {
    col_title  <- "#0E6655"
    col_line   <- "#5D6D7E"
    lwd_line   <- 2
    bg_tag     <- "#FEF9E7"; border_tag <- "#F5B041"; text_tag <- "#7D6608"
    bg_split   <- "#EBF5FB"; border_split <- "#2E86C1"; text_split <- "#1B4F72"
    bg_leaf_pos <- "#E8F8F5"; border_leaf_pos <- "#16A085"; text_leaf_pos <- "#0E6655"
    bg_leaf_neg <- "#FDEDEC"; border_leaf_neg <- "#C0392B"; text_leaf_neg <- "#78281F"
  } else if (style == "classic") {
    col_title  <- "#2C3E50"
    col_line   <- "#34495E"
    lwd_line   <- 1.5
    bg_tag     <- "#F4F6F6"; border_tag <- "#A6ACAF"; text_tag <- "#2C3E50"
    bg_split   <- "#FFFFFF"; border_split <- "#2C3E50"; text_split <- "#2C3E50"
    bg_leaf_pos <- "#EAEDED"; border_leaf_pos <- "#7F8C8D"; text_leaf_pos <- "#17202A"
    bg_leaf_neg <- bg_leaf_pos; border_leaf_neg <- border_leaf_pos; text_leaf_neg <- text_leaf_pos
  } else { # "modern"
    col_title  <- "#1B4F72"
    col_line   <- "#85929E"
    lwd_line   <- 2
    bg_tag     <- "#FFFFFF"; border_tag <- "#BDC3C7"; text_tag <- "#2C3E50"
    bg_split   <- "#EBF5FB"; border_split <- "#2980B9"; text_split <- "#1B4F72"
    bg_leaf_pos <- "#E8F8F5"; border_leaf_pos <- "#27AE60"; text_leaf_pos <- "#117A65"
    bg_leaf_neg <- "#FDEDEC"; border_leaf_neg <- "#E74C3C"; text_leaf_neg <- "#922B21"
  }

  main_title <- panel_title(style, tree_num, title_override)
  graphics::title(main = main_title, col.main = col_title, font.main = 2, cex.main = 1.1)

  # 1. Connecting branch lines
  graphics::segments(edges$x1, -edges$depth, edges$x2, -edges$depth - 1,
                     col = col_line, lwd = lwd_line)

  # 2. Branch condition tags, halfway along each branch
  tag_y <- -edges$depth - 0.5
  graphics::rect(edges$tx - edges$hw, tag_y - edges$hh * to_y,
                 edges$tx + edges$hw, tag_y + edges$hh * to_y,
                 col = bg_tag, border = border_tag, lwd = 1)
  graphics::text(edges$tx, tag_y, labels = edges$label, cex = 0.8 * s, col = text_tag,
                 font = if (style == "scientific") 2 else 1)

  # 3. Node boxes
  for (i in seq_len(nrow(nodes))) {
    nd <- nodes[i, ]
    y <- -nd$depth
    if (nd$type == "split") {
      graphics::rect(nd$x - nd$hw, y - nd$hh * to_y, nd$x + nd$hw, y + nd$hh * to_y,
                     col = bg_split, border = border_split, lwd = 2)
      graphics::text(nd$x, y, labels = nd$label, cex = 0.9 * s, col = text_split, font = 2)
    } else {
      is_neg <- nd$value < 0
      bg_leaf     <- if (is_neg) bg_leaf_neg else bg_leaf_pos
      border_leaf <- if (is_neg) border_leaf_neg else border_leaf_pos
      text_leaf   <- if (is_neg) text_leaf_neg else text_leaf_pos

      graphics::rect(nd$x - nd$hw, y - nd$hh * to_y, nd$x + nd$hw, y + nd$hh * to_y,
                     col = bg_leaf, border = border_leaf, lwd = if (style == "classic") 1 else 2)
      graphics::text(nd$x, y, labels = nd$label, cex = 0.85 * s, col = text_leaf,
                     font = if (style == "classic") 1 else 2)
    }
  }
}
