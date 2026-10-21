# ggfigs(type = "rules"): every tree as a horizontal rule list, the trees
# stacked with "+" between them.
#
# Layout: each node continues to the right through the child with more nodes
# (a tie keeps "No" on the line and drops "Yes") and the other child drops. A
# leaf that drops is an arrow with its value; an internal node that drops
# opens a new row below, one column to the right, joined by an L connector.
# A tree in which every split has a leaf child reads as one line.

# Geometry in inches: coord_fixed(ratio = 1) makes one unit one inch at the
# natural size returned in attr(p, "ggfigs_size").
RULES_GEOM <- list(
  char_w   = 0.068,  # mean character width of the box text
  box_pad  = 0.30,
  box_min  = 1.25,
  box_h    = 0.62,
  gap      = 1.05,   # horizontal space between boxes
  branch   = 0.30,   # box edge to the point where a leaf drops
  drop     = 0.52,   # length of the arrow down to a leaf
  terminal = 0.62,   # length of the last arrow to the right
  row      = 1.55,   # vertical distance between rows
  tree_gap = 0.55    # extra space between trees, where the "+" goes
)

# The box condition, read as a question: "Yes" is the engine's left child.
rules_condition <- function(nd, digits = 3) {
  if (isTRUE(nd$split_on_missing)) return("is missing")
  cond <- if (isTRUE(nd$is_factor)) {
    paste0("in {", levels_label(nd$split_val), "}")
  } else {
    paste0("<= ", fmt_num(nd$split_val, digits))
  }
  if (has_na_dir(nd)) {
    cond <- paste0(cond, if (nd$na_dir == "left") " or NA" else " (NA: no)")
  }
  cond
}

# Box statistics: n always; with the training outcome, the class rate
# (classification) or the mean (regression).
rules_stats <- function(x, idx, y) {
  n <- length(idx)
  if (is.null(y)) return(sprintf("n = %d", n))
  if (x$mode == "classification") {
    k <- sum(y[idx])
    sprintf("%d/%d (%.1f%%) %s", k, n, 100 * k / n, x$classes[2])
  } else {
    sprintf("n = %d, mean %s", n, fmt_num(mean(y[idx]), 3))
  }
}

subtree_size <- function(tree, id) {
  nd <- tree[[id]]
  if (nd$is_leaf) return(1L)
  1L + subtree_size(tree, nd$left_child) + subtree_size(tree, nd$right_child)
}

# Lay out tree `t` from row `row0`; return its drawing pieces and the next
# free row.
layout_rules <- function(tree, t, x, y, digits, bw, row0) {
  G <- RULES_GEOM
  pitch <- bw + G$gap
  xc <- function(col) col * pitch
  yc <- function(row) -row * G$row

  boxes <- list()
  segs <- list()
  tags <- list()
  vals <- list()
  add <- function(lst, ...) c(lst, list(data.frame(..., stringsAsFactors = FALSE)))
  seg <- function(x, y, xend, yend, arrow) {
    segs <<- add(segs, x = x, y = y, xend = xend, yend = yend, arrow = arrow)
  }
  tag <- function(x, y, label, hjust, vjust) {
    tags <<- add(tags, x = x, y = y, label = label, hjust = hjust, vjust = vjust)
  }
  val <- function(x, y, nd, hjust, vjust, rule) {
    vals <<- add(vals, x = x, y = y, value = nd$value,
                 label = fmt_signed(nd$value, digits), hjust = hjust,
                 vjust = vjust, n = length(nd$sample_indices), rule = rule,
                 uid = paste0("t", t, "_", nd$id))
  }

  place <- function(id, col, row, rule) {
    y0 <- yc(row)
    cur <- id
    c <- col
    downs <- list()
    repeat {
      nd <- tree[[cur]]
      boxes <<- add(boxes, x = xc(c), y = y0, feature = nd$feature,
                    cond = rules_condition(nd, digits),
                    stats = rules_stats(x, nd$sample_indices, y),
                    gain = nd$gain, rule = rule, uid = paste0("t", t, "_", cur))

      l <- nd$left_child
      r <- nd$right_child
      go_left <- subtree_size(tree, l) > subtree_size(tree, r)
      cont <- if (go_left) l else r
      down <- if (go_left) r else l
      sep <- if (nchar(rule)) "<br>and " else ""
      cont_rule <- paste0(rule, sep, split_clause(nd, go_left, digits))
      down_rule <- paste0(rule, sep, split_clause(nd, !go_left, digits))
      cont_lab <- if (go_left) "Yes" else "No"
      down_lab <- if (go_left) "No" else "Yes"

      right <- xc(c) + bw / 2
      bx <- right + G$branch
      tag(bx, y0 + 0.05, cont_lab, 0.5, 0)

      if (tree[[down]]$is_leaf) {
        seg(bx, y0, bx, y0 - G$drop, TRUE)
        tag(bx + 0.05, y0 - G$drop * 0.45, down_lab, 0, 0.5)
        val(bx, y0 - G$drop - 0.06, tree[[down]], 0.5, 1, down_rule)
      } else {
        downs <- c(downs, list(list(id = down, col = c, bx = bx,
                                    lab = down_lab, rule = down_rule)))
      }

      if (tree[[cont]]$is_leaf) {
        end <- right + G$terminal
        seg(right, y0, end, y0, TRUE)
        val(end + 0.07, y0, tree[[cont]], 0, 0.5, cont_rule)
        break
      }
      seg(right, y0, xc(c + 1) - bw / 2, y0, TRUE)
      cur <- cont
      c <- c + 1
      rule <- cont_rule
    }

    # Internal branches that drop are stacked right to left, so the vertical
    # connector of one branch never crosses the rows of another.
    nxt <- row + 1
    for (d in rev(downs)) {
      y1 <- yc(nxt)
      seg(d$bx, y0, d$bx, y1, FALSE)
      seg(d$bx, y1, xc(d$col + 1) - bw / 2, y1, TRUE)
      tag(d$bx + 0.05, y0 - G$drop * 0.45, d$lab, 0, 0.5)
      nxt <- place(d$id, d$col + 1, nxt, d$rule)
    }
    nxt
  }

  nxt <- place(1L, 0L, row0, "")
  list(boxes = do.call(rbind, boxes), segs = do.call(rbind, segs),
       tags = do.call(rbind, tags), vals = do.call(rbind, vals),
       next_row = nxt)
}

ggfigs_rules <- function(x, data = NULL, digits = 3, interactive = FALSE,
                         width_svg = NULL, height_svg = NULL) {
  if (length(x$trees) == 0) {
    stop("the model has no trees to show.", call. = FALSE)
  }
  G <- RULES_GEOM
  y <- if (is.null(data)) NULL else figs_response(x, data)

  # One box width for the whole model, from the longest text. The width is
  # estimated from the character count, not measured.
  texts <- unlist(lapply(x$trees, function(tree) lapply(tree, function(nd) {
    if (nd$is_leaf) return(NULL)
    c(nd$feature, rules_condition(nd, digits),
      rules_stats(x, nd$sample_indices, y))
  })))
  bw <- max(G$box_min, max(nchar(texts)) * G$char_w + G$box_pad)

  parts <- list()
  plus <- NULL
  row <- 0
  y_off <- 0
  for (t in seq_along(x$trees)) {
    lay <- layout_rules(x$trees[[t]], t, x, y, digits, bw, row)
    for (k in c("boxes", "segs", "tags", "vals")) {
      d <- lay[[k]]
      for (v in intersect(c("y", "yend"), names(d))) d[[v]] <- d[[v]] - y_off
      parts[[k]] <- rbind(parts[[k]], d)
    }
    if (t < length(x$trees)) {
      bottom <- -(lay$next_row - 1) * G$row - y_off
      plus <- rbind(plus, data.frame(x = 0, y = bottom - (G$row + G$tree_gap) / 2))
      y_off <- y_off + G$tree_gap
    }
    row <- lay$next_row
  }
  boxes <- parts$boxes
  segs <- parts$segs
  tags <- parts$tags
  vals <- parts$vals

  boxes$tip <- sprintf(
    "<b>%s %s</b><br>%s<br>SSE gain = %s%s",
    boxes$feature, boxes$cond, boxes$stats, fmt_num(boxes$gain, digits),
    ifelse(nchar(boxes$rule),
           paste0("<br><br><i>reached when ", boxes$rule, "</i>"), ""))
  vals$tip <- sprintf("<b>Leaf: %s</b><br>n = %d<br><br><i>%s</i>",
                      vals$label, vals$n, vals$rule)
  vals$sign <- ifelse(vals$value < 0, "neg", "pos")
  boxes$xmin <- boxes$x - bw / 2
  boxes$xmax <- boxes$x + bw / 2
  boxes$ymin <- boxes$y - G$box_h / 2
  boxes$ymax <- boxes$y + G$box_h / 2

  line_h <- 0.165
  arrow_head <- ggplot2::arrow(length = ggplot2::unit(5, "pt"), type = "closed")

  p <- ggplot2::ggplot() +
    ggplot2::geom_segment(
      data = segs[!segs$arrow, , drop = FALSE],
      ggplot2::aes(x = .data$x, y = .data$y, xend = .data$xend, yend = .data$yend),
      colour = FIGS_PAL$ink_2, linewidth = 0.4) +
    ggplot2::geom_segment(
      data = segs[segs$arrow, , drop = FALSE],
      ggplot2::aes(x = .data$x, y = .data$y, xend = .data$xend, yend = .data$yend),
      colour = FIGS_PAL$ink_2, linewidth = 0.4, arrow = arrow_head,
      linejoin = "mitre") +
    geom_figs("geom_rect", interactive,
      ggplot2::aes(xmin = .data$xmin, xmax = .data$xmax, ymin = .data$ymin,
                   ymax = .data$ymax, tooltip = .data$tip, data_id = .data$uid),
      data = boxes, fill = FIGS_PAL$node_fill, colour = FIGS_PAL$ink_2,
      linewidth = 0.35) +
    ggplot2::geom_text(
      data = boxes,
      ggplot2::aes(x = .data$x, y = .data$y + line_h, label = .data$feature),
      colour = FIGS_PAL$ink, size = 3.05, fontface = "bold") +
    ggplot2::geom_text(
      data = boxes, ggplot2::aes(x = .data$x, y = .data$y, label = .data$cond),
      colour = FIGS_PAL$ink, size = 2.9) +
    ggplot2::geom_text(
      data = boxes,
      ggplot2::aes(x = .data$x, y = .data$y - line_h, label = .data$stats),
      colour = FIGS_PAL$ink_2, size = 2.7) +
    ggplot2::geom_text(
      data = tags,
      ggplot2::aes(x = .data$x, y = .data$y, label = .data$label,
                   hjust = .data$hjust, vjust = .data$vjust),
      colour = FIGS_PAL$ink_2, size = 2.6) +
    geom_figs("geom_text", interactive,
      ggplot2::aes(x = .data$x, y = .data$y, label = .data$label,
                   hjust = .data$hjust, vjust = .data$vjust,
                   colour = .data$sign, tooltip = .data$tip,
                   data_id = .data$uid),
      data = vals, size = 3.3, fontface = "bold") +
    ggplot2::scale_colour_manual(
      values = c(neg = FIGS_PAL$div_low, pos = FIGS_PAL$div_high),
      guide = "none") +
    ggplot2::coord_fixed(ratio = 1, clip = "off") +
    ggplot2::labs(
      title = "FIGS rule lists",
      subtitle = paste0(
        "Prediction = sum of one leaf value per tree",
        if (x$intercept != 0) paste0(" + intercept ", fmt_num(x$intercept, digits)),
        if (x$mode == "classification")
          sprintf(", read as P(y = \"%s\")", x$classes[2])),
      caption = paste0("Yes = the condition in the box holds",
                       if (is.null(y)) "; pass `data =` for outcome rates per box")) +
    theme_figs()

  if (!is.null(plus)) {
    p <- p + ggplot2::geom_text(
      data = plus, ggplot2::aes(x = .data$x, y = .data$y),
      label = "+", size = 7, colour = FIGS_PAL$ink)
  }

  # natural size of the drawing (one unit = one inch) plus margins and title
  xr <- range(c(boxes$xmin, segs$xend, vals$x + 0.5))
  yr <- range(c(boxes$ymax, vals$y - 0.25))
  size <- c(width = diff(xr) + 0.6, height = diff(yr) + 1.5)
  attr(p, "ggfigs_size") <- size

  if (!interactive) return(p)
  figs_girafe(p,
              width_svg = if (is.null(width_svg)) size[["width"]] else width_svg,
              height_svg = if (is.null(height_svg)) size[["height"]] else height_svg,
              hover_css = paste0("stroke:", FIGS_PAL$ink, ";stroke-width:1.4px;"))
}
