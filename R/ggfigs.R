#' 'ggplot2' Graphics for `figsr_fit` Models
#'
#' @description
#' `ggfigs()` draws a fitted Fast Interpretable Greedy-Tree Sums (FIGS) model
#' with 'ggplot2'. Five views are available:
#'
#' * `"tree"`: every tree of the sum as a node-link diagram, edge width
#'   proportional to the observations that flow through it and leaves filled
#'   by their contribution on a diverging scale.
#' * `"rules"`: every tree as a horizontal list of rules, with `+` between
#'   trees. Each node continues to the right through the child with more
#'   nodes below it and the other child drops down, so a tree in which every
#'   split has a leaf child reads as a single line.
#' * `"waterfall"`: where the prediction for one observation comes from, as
#'   one bar per tree accumulating to the final prediction.
#' * `"cuts"`: every numeric cutpoint drawn over the data it was chosen
#'   from, one panel per predictor.
#' * `"profile"`: the exact partial dependence of the prediction on each
#'   predictor that carries a split.
#'
#' With `interactive = FALSE` (the default) the result is an ordinary
#' `ggplot` object, ready for `ggsave()`, PDF output or further `+` layers.
#' With `interactive = TRUE` it is an HTML widget built with 'ggiraph', with
#' tooltips that show the full rule behind each node, leaf or cut; this needs
#' the 'ggiraph' package to be installed.
#'
#' `autoplot()` is the same function under the 'ggplot2' generic, and always
#' returns a `ggplot`.
#'
#' @param x,object A fitted `figsr_fit` model object.
#' @param type The view to draw: `"tree"`, `"rules"`, `"waterfall"`,
#'   `"cuts"` or `"profile"`.
#' @param data The data frame the model was fit on. Required by `"cuts"` and
#'   `"profile"`, which draw the data, and optional for `"rules"`, which then
#'   adds the outcome rate (classification) or mean (regression) to each
#'   rule. The fitted model does not store its training data.
#' @param newdata A data frame with exactly one row, the observation that
#'   `type = "waterfall"` decomposes.
#' @param tree_idx Optional integer vector of the trees to draw in
#'   `type = "tree"`. Default `NULL` draws them all.
#' @param digits Significant digits for cutpoints and leaf values.
#' @param interactive Logical. `FALSE` (default) returns a `ggplot`; `TRUE`
#'   returns a 'ggiraph' `girafe` HTML widget.
#' @param ... Further arguments for the chosen view: `width_svg` and
#'   `height_svg` (inches) size the interactive widget; `grid_n` (default
#'   160) and `features` select the grid and the predictors of `"profile"`;
#'   `max_points` (default 2000) caps the points drawn by `"cuts"`.
#'
#' @return A `ggplot` object, or a `girafe` HTML widget when
#'   `interactive = TRUE`. For `type = "rules"` the `ggplot` carries an
#'   attribute `"ggfigs_size"`, the natural `c(width, height)` of the drawing
#'   in inches, to size `ggsave()` with.
#' @seealso [plot.figsr_fit()] for the base-graphics tree diagram.
#' @importFrom rlang .data
#' @export
#'
#' @examples
#' fit <- figs(mpg ~ wt + hp + disp, data = mtcars, max_splits = 5)
#' ggfigs(fit)
#' ggfigs(fit, type = "rules", data = mtcars)
#' ggfigs(fit, type = "waterfall", newdata = mtcars[1, ])
#' ggfigs(fit, type = "cuts", data = mtcars)
#' ggfigs(fit, type = "profile", data = mtcars)
#'
#' # the 'ggplot2' generic gives the same plots
#' ggplot2::autoplot(fit, type = "rules")
#'
#' \donttest{
#' if (requireNamespace("ggiraph", quietly = TRUE)) {
#'   ggfigs(fit, type = "rules", data = mtcars, interactive = TRUE)
#' }
#' }
ggfigs <- function(x, type = c("tree", "rules", "waterfall", "cuts", "profile"),
                   data = NULL, newdata = NULL, tree_idx = NULL, digits = 3,
                   interactive = FALSE, ...) {
  type <- match.arg(type)
  if (!inherits(x, "figsr_fit")) {
    stop("`x` must be a `figsr_fit` object.", call. = FALSE)
  }
  if (!is.logical(interactive) || length(interactive) != 1L || is.na(interactive)) {
    stop("`interactive` must be TRUE or FALSE.", call. = FALSE)
  }
  if (interactive && !requireNamespace("ggiraph", quietly = TRUE)) {
    stop("`interactive = TRUE` needs the 'ggiraph' package; install it ",
         "or use `interactive = FALSE`.", call. = FALSE)
  }
  switch(type,
    tree      = ggfigs_tree(x, tree_idx, digits, interactive, ...),
    rules     = ggfigs_rules(x, data, digits, interactive, ...),
    waterfall = ggfigs_waterfall(x, newdata, digits, interactive, ...),
    cuts      = ggfigs_cuts(x, data, digits, interactive, ...),
    profile   = ggfigs_profile(x, data, digits, interactive, ...))
}

#' @rdname ggfigs
#' @exportS3Method ggplot2::autoplot
autoplot.figsr_fit <- function(object, type = c("tree", "rules", "waterfall",
                                                "cuts", "profile"), ...) {
  ggfigs(object, type = match.arg(type), interactive = FALSE, ...)
}

# ---------------------------------------------------------------- palette ----
FIGS_PAL <- list(
  surface   = "#fcfcfb",
  ink       = "#0b0b0b",
  ink_2     = "#52514e",
  muted     = "#898781",
  grid      = "#e1e0d9",
  baseline  = "#c3c2b7",
  node_fill = "#f1f0ec",
  edge      = "#dcdbd3",
  div_low   = "#2a78d6",  # negative contribution
  div_mid   = "#f0efec",
  div_high  = "#d03b3b"   # positive contribution
)

# Fixed-order categorical palette, one colour per tree; never recycled.
FIGS_PAL_TREE <- c("#2a78d6", "#eb6834", "#1baf7a", "#eda100",
                   "#e87ba4", "#008300", "#4a3aa7", "#e34948")

FIGS_TIP_CSS <- paste0(
  "background:", FIGS_PAL$surface, ";color:", FIGS_PAL$ink,
  ";border:1px solid ", FIGS_PAL$baseline,
  ";border-radius:6px;padding:7px 9px;font-family:sans-serif;",
  "font-size:11.5px;box-shadow:0 2px 8px rgba(0,0,0,.12);")

theme_figs <- function(base_size = 11) {
  ggplot2::theme_void(base_size = base_size) +
    ggplot2::theme(
      plot.background  = ggplot2::element_rect(fill = FIGS_PAL$surface, colour = NA),
      panel.background = ggplot2::element_rect(fill = FIGS_PAL$surface, colour = NA),
      plot.title = ggplot2::element_text(
        colour = FIGS_PAL$ink, face = "bold", size = base_size * 1.35,
        hjust = 0, margin = ggplot2::margin(b = 2)),
      plot.subtitle = ggplot2::element_text(
        colour = FIGS_PAL$ink_2, size = base_size * 0.95, hjust = 0,
        margin = ggplot2::margin(b = 10)),
      plot.caption = ggplot2::element_text(
        colour = FIGS_PAL$muted, size = base_size * 0.8, hjust = 0,
        margin = ggplot2::margin(t = 10)),
      strip.text = ggplot2::element_text(
        colour = FIGS_PAL$ink_2, face = "bold", size = base_size,
        margin = ggplot2::margin(b = 6)),
      legend.position = "bottom",
      legend.title = ggplot2::element_text(colour = FIGS_PAL$ink_2,
                                           size = base_size * 0.85),
      legend.text = ggplot2::element_text(colour = FIGS_PAL$ink_2,
                                          size = base_size * 0.8),
      plot.margin = ggplot2::margin(12, 12, 12, 12)
    )
}

# Axis styling shared by the data-space views ("cuts", "profile").
theme_figs_axes <- function() {
  ggplot2::theme(
    axis.text = ggplot2::element_text(colour = FIGS_PAL$muted, size = 8),
    axis.title.y = ggplot2::element_text(colour = FIGS_PAL$ink_2, size = 9,
                                         angle = 90,
                                         margin = ggplot2::margin(r = 6)),
    axis.line.x = ggplot2::element_line(colour = FIGS_PAL$baseline,
                                        linewidth = 0.3),
    panel.grid.major.y = ggplot2::element_line(colour = FIGS_PAL$grid,
                                               linewidth = 0.3),
    panel.spacing = ggplot2::unit(14, "pt"))
}

# ---------------------------------------------------------- interactivity ----

# A geom that becomes its 'ggiraph' `_interactive` twin only when asked.
# The static branch drops the `tooltip`/`data_id` aesthetics, so the static
# plot never needs 'ggiraph'.
geom_figs <- function(name, interactive, mapping, ...) {
  if (interactive) {
    fun <- getExportedValue("ggiraph", paste0(name, "_interactive"))
  } else {
    mapping <- mapping[setdiff(names(mapping), c("tooltip", "data_id"))]
    fun <- getExportedValue("ggplot2", name)
  }
  fun(mapping = mapping, ...)
}

figs_girafe <- function(p, width_svg, height_svg, hover_css,
                        hover_inv_css = NULL) {
  opts <- list(
    ggiraph::opts_hover(css = hover_css),
    ggiraph::opts_tooltip(css = FIGS_TIP_CSS, opacity = 1, use_fill = FALSE),
    ggiraph::opts_toolbar(saveaspng = TRUE, position = "topright"),
    ggiraph::opts_sizing(rescale = TRUE))
  if (!is.null(hover_inv_css)) {
    opts <- c(opts, list(ggiraph::opts_hover_inv(css = hover_inv_css)))
  }
  ggiraph::girafe(ggobj = p, width_svg = width_svg, height_svg = height_svg,
                  options = opts)
}

# -------------------------------------------------------------- utilities ----
fmt_num <- function(v, digits = 3) {
  format(signif(v, digits), trim = TRUE, scientific = FALSE,
         drop0trailing = TRUE)
}

fmt_signed <- function(v, digits = 3) {
  s <- fmt_num(abs(v), digits)
  ifelse(v < 0, paste0("-", s), paste0("+", s))
}

# Labels drawn on the plot stay ASCII: the default pdf() device, which
# ggsave() uses for .pdf files, cannot draw a less-than-or-equal sign or
# subscript digits and errors on the latter. Tooltips are HTML and use
# entities instead.
f_label <- function(k) paste0("f", k, "(x)")

has_na_dir <- function(node) {
  length(node$na_dir) == 1L && !is.na(node$na_dir)
}

# Split condition seen from the left child, for node labels.
split_label <- function(node, digits = 3, wrap = FALSE) {
  br <- if (wrap) "\n" else " "
  if (isTRUE(node$split_on_missing)) {
    return(paste0(node$feature, br, "missing?"))
  }
  if (isTRUE(node$is_factor)) {
    paste0(node$feature, br, "in {", levels_label(node$split_val), "}")
  } else {
    paste0(node$feature, br, "<= ", fmt_num(node$split_val, digits))
  }
}

levels_label <- function(lv, max_shown = 3) {
  lv <- as.character(lv)
  if (length(lv) > max_shown) {
    paste0(paste(lv[seq_len(max_shown)], collapse = ", "), ", ...")
  } else {
    paste(lv, collapse = ", ")
  }
}

# One side of a split as a full clause, for the HTML tooltips.
split_clause <- function(node, left, digits = 3) {
  f <- node$feature
  if (isTRUE(node$split_on_missing)) {
    return(paste(f, if (left) "is missing" else "is not missing"))
  }
  out <- if (isTRUE(node$is_factor)) {
    paste0(f, if (left) " in {" else " not in {",
           paste(as.character(node$split_val), collapse = ", "), "}")
  } else {
    paste0(f, if (left) " &le; " else " &gt; ", fmt_num(node$split_val, digits))
  }
  if (has_na_dir(node) && (node$na_dir == "left") == left) {
    out <- paste0(out, " or missing")
  }
  out
}

# The model does not keep its training data; the views that draw it take
# `data` and rebuild the predictors through the stored terms.
figs_model_frame <- function(x, data, type) {
  if (is.null(data)) {
    stop(sprintf("`type = \"%s\"` needs `data =`, the data the model was ", type),
         "fit on; the fitted model does not store it.", call. = FALSE)
  }
  mf <- stats::model.frame(stats::delete.response(x$terms),
                           as.data.frame(data), na.action = stats::na.pass,
                           xlev = x$xlevels)
  check_training_rows(x, nrow(mf))
  mf
}

# Numeric outcome as the engine saw it: a binary factor becomes 0/1.
figs_response <- function(x, data) {
  mf <- stats::model.frame(x$terms, as.data.frame(data),
                           na.action = stats::na.pass, xlev = x$xlevels)
  check_training_rows(x, nrow(mf))
  y <- stats::model.response(mf)
  if (is.factor(y)) as.numeric(y == x$classes[2]) else as.numeric(y)
}

check_training_rows <- function(x, n) {
  if (n != length(x$fitted_values)) {
    stop(sprintf("`data` has %d rows but the model was fit on %d; pass the ", n,
                 length(x$fitted_values)),
         "training data.", call. = FALSE)
  }
}

# Every accepted split, flattened into a data frame.
collect_splits <- function(x, digits = 3) {
  out <- do.call(rbind, lapply(seq_along(x$trees), function(t) {
    tree <- x$trees[[t]]
    do.call(rbind, lapply(seq_along(tree), function(i) {
      nd <- tree[[i]]
      if (nd$is_leaf) return(NULL)
      numeric_cut <- !isTRUE(nd$is_factor) && !isTRUE(nd$split_on_missing)
      data.frame(
        tree       = f_label(t),
        feature    = nd$feature,
        numeric    = numeric_cut,
        label      = split_label(nd, digits),
        split_val  = if (numeric_cut) as.numeric(nd$split_val) else NA_real_,
        gain       = as.numeric(nd$gain),
        n          = length(nd$sample_indices),
        stringsAsFactors = FALSE
      )
    }))
  }))
  if (is.null(out) || !nrow(out)) {
    stop("the model has no splits to show.", call. = FALSE)
  }
  out$tree <- factor(out$tree, levels = vapply(seq_along(x$trees), f_label,
                                               character(1)))
  out
}
