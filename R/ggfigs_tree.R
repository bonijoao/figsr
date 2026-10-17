# ggfigs(type = "tree") and ggfigs(type = "waterfall").

# Lay out one tree (a flat node list, id == index) as `nodes`, `edges` and,
# for the hover overlay, `paths`: one row per (leaf, ancestor edge).
layout_tree <- function(tree, digits = 3, leaf_gap = 1, level_gap = 1.45,
                        shrink = 0.88) {
  n_nodes <- length(tree)
  depth  <- integer(n_nodes)
  parent <- rep(NA_integer_, n_nodes)
  side   <- rep(NA_character_, n_nodes)

  walk <- function(id, d) {
    depth[id] <<- d
    nd <- tree[[id]]
    if (!nd$is_leaf) {
      parent[nd$left_child]  <<- id
      side[nd$left_child]    <<- "left"
      parent[nd$right_child] <<- id
      side[nd$right_child]   <<- "right"
      walk(nd$left_child, d + 1)
      walk(nd$right_child, d + 1)
    }
  }
  walk(1L, 0L)

  # x: leaves in traversal order, internal nodes centred over their children
  x <- numeric(n_nodes)
  leaf_counter <- 0
  assign_x <- function(id) {
    nd <- tree[[id]]
    if (nd$is_leaf) {
      leaf_counter <<- leaf_counter + 1
      x[id] <<- leaf_counter * leaf_gap
    } else {
      assign_x(nd$left_child)
      assign_x(nd$right_child)
      x[id] <<- (x[nd$left_child] + x[nd$right_child]) / 2
    }
    invisible(NULL)
  }
  assign_x(1L)

  # Without this every internal node inherits the full width of its subtree
  # and the legs splay. Pull each child towards its parent, a little more at
  # every level, which narrows the angle and brings sibling leaves together.
  tighten <- function(id, new_x) {
    nd <- tree[[id]]
    old <- x[id]
    x[id] <<- new_x
    if (!nd$is_leaf) {
      for (ch in c(nd$left_child, nd$right_child)) {
        tighten(ch, new_x + (x[ch] - old) * shrink)
      }
    }
    invisible(NULL)
  }
  tighten(1L, x[1L])

  rule <- rep("", n_nodes)
  walk_rule <- function(id, acc) {
    rule[id] <<- acc
    nd <- tree[[id]]
    if (!nd$is_leaf) {
      sep <- if (nchar(acc)) "<br>and " else ""
      walk_rule(nd$left_child, paste0(acc, sep, split_clause(nd, TRUE, digits)))
      walk_rule(nd$right_child, paste0(acc, sep, split_clause(nd, FALSE, digits)))
    }
  }
  walk_rule(1L, "")

  nodes <- data.frame(
    id      = seq_len(n_nodes),
    x       = x,
    y       = -depth * level_gap,
    is_leaf = vapply(tree, function(nd) isTRUE(nd$is_leaf), logical(1)),
    value   = vapply(tree, function(nd) as.numeric(nd$value), numeric(1)),
    gain    = vapply(tree, function(nd) as.numeric(nd$gain), numeric(1)),
    n       = vapply(tree, function(nd) length(nd$sample_indices), integer(1)),
    label   = vapply(tree, function(nd) {
      if (nd$is_leaf) fmt_num(nd$value, digits) else split_label(nd, digits, TRUE)
    }, character(1)),
    rule    = rule,
    stringsAsFactors = FALSE
  )

  has_parent <- !is.na(parent)
  edges <- data.frame(
    child = nodes$id[has_parent],
    x     = nodes$x[parent[has_parent]],
    y     = nodes$y[parent[has_parent]],
    xend  = nodes$x[has_parent],
    yend  = nodes$y[has_parent],
    n     = nodes$n[has_parent],
    side  = side[has_parent],
    stringsAsFactors = FALSE
  )

  paths <- do.call(rbind, lapply(nodes$id[nodes$is_leaf], function(lf) {
    path <- integer(0)
    cur <- lf
    while (!is.na(parent[cur])) {
      path <- c(path, cur)
      cur <- parent[cur]
    }
    e <- edges[edges$child %in% path, , drop = FALSE]
    if (!nrow(e)) return(NULL)
    e$leaf <- lf
    e
  }))

  list(nodes = nodes, edges = edges, paths = paths)
}

ggfigs_tree <- function(x, tree_idx = NULL, digits = 3, interactive = FALSE,
                        width_svg = 10, height_svg = 5.5) {
  if (length(x$trees) == 0) {
    stop("the model has no trees to show.", call. = FALSE)
  }
  idx <- if (is.null(tree_idx)) seq_along(x$trees) else tree_idx
  if (!is.numeric(idx) || any(idx < 1 | idx > length(x$trees))) {
    stop(sprintf("`tree_idx` must be between 1 and %d.", length(x$trees)),
         call. = FALSE)
  }

  lays <- lapply(idx, function(i) layout_tree(x$trees[[i]], digits))
  lab  <- vapply(idx, f_label, character(1))

  # coord_fixed() does not combine with free facet scales, and without it
  # ggplot2 rescales x and reopens the legs. So the trees share one panel,
  # shifted along x, with their titles drawn as text.
  spans   <- vapply(lays, function(l) diff(range(l$nodes$x)), numeric(1))
  gap     <- max(1.6, 0.18 * max(spans))
  offsets <- cumsum(c(0, spans[-length(spans)] + gap))

  bind <- function(part) {
    do.call(rbind, lapply(seq_along(lays), function(k) {
      d <- lays[[k]][[part]]
      if (is.null(d) || !nrow(d)) return(NULL)
      shift <- offsets[k] - min(lays[[k]]$nodes$x)
      for (v in intersect(c("x", "xend"), names(d))) d[[v]] <- d[[v]] + shift
      # the overlay's data_id must equal the leaf's, or hovering the leaf
      # does not light its path
      d$uid <- paste0("t", idx[k], "_",
                      if ("leaf" %in% names(d)) d$leaf
                      else if ("child" %in% names(d)) paste0("e", d$child)
                      else d$id)
      d
    }))
  }
  nd <- bind("nodes")
  ed <- bind("edges")
  pa <- bind("paths")

  heads <- data.frame(x = offsets + spans / 2, y = max(nd$y) + 0.95,
                      label = lab, stringsAsFactors = FALSE)

  leaves <- nd[nd$is_leaf, , drop = FALSE]
  inner  <- nd[!nd$is_leaf, , drop = FALSE]
  leaves$tip <- sprintf(
    "<b>Leaf</b><br>contribution: <b>%s</b><br>n = %d<br><br><i>%s</i>",
    fmt_num(leaves$value, digits), leaves$n, leaves$rule)
  inner$tip <- sprintf(
    "<b>Split</b><br>%s<br>n = %d<br>SSE gain = %s%s",
    gsub("\n", " ", inner$label), inner$n, fmt_num(inner$gain, digits),
    ifelse(nchar(inner$rule), paste0("<br><br><i>", inner$rule, "</i>"), ""))

  lim <- max(abs(leaves$value), 1e-12)
  root_edges <- ed[ed$y == 0, , drop = FALSE]
  root_edges$txt <- ifelse(root_edges$side == "left", "yes", "no")

  p <- ggplot2::ggplot() +
    ggplot2::geom_segment(
      data = ed,
      ggplot2::aes(x = .data$x, y = .data$y, xend = .data$xend,
                   yend = .data$yend, linewidth = .data$n),
      colour = FIGS_PAL$edge, lineend = "round")
  if (interactive && !is.null(pa)) {
    # invisible path overlay; it lights up when its leaf is hovered
    p <- p + ggiraph::geom_segment_interactive(
      data = pa,
      ggplot2::aes(x = .data$x, y = .data$y, xend = .data$xend,
                   yend = .data$yend, data_id = .data$uid),
      colour = FIGS_PAL$ink, linewidth = 1.2, alpha = 0, lineend = "round")
  }
  p <- p +
    ggplot2::geom_text(
      data = root_edges,
      ggplot2::aes(x = (.data$x + .data$xend) / 2, y = (.data$y + .data$yend) / 2,
                   label = .data$txt),
      colour = FIGS_PAL$muted, size = 2.6, fontface = "italic", vjust = -0.5) +
    geom_figs("geom_label", interactive,
      ggplot2::aes(x = .data$x, y = .data$y, label = .data$label,
                   tooltip = .data$tip, data_id = .data$uid),
      data = inner, fill = FIGS_PAL$node_fill, colour = FIGS_PAL$ink,
      linewidth = 0, label.r = ggplot2::unit(7, "pt"),
      label.padding = ggplot2::unit(4.4, "pt"), size = 2.8) +
    geom_figs("geom_label", interactive,
      ggplot2::aes(x = .data$x, y = .data$y, label = .data$label,
                   fill = .data$value, tooltip = .data$tip,
                   data_id = .data$uid),
      data = leaves, colour = FIGS_PAL$ink, linewidth = 0,
      label.r = ggplot2::unit(7, "pt"),
      label.padding = ggplot2::unit(4.2, "pt"), size = 2.8) +
    ggplot2::geom_text(
      data = heads,
      ggplot2::aes(x = .data$x, y = .data$y, label = .data$label),
      colour = FIGS_PAL$ink_2, size = 3.6, fontface = "italic") +
    ggplot2::scale_linewidth_continuous(range = c(0.3, 1.7), guide = "none") +
    ggplot2::scale_fill_gradient2(
      low = FIGS_PAL$div_low, mid = FIGS_PAL$div_mid, high = FIGS_PAL$div_high,
      midpoint = 0, limits = c(-lim, lim),
      name = "leaf value: what it adds to the sum") +
    ggplot2::guides(fill = ggplot2::guide_colourbar(
      barheight = ggplot2::unit(5, "pt"), barwidth = ggplot2::unit(90, "pt"),
      ticks.colour = NA, title.position = "top")) +
    ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = 0.14)) +
    ggplot2::scale_x_continuous(expand = ggplot2::expansion(mult = 0.1)) +
    ggplot2::coord_fixed(ratio = 1, clip = "off") +
    ggplot2::labs(
      title = "FIGS tree sum",
      subtitle = sprintf(
        "%d tree%s, %d split%s -- the prediction is the sum of one leaf per tree%s",
        length(x$trees), if (length(x$trees) == 1) "" else "s",
        x$total_splits, if (x$total_splits == 1) "" else "s",
        if (x$mode == "classification")
          sprintf(", read as P(y = \"%s\")", x$classes[2]) else ""),
      caption = paste0("leaf labels are the values added to the sum; edge ",
                       "width scales with the number of observations",
                       if (interactive) "\nhover a leaf to trace its route" else "")) +
    theme_figs()

  if (!interactive) return(p)

  # Hover CSS scoped per element type: a global `stroke` would also outline
  # the label glyphs and make the text unreadable.
  figs_girafe(p, width_svg, height_svg,
              hover_css = ggiraph::girafe_css(
                css  = "cursor:pointer;",
                text = "stroke:none;",
                area = paste0("stroke:", FIGS_PAL$ink_2, ";stroke-width:0.5px;"),
                line = "stroke-opacity:1;stroke-width:1.1px;"),
              hover_inv_css = "opacity:0.32;")
}

# Route a single observation down one tree; return its leaf value and rule.
descend_one <- function(tree, row, digits = 3) {
  nd <- tree[[1]]
  path <- character(0)
  repeat {
    if (nd$is_leaf) {
      return(list(value = as.numeric(nd$value),
                  rule = paste(path, collapse = "<br>and ")))
    }
    v <- row[[nd$feature]]
    go_left <- if (isTRUE(nd$split_on_missing)) {
      is.na(v)
    } else if (is.na(v)) {
      identical(nd$na_dir, "left")
    } else if (isTRUE(nd$is_factor)) {
      as.character(v) %in% as.character(nd$split_val)
    } else {
      v <= nd$split_val
    }
    path <- c(path, split_clause(nd, go_left, digits))
    nd <- tree[[if (go_left) nd$left_child else nd$right_child]]
  }
}

ggfigs_waterfall <- function(x, newdata, digits = 3, interactive = FALSE,
                             width_svg = 8, height_svg = 4.6) {
  if (is.null(newdata)) {
    stop("`type = \"waterfall\"` needs `newdata =`, a single observation.",
         call. = FALSE)
  }
  mf <- stats::model.frame(stats::delete.response(x$terms),
                           as.data.frame(newdata), xlev = x$xlevels,
                           na.action = stats::na.pass)
  if (nrow(mf) != 1L) {
    stop("`newdata` must have exactly one row.", call. = FALSE)
  }
  row <- as.list(mf[1, , drop = FALSE])

  contrib <- lapply(x$trees, descend_one, row = row, digits = digits)
  vals  <- vapply(contrib, function(cc) cc$value, numeric(1))
  labs  <- vapply(seq_along(x$trees), f_label, character(1))
  rules <- vapply(contrib, function(cc) cc$rule, character(1))
  # the intercept is 0 whenever at least one tree exists; a zero bar is noise
  if (abs(x$intercept) > 1e-12 || !length(x$trees)) {
    vals  <- c(x$intercept, vals)
    labs  <- c("intercept", labs)
    rules <- c("model baseline (no split was accepted)", rules)
  }

  cum   <- cumsum(vals)
  start <- c(0, cum[-length(cum)])
  total <- cum[length(cum)]

  d <- data.frame(
    step  = factor(c(labs, "prediction"), levels = c(labs, "prediction")),
    i     = seq_len(length(vals) + 1),
    start = c(start, 0),
    end   = c(cum, total),
    delta = c(vals, total),
    rule  = c(rules, "sum of the above"),
    kind  = c(rep("step", length(vals)), "total"),
    stringsAsFactors = FALSE
  )
  d$ymin <- pmin(d$start, d$end)
  d$ymax <- pmax(d$start, d$end)
  d$tip <- sprintf("<b>%s</b><br>%s: <b>%s</b><br><br><i>%s</i>",
                   d$step, ifelse(d$kind == "total", "prediction", "contribution"),
                   fmt_num(d$delta, digits), d$rule)
  d$fill <- ifelse(d$kind == "total", FIGS_PAL$ink_2,
                   ifelse(d$delta >= 0, FIGS_PAL$div_high, FIGS_PAL$div_low))
  d$txt <- ifelse(d$kind == "total", fmt_num(d$delta, digits),
                  fmt_signed(d$delta, digits))
  rng <- diff(range(c(d$ymin, d$ymax)))
  d$label_y <- d$ymax + rng * 0.045

  n <- nrow(d)
  conn <- data.frame(x = d$i[-n] + 0.33, xend = d$i[-1] - 0.33,
                     y = d$end[-n], yend = d$end[-n])

  p <- ggplot2::ggplot(d) +
    ggplot2::geom_hline(yintercept = 0, colour = FIGS_PAL$baseline,
                        linewidth = 0.4) +
    ggplot2::geom_segment(
      data = conn,
      ggplot2::aes(x = .data$x, xend = .data$xend, y = .data$y,
                   yend = .data$yend),
      colour = FIGS_PAL$baseline, linetype = "22", linewidth = 0.45) +
    geom_figs("geom_rect", interactive,
      ggplot2::aes(xmin = .data$i - 0.33, xmax = .data$i + 0.33,
                   ymin = .data$ymin, ymax = .data$ymax, fill = .data$fill,
                   tooltip = .data$tip, data_id = .data$step),
      colour = FIGS_PAL$surface, linewidth = 0.8) +
    ggplot2::geom_text(
      ggplot2::aes(x = .data$i, y = .data$label_y, label = .data$txt),
      colour = FIGS_PAL$ink_2, size = 3, fontface = "bold") +
    ggplot2::scale_fill_identity() +
    ggplot2::scale_x_continuous(breaks = d$i, labels = levels(d$step),
                                expand = ggplot2::expansion(add = 0.5)) +
    ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = c(0.08, 0.14))) +
    ggplot2::labs(
      title = "Where this prediction comes from",
      subtitle = paste("each tree of the sum contributes the value of the",
                       "single leaf the observation lands on"),
      x = NULL, y = NULL,
      caption = if (interactive)
        "hover a bar for the rule that routed this observation to that leaf") +
    theme_figs() +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(colour = FIGS_PAL$ink_2, size = 9,
                                          margin = ggplot2::margin(t = 5)),
      axis.text.y = ggplot2::element_text(colour = FIGS_PAL$muted, size = 8,
                                          hjust = 1),
      panel.grid.major.y = ggplot2::element_line(colour = FIGS_PAL$grid,
                                                 linewidth = 0.3))

  if (!interactive) return(p)
  figs_girafe(p, width_svg, height_svg, hover_css = "fill-opacity:1;",
              hover_inv_css = "opacity:0.25;")
}
