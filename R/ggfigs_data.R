# ggfigs(type = "cuts") and ggfigs(type = "profile"): views drawn over the
# training data, which the caller passes as `data`.

tree_colours <- function(n) {
  if (n > length(FIGS_PAL_TREE)) {
    stop(sprintf("`type = \"cuts\"` colours each tree and has %d colours; ",
                 length(FIGS_PAL_TREE)),
         sprintf("this model has %d trees.", n), call. = FALSE)
  }
  stats::setNames(FIGS_PAL_TREE[seq_len(n)],
                  vapply(seq_len(n), f_label, character(1)))
}

ggfigs_cuts <- function(x, data = NULL, digits = 3, interactive = FALSE,
                        max_points = 2000, width_svg = 10, height_svg = 5.5) {
  mf  <- figs_model_frame(x, data, "cuts")
  y   <- figs_response(x, data)
  spl <- collect_splits(x, digits)

  num <- spl[spl$numeric, , drop = FALSE]
  other <- spl[!spl$numeric, , drop = FALSE]
  if (!nrow(num)) {
    stop("`type = \"cuts\"` draws numeric cutpoints and every split of this ",
         "model is on a factor or on missingness; try `type = \"rules\"`.",
         call. = FALSE)
  }
  feats <- unique(num$feature)

  pts <- do.call(rbind, lapply(feats, function(f) {
    data.frame(feature = f, value = as.numeric(mf[[f]]), y = y,
               stringsAsFactors = FALSE)
  }))
  pts <- pts[!is.na(pts$value), , drop = FALSE]
  # thin deterministically, so drawing does not touch the RNG
  if (nrow(pts) > max_points) {
    pts <- pts[unique(round(seq(1, nrow(pts), length.out = max_points))), ]
  }
  pts$feature <- factor(pts$feature, levels = feats)
  num$feature <- factor(num$feature, levels = feats)
  num$tip <- sprintf(
    "<b>%s</b><br>tree: %s<br>n at this node: %d<br>SSE gain: %s",
    num$label, num$tree, num$n, fmt_num(num$gain, digits))
  num$uid <- paste0("cut", seq_len(nrow(num)))

  classification <- x$mode == "classification"
  # a binary outcome has no 0.3 to label; name the two classes instead
  y_scale <- if (classification) {
    ggplot2::scale_y_continuous(breaks = c(0, 1), labels = x$classes,
                                expand = ggplot2::expansion(mult = 0.18))
  } else {
    ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = 0.08))
  }
  # deterministic vertical spread for the two classes
  if (classification) {
    pts$y <- pts$y + (stats::ave(pts$y, pts$feature, pts$y,
                                 FUN = seq_along) %% 7 - 3) * 0.022
  }

  caption <- "one panel per predictor with a numeric cut"
  if (nrow(other)) {
    caption <- paste0(caption, "; not drawn, as they have no cutpoint: ",
                      paste(unique(other$label), collapse = ", "))
  }
  if (interactive) caption <- paste0(caption, "\nhover a line for the node behind it")

  p <- ggplot2::ggplot() +
    ggplot2::geom_point(
      data = pts, ggplot2::aes(x = .data$value, y = .data$y),
      colour = FIGS_PAL$muted, alpha = 0.3, size = 0.9, stroke = 0) +
    ggplot2::geom_rug(
      data = pts, ggplot2::aes(x = .data$value), sides = "b",
      colour = FIGS_PAL$baseline, alpha = 0.3,
      length = ggplot2::unit(3, "pt")) +
    geom_figs("geom_vline", interactive,
      ggplot2::aes(xintercept = .data$split_val, colour = .data$tree,
                   linewidth = .data$gain, tooltip = .data$tip,
                   data_id = .data$uid),
      data = num) +
    ggplot2::scale_colour_manual(values = tree_colours(length(x$trees)),
                                 name = NULL, drop = FALSE) +
    # the root split's gain dwarfs every later one, so compress the mapping
    ggplot2::scale_linewidth_continuous(range = c(0.4, 1.15), transform = "sqrt",
                                        guide = "none") +
    y_scale +
    ggplot2::facet_wrap(~ feature, scales = "free_x") +
    ggplot2::labs(
      title = "Where the model cut",
      subtitle = paste("every numeric split drawn on the data it was chosen",
                       "from; line width proportional to the SSE gain"),
      x = NULL,
      y = if (classification) "observed outcome" else "response",
      caption = caption) +
    theme_figs() +
    theme_figs_axes()

  if (!interactive) return(p)
  figs_girafe(p, width_svg, height_svg, hover_css = "stroke-width:3.5px;",
              hover_inv_css = "opacity:0.25;")
}

# Exact partial dependence: for each grid value, set the predictor to it in
# every row and average the predictions. The steps are the cuts.
ggfigs_profile <- function(x, data = NULL, digits = 3, interactive = FALSE,
                           grid_n = 160, features = NULL,
                           width_svg = 10, height_svg = 5.5) {
  mf  <- figs_model_frame(x, data, "profile")
  spl <- collect_splits(x, digits)
  feats <- if (is.null(features)) unique(spl$feature) else features
  feats <- intersect(feats, names(mf))
  if (!length(feats)) {
    stop("no predictor to profile; `features` must name predictors of the model.",
         call. = FALSE)
  }

  pd <- do.call(rbind, lapply(feats, function(f) {
    col <- mf[[f]]
    is_f <- is.factor(col)
    grid <- if (is_f) {
      levels(droplevels(col))
    } else {
      rng <- range(col, na.rm = TRUE)
      cp  <- spl$split_val[spl$feature == f & spl$numeric]
      sort(unique(c(seq(rng[1], rng[2], length.out = grid_n), cp)))
    }
    vals <- vapply(seq_along(grid), function(k) {
      tmp <- mf
      tmp[[f]] <- if (is_f) factor(grid[k], levels = levels(col)) else grid[k]
      mean(x$intercept + predict_trees(x$trees, tmp), na.rm = TRUE)
    }, numeric(1))
    data.frame(feature = f,
               value = if (is_f) seq_along(grid) else as.numeric(grid),
               pd = vals, stringsAsFactors = FALSE)
  }))
  pd$feature <- factor(pd$feature, levels = feats)

  cuts <- spl[spl$numeric & spl$feature %in% feats, , drop = FALSE]
  cuts$feature <- factor(cuts$feature, levels = feats)
  cuts$uid <- paste0("pcut", seq_len(nrow(cuts)))
  cuts$tip <- sprintf("<b>%s</b><br>tree: %s<br>SSE gain: %s",
                      cuts$label, cuts$tree, fmt_num(cuts$gain, digits))

  rug <- do.call(rbind, lapply(feats, function(f) {
    col <- mf[[f]]
    if (is.factor(col)) return(NULL)
    data.frame(feature = f, value = as.numeric(col), stringsAsFactors = FALSE)
  }))

  p <- ggplot2::ggplot()
  if (nrow(cuts)) {
    p <- p + geom_figs("geom_vline", interactive,
      ggplot2::aes(xintercept = .data$split_val, tooltip = .data$tip,
                   data_id = .data$uid),
      data = cuts, colour = FIGS_PAL$baseline, linetype = "22",
      linewidth = 0.45)
  }
  if (!is.null(rug)) {
    rug <- rug[!is.na(rug$value), , drop = FALSE]
    rug$feature <- factor(rug$feature, levels = feats)
    p <- p + ggplot2::geom_rug(
      data = rug, ggplot2::aes(x = .data$value), sides = "b",
      colour = FIGS_PAL$baseline, alpha = 0.3,
      length = ggplot2::unit(3, "pt"))
  }
  p <- p +
    ggplot2::geom_step(
      data = pd, ggplot2::aes(x = .data$value, y = .data$pd),
      colour = FIGS_PAL$div_low, linewidth = 0.9, direction = "hv") +
    ggplot2::facet_wrap(~ feature, scales = "free_x") +
    ggplot2::labs(
      title = "What each predictor does to the prediction",
      subtitle = paste("partial dependence: the predictor is swept over its",
                       "range in every row and the predictions averaged"),
      x = NULL,
      y = if (x$mode == "classification")
        sprintf("average P(%s)", x$classes[2]) else "average prediction",
      caption = paste("dashed lines mark the cutpoints; a step in the curve",
                      "is a cut taking effect")) +
    theme_figs() +
    theme_figs_axes()

  if (!interactive) return(p)
  figs_girafe(p, width_svg, height_svg,
              hover_css = paste0("stroke:", FIGS_PAL$ink, ";stroke-width:1.4px;"))
}
