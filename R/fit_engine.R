#' Fit Fast Interpretable Greedy-Tree Sums (FIGS)
#'
#' @description
#' `figs()` fits a Fast Interpretable Greedy-Tree Sums model for regression or
#' binary classification tasks.
#'
#' @details
#' Trees are grown one split at a time. At each step every leaf of every existing
#' tree, plus the root of a possible new tree, competes for the split that most
#' reduces the residual sum of squares; the single best candidate is taken and
#' the residuals are recomputed against the whole sum. Growth stops at
#' `max_splits` splits or when no candidate improves the fit.
#'
#' Classification is limited to two classes. A factor outcome with more than two
#' levels raises an error. The binary case is fitted on the 0/1 encoding of the
#' outcome using the same sum-of-squares criterion, so the sum of the leaf values
#' already estimates the probability of the second level; it is clamped to the
#' unit interval at prediction time rather than passed through a link function.
#'
#' Predictors are used exactly as supplied: numeric features are split at
#' midpoints between sorted unique values, capped at 30 sample quantiles, and
#' factor features are split by enumerating subsets of their levels, which is
#' skipped above 10 levels. A factor level that was not seen in training raises
#' an error at prediction time, as it does for the other model-frame based
#' fitting functions in `stats`.
#'
#' Missing predictor values are governed by `na_method`. With `"omit"`, the
#' default, rows with a missing predictor are dropped at fit time by
#' [stats::model.frame()] and raise an error at prediction time. With `"mia"`
#' (missingness incorporated in attributes, Twala et al. 2008) every row is
#' kept: for a predictor with missing values the split search also tries
#' sending them to the left or to the right of each cutpoint, and splitting on
#' whether the value is missing at all, and keeps whichever reduces the
#' residual sum of squares most. The learned direction is used at prediction
#' time. A missing value in a predictor that was complete in training raises
#' an error, because no direction was learned; impute such values first, for
#' example with `recipes::step_impute_knn()`. Even under `"mia"`, a branch of
#' the tree that no missing value reached during training has not learned a
#' direction, so a missing value reaching that same branch at prediction time
#' still raises an error. Rows with a missing outcome are dropped with a
#' warning under `na_method = "mia"` only; under `"omit"` they are dropped
#' silently by [stats::na.omit()].
#'
#' @param formula A formula specifying outcome and predictor variables.
#' @param data A data frame containing training data.
#' @param max_splits Integer. Maximum total number of splits across all trees in the sum. Default is 10.
#' @param max_trees Integer. Maximum number of trees allowed in the sum. Default is NULL (unconstrained up to max_splits).
#' @param min_n Integer. Minimum number of observations required in a node to split. Default is 5.
#' @param mode Character. Either `"regression"` or `"classification"`. Only
#'   two-class outcomes are supported in classification mode. Default is
#'   `"regression"`.
#' @param subset An optional vector selecting the rows of `data` to fit on,
#'   passed to [stats::model.frame()].
#' @param na.action A function describing what to do with missing values, passed
#'   to [stats::model.frame()]. Defaults to [stats::na.omit()]. Cannot be
#'   combined with `na_method = "mia"`.
#' @param na_method Character. How to treat missing predictor values:
#'   `"omit"` (the default) drops incomplete rows, `"mia"` learns a direction
#'   for them at every split and can also split on missingness itself. See
#'   Details. Cannot be combined with `na.action`.
#' @param ... Additional arguments, currently ignored. Case weights are not
#'   supported and passing `weights` raises an error.
#'
#' @references
#' Twala, B. E. T. H., Jones, M. C. and Hand, D. J. (2008). Good methods for
#' coping with missing data in decision trees. *Pattern Recognition Letters*,
#' 29(7), 950-956.
#'
#' @return An object of class `figsr_fit` containing fitted tree structures, predictions, and metadata.
#' @export
#'
#' @examples
#' set.seed(123)
#' df <- data.frame(
#'   x1 = rnorm(100),
#'   x2 = rnorm(100),
#'   y = rnorm(100)
#' )
#' fit <- figs(y ~ x1 + x2, data = df, max_splits = 4)
#' print(fit)
figs <- function(formula, data, max_splits = 10, max_trees = NULL, min_n = 5,
                 mode = "regression", subset = NULL,
                 na.action = stats::na.omit, na_method = c("omit", "mia"), ...) {
  cl <- match.call()
  na_method <- match.arg(na_method)

  if (!is.data.frame(data)) {
    stop("`data` must be a data frame.", call. = FALSE)
  }
  if ("weights" %in% names(list(...))) {
    stop("Case weights are not supported by figsr.", call. = FALSE)
  }

  if (length(max_splits) != 1 || is.na(max_splits) || max_splits < 0) {
    stop("`max_splits` must be a single non-negative integer.", call. = FALSE)
  }
  if (length(min_n) != 1 || is.na(min_n) || min_n < 1) {
    stop("`min_n` must be a single integer of at least 1.", call. = FALSE)
  }
  if (!is.null(max_trees) &&
      (length(max_trees) != 1 || is.na(max_trees) || max_trees < 1)) {
    stop("`max_trees` must be NULL or a single integer of at least 1.", call. = FALSE)
  }
  if (!mode %in% c("regression", "classification")) {
    stop("`mode` must be either \"regression\" or \"classification\".", call. = FALSE)
  }
  if (na_method == "mia") {
    # Under MIA the engine owns the missing values; a user-supplied na.action
    # would either delete them or contradict that, so the two cannot be mixed.
    if (!missing(na.action)) {
      stop("`na.action` cannot be combined with `na_method = \"mia\"`; ",
           "missing predictor values are handled by the split search.",
           call. = FALSE)
    }
    na.action <- stats::na.pass
  }

  # Subsetting here rather than through `model.frame()`, whose `subset` argument
  # is evaluated non-standardly and would not see an ordinary vector.
  if (!is.null(subset)) {
    data <- data[subset, , drop = FALSE]
  }
  mf <- stats::model.frame(formula = formula, data = data, na.action = na.action)
  mt <- stats::terms(mf)
  xlevels <- stats::.getXlevels(mt, mf)
  y <- stats::model.response(mf)
  X <- mf[, -1, drop = FALSE]

  if (na_method == "mia") {
    # na.pass keeps rows with a missing outcome too; those carry no signal.
    keep <- !is.na(y)
    if (!all(keep)) {
      warning(sprintf("%d row(s) with a missing outcome were dropped.", sum(!keep)),
              call. = FALSE)
      y <- y[keep]
      X <- X[keep, , drop = FALSE]
    }
  } else if (anyNA(X)) {
    stop("Predictors contain missing values, which `na_method = \"omit\"` ",
         "cannot use. Set `na_method = \"mia\"` to learn a direction for ",
         "them, or impute them before fitting.", call. = FALSE)
  }

  # A term such as `poly(x, 2)` yields a matrix column, which the split search
  # would silently turn into NA gains.
  matrix_terms <- names(X)[vapply(X, function(col) !is.null(dim(col)), logical(1))]
  if (length(matrix_terms) > 0) {
    stop(paste0("Matrix-valued terms are not supported: ",
                paste(matrix_terms, collapse = ", "),
                ". Compute them as ordinary columns of `data` first."),
         call. = FALSE)
  }

  if (length(y) == 0 || nrow(X) == 0) {
    stop("Training data cannot be empty.", call. = FALSE)
  }

  fit_figs_engine(
    X = X,
    y = y,
    max_splits = max_splits,
    max_trees = max_trees,
    min_n = min_n,
    mode = mode,
    na_method = na_method,
    formula = formula,
    terms = mt,
    xlevels = xlevels,
    call = cl
  )
}

# Engine implementation
#
# Every leaf of every tree, plus the root of a possible new tree, is a
# "candidate". A candidate's rows and their predictor values never change while
# it exists; only the residuals do. Everything that depends on the predictors
# alone (rows ordered by value, cutpoints, how many rows fall left of each
# cutpoint, rows grouped by factor level) is therefore computed once, when the
# candidate is created, and kept in its `index`. Each iteration then only has
# to gather the residuals in that order and take one cumulative sum per
# predictor to score every cutpoint at once.
#
# After a split of leaf L, residuals change on the rows of L only. A candidate
# whose rows do not meet L keeps its best split from the previous iteration;
# this is always the case for the other leaves of L's tree.
fit_figs_engine <- function(X, y, max_splits = 10, max_trees = NULL, min_n = 5,
                            mode = "regression", na_method = "omit",
                            formula = NULL, terms = NULL,
                            xlevels = NULL, call = NULL) {
  n <- nrow(X)

  is_class <- (mode == "classification") || is.factor(y) || is.character(y)

  if (is_class) {
    y_fac <- as.factor(y)
    classes <- levels(y_fac)
    if (length(classes) != 2) {
      stop("Currently binary classification is supported.", call. = FALSE)
    }
    # Encode binary y as 0/1
    y_num <- ifelse(y_fac == classes[2], 1, 0)
    mode <- "classification"
  } else {
    y_num <- as.numeric(y)
    classes <- NULL
    mode <- "regression"
  }

  mia <- na_method == "mia"
  cols <- prepare_columns(X)
  feature_names <- colnames(X)

  trees <- list()
  residuals <- y_num
  total_splits <- 0

  # The root of a new tree always holds every row, so its index is built once
  # and shared by every tree the fit opens.
  root_index <- build_node_index(cols, seq_len(n))
  root <- new_candidate(0L, 1L, seq_len(n), root_index)
  leaves <- list()

  while (total_splits < max_splits) {
    allow_new_tree <- is.null(max_trees) || length(trees) < max_trees

    best_global_gain <- -Inf
    best_leaf <- NULL

    # Same order as always: the new root first, then trees and nodes in
    # increasing order, so the first maximum wins ties (see `beats()`).
    if (allow_new_tree) {
      if (root$dirty) {
        root$best <- search_candidate(root, residuals, cols, min_n, mia)
        root$dirty <- FALSE
      }
      if (!is.null(root$best) && beats(root$best$gain, best_global_gain)) {
        best_global_gain <- root$best$gain
        best_leaf <- 0L
      }
    }

    if (length(leaves) > 0) {
      visit <- order(vapply(leaves, `[[`, integer(1), "tree"),
                     vapply(leaves, `[[`, integer(1), "node"))
      for (s in visit) {
        if (leaves[[s]]$dirty) {
          leaves[[s]]$best <- search_candidate(leaves[[s]], residuals, cols, min_n, mia)
          leaves[[s]]$dirty <- FALSE
        }
        cand <- leaves[[s]]$best
        if (!is.null(cand) && beats(cand$gain, best_global_gain)) {
          best_global_gain <- cand$gain
          best_leaf <- s
        }
      }
    }

    if (is.null(best_leaf) || best_global_gain <= 1e-6) {
      break
    }

    chosen <- if (best_leaf == 0L) root else leaves[[best_leaf]]
    sp <- materialize_split(chosen, X, feature_names)
    mean_left <- mean(residuals[sp$idx_left])
    mean_right <- mean(residuals[sp$idx_right])

    if (best_leaf == 0L) {
      root_node <- make_node(
        id = 1, is_leaf = FALSE, feature = sp$var_name, is_factor = sp$is_factor,
        split_val = sp$split_val, left_child = 2, right_child = 3, gain = sp$gain,
        na_dir = sp$na_dir, split_on_missing = sp$split_on_missing,
        value = 0, sample_indices = seq_len(n)
      )
      left_node <- make_node(id = 2, value = mean_left, sample_indices = sp$idx_left)
      right_node <- make_node(id = 3, value = mean_right, sample_indices = sp$idx_right)
      trees[[length(trees) + 1]] <- list(root_node, left_node, right_node)
      t_idx <- length(trees)
      left_id <- 2L
      parent_index <- root_index
    } else {
      t_idx <- chosen$tree
      n_idx <- chosen$node
      tree <- trees[[t_idx]]
      parent <- tree[[n_idx]]

      next_id <- length(tree) + 1
      parent$is_leaf <- FALSE
      parent$feature <- sp$var_name
      parent$is_factor <- sp$is_factor
      parent$split_val <- sp$split_val
      parent$left_child <- next_id
      parent$right_child <- next_id + 1
      parent$gain <- sp$gain
      parent$na_dir <- sp$na_dir
      parent$split_on_missing <- sp$split_on_missing

      # `residuals` are net of the value the parent leaf was already
      # contributing, while `predict_trees()` reads only the leaf it lands on.
      # The children must therefore carry the parent's contribution as well.
      base_value <- parent$value
      left_node <- make_node(
        id = next_id, value = base_value + mean_left, sample_indices = sp$idx_left
      )
      right_node <- make_node(
        id = next_id + 1, value = base_value + mean_right, sample_indices = sp$idx_right
      )

      tree[[n_idx]] <- parent
      tree[[next_id]] <- left_node
      tree[[next_id + 1]] <- right_node
      trees[[t_idx]] <- tree
      left_id <- as.integer(next_id)
      parent_index <- chosen$index
      leaves[[best_leaf]] <- NULL
    }

    total_splits <- total_splits + 1

    # The fitted sum changes on the split leaf only, by a constant on each
    # side, so this equals `y_num - predict_trees(trees, X)` without walking
    # the trees.
    residuals[sp$idx_left] <- residuals[sp$idx_left] - mean_left
    residuals[sp$idx_right] <- residuals[sp$idx_right] - mean_right

    changed <- logical(n)
    changed[sp$idx_left] <- TRUE
    changed[sp$idx_right] <- TRUE
    root$dirty <- TRUE
    for (s in seq_along(leaves)) {
      if (!leaves[[s]]$dirty && any(changed[leaves[[s]]$idx])) {
        leaves[[s]]$dirty <- TRUE
      }
    }

    leaves[[length(leaves) + 1]] <- new_candidate(
      t_idx, left_id, sp$idx_left, child_index(parent_index, cols, sp$idx_left, n)
    )
    leaves[[length(leaves) + 1]] <- new_candidate(
      t_idx, left_id + 1L, sp$idx_right, child_index(parent_index, cols, sp$idx_right, n)
    )
  }

  # The root of the first tree splits the whole sample, so its leaves already
  # absorb the outcome mean and no intercept is needed. When no split was ever
  # accepted there are no leaves to absorb it, and the model must fall back to
  # the mean rather than predicting zero.
  intercept <- if (length(trees) == 0) mean(y_num) else 0

  fitted_vals <- intercept + predict_trees(trees, X)
  if (mode == "classification") {
    # Keep `fitted_values` on the same scale `predict()` reports.
    fitted_vals <- pmin(pmax(fitted_vals, PROB_EPS), 1 - PROB_EPS)
  }

  res <- list(
    trees = trees,
    intercept = intercept,
    mode = mode,
    na_method = na_method,
    classes = classes,
    max_splits = max_splits,
    total_splits = total_splits,
    feature_names = colnames(X),
    fitted_values = fitted_vals,
    formula = formula,
    terms = terms,
    xlevels = xlevels,
    call = call
  )

  class(res) <- "figsr_fit"
  return(res)
}

# A split candidate: the root of a new tree (`tree = 0`) or a leaf. `best`
# caches its best split on the residuals of the last time it was searched;
# `dirty` marks that some of its residuals changed since.
new_candidate <- function(tree, node, idx, index) {
  list(tree = as.integer(tree), node = as.integer(node), idx = idx,
       index = index, best = NULL, dirty = TRUE)
}

# Constructor guaranteeing every node carries the same field set, so consumers
# never have to test for missing components.
# `na_dir` is where a missing value of `feature` is routed ("left"/"right"),
# or NA when the training data had none. `split_on_missing` marks a node that
# splits on is.na(feature) itself; `split_val` is then unused.
make_node <- function(id, is_leaf = TRUE, feature = NULL, is_factor = FALSE,
                      split_val = NULL, left_child = NULL, right_child = NULL,
                      gain = 0, value = 0, sample_indices = integer(0),
                      na_dir = NA_character_, split_on_missing = FALSE) {
  list(
    id = id,
    is_leaf = is_leaf,
    feature = feature,
    is_factor = is_factor,
    split_val = split_val,
    left_child = left_child,
    right_child = right_child,
    gain = gain,
    value = value,
    sample_indices = sample_indices,
    na_dir = na_dir,
    split_on_missing = split_on_missing
  )
}


# Gains are now accumulated from sums taken in each predictor's own order, so
# the same partition reached through two predictors (a predictor and its
# mirror image, a factor and a copy with its levels reordered) can score
# differently in the last bits. Gains within this relative distance of the
# incumbent therefore count as tied, and the first candidate in search order
# keeps winning, as identical partitions always did when every gain was
# computed in row order.
TIE_TOL <- 1e-10

beats <- function(gain, incumbent) {
  incumbent == -Inf || gain > incumbent + TIE_TOL * abs(incumbent)
}

# SSE reduction of every partition of a node into a left part with residual
# sum `S_left` over `n_left` rows and the rest, given the node's total `S_tot`
# over `n_node` rows. The residuals must be centered on the node mean, which
# makes this
#   SS_total - (SS_left + SS_right) = S_left^2 / n_left + S_right^2 / n_right - S_tot^2 / n_node
# free of the cancellation the left-hand side suffers when the gain is small
# next to SS_total. Partitions with a side smaller than `min_n` get -Inf.
split_gains <- function(S_left, n_left, S_tot, n_node, min_n) {
  n_right <- n_node - n_left
  g <- S_left^2 / n_left + (S_tot - S_left)^2 / n_right - S_tot^2 / n_node
  g[n_left < min_n | n_right < min_n] <- -Inf
  g
}

# Predictors as plain vectors: doubles for numeric columns, integer codes for
# factor and character ones (a character column gets the levels
# `as.factor()` would give it, as before).
prepare_columns <- function(X) {
  lapply(X, function(col) {
    if (is.factor(col) || is.character(col)) {
      f <- as.factor(col)
      list(is_fac = TRUE, codes = as.integer(f), labels = levels(f), miss = is.na(f))
    } else {
      # `as.numeric()` guards against integer overflow in the midpoints.
      x <- as.numeric(col)
      list(is_fac = FALSE, x = x, miss = is.na(x))
    }
  })
}

# Per-predictor index of the rows `idx`: observed rows ordered by value (or by
# level code), the rows with a missing value, and the cutpoints.
build_node_index <- function(cols, idx) {
  lapply(cols, function(col) {
    miss_rows <- idx[col$miss[idx]]
    obs_rows <- idx[!col$miss[idx]]
    key <- if (col$is_fac) col$codes[obs_rows] else col$x[obs_rows]
    finish_index(col, obs_rows[order(key, method = "radix")], miss_rows)
  })
}

# A child keeps its parent's order, filtered to its own rows: no re-sorting.
child_index <- function(parent_index, cols, idx_child, n) {
  member <- logical(n)
  member[idx_child] <- TRUE
  Map(function(pi, col) {
    finish_index(col, pi$ord[member[pi$ord]], pi$miss_rows[member[pi$miss_rows]])
  }, parent_index, cols)
}

# Numeric predictors are split at midpoints between sorted unique values,
# capped at 30 sample quantiles. Factors are split by enumerating subsets of
# the levels present in the node, skipped above 10 levels; levels keep their
# declared order and NA is never a level. `active` is FALSE when the predictor
# offers no cutpoint in this node (a split on missingness may still exist).
finish_index <- function(col, ord, miss_rows) {
  out <- list(ord = ord, miss_rows = miss_rows, n_obs = length(ord),
              n_miss = length(miss_rows), active = FALSE)
  if (length(ord) == 0) return(out)
  if (col$is_fac) {
    counts <- tabulate(col$codes[ord], nbins = length(col$labels))
    present <- which(counts > 0)
    levs <- col$labels[present]
    if (length(levs) <= 1 || length(levs) > 10) return(out)
    subsets <- get_factor_subsets(levs)
    membership <- t(vapply(subsets, function(sub) as.numeric(levs %in% sub),
                           numeric(length(levs))))
    out$active <- TRUE
    out$ends <- cumsum(counts[present])
    out$membership <- membership
    out$n_sub_left <- as.vector(membership %*% counts[present])
    out$subsets <- subsets
  } else {
    xs <- col$x[ord]
    vals <- xs[c(TRUE, diff(xs) != 0)]
    if (length(vals) <= 1) return(out)
    cutpoints <- (vals[-length(vals)] + vals[-1]) / 2
    if (length(cutpoints) > 30) {
      # Quantiles of the sample, not of `vals`: the unique values weight every
      # distinct level equally and so ignore where the data actually lie.
      cutpoints <- unique(quantile7_sorted(xs, seq(0.05, 0.95, length.out = 30)))
    }
    out$active <- TRUE
    out$cutpoints <- cutpoints
    # Rows with x <= each cutpoint, the comparison the split itself uses.
    out$pos <- findInterval(cutpoints, xs)
  }
  out
}

# `stats::quantile(xs, probs, type = 7)` for an already sorted `xs`, by the
# same arithmetic as `quantile.default()`, without sorting `xs` again.
quantile7_sorted <- function(xs, probs) {
  n <- length(xs)
  index <- 1 + max(n - 1, 0) * probs
  lo <- floor(index)
  hi <- ceiling(index)
  qs <- xs[lo]
  i <- which(index > lo & xs[hi] != qs)
  h <- (index - lo)[i]
  qs[i] <- (1 - h) * qs[i] + h * xs[hi[i]]
  qs
}

# Best split of a candidate on the current residuals, as a description
# (predictor, cutpoint or subset number, missing-value routing), or NULL.
# Under na_method = "mia" a predictor with missing values in the node also
# offers the three candidates of Twala et al. (2008): NA to the left of each
# cutpoint (A), NA to the right (B), and NA versus observed on its own (C).
# They are scored in the order C, A1, B1, A2, B2, ... and, across predictors,
# the first maximum wins (up to `TIE_TOL`).
search_candidate <- function(cand, residuals, cols, min_n, mia) {
  idx <- cand$idx
  n_node <- length(idx)
  if (n_node < 2 * min_n) return(NULL)

  mu <- mean(residuals[idx])
  best_gain <- -Inf
  best <- NULL

  for (j in seq_along(cols)) {
    ix <- cand$index[[j]]
    has_na <- mia && ix$n_miss > 0
    if (!has_na && !ix$active) next

    S_miss <- if (ix$n_miss > 0) sum(residuals[ix$miss_rows] - mu) else 0
    cs <- cumsum(residuals[ix$ord] - mu)
    S_obs <- if (ix$n_obs > 0) cs[ix$n_obs] else 0
    S_tot <- S_obs + S_miss

    g_C <- if (has_na) split_gains(S_miss, ix$n_miss, S_tot, n_node, min_n) else numeric(0)
    g_cut <- numeric(0)
    if (ix$active) {
      if (cols[[j]]$is_fac) {
        S_lev <- diff(c(0, cs[ix$ends]))
        S_le <- as.vector(ix$membership %*% S_lev)
        n_le <- ix$n_sub_left
      } else {
        S_le <- c(0, cs)[ix$pos + 1]
        n_le <- ix$pos
      }
      g_cut <- if (has_na) {
        as.vector(rbind(split_gains(S_le + S_miss, n_le + ix$n_miss, S_tot, n_node, min_n),
                        split_gains(S_le, n_le, S_tot, n_node, min_n)))
      } else {
        split_gains(S_le, n_le, S_tot, n_node, min_n)
      }
    }

    g <- c(g_C, g_cut)
    top <- if (length(g) > 0) max(g) else -Inf
    if (top == -Inf) next
    k <- which(g >= top - TIE_TOL * abs(top))[1]
    if (!beats(g[k], best_gain)) next
    best_gain <- g[k]
    if (has_na && k == 1) {
      best <- list(gain = g[k], j = j, split_on_missing = TRUE, k = NA_integer_,
                   na_dir = NA_character_)
    } else if (has_na) {
      k_cut <- k - 1
      best <- list(gain = g[k], j = j, split_on_missing = FALSE,
                   k = (k_cut + 1) %/% 2,
                   na_dir = if (k_cut %% 2 == 1) "left" else "right")
    } else {
      best <- list(gain = g[k], j = j, split_on_missing = FALSE, k = k,
                   na_dir = NA_character_)
    }
  }

  if (best_gain <= 1e-6 || is.null(best)) return(NULL)
  best
}

# Turn a candidate's best split into the split record the engine stores,
# rebuilding the left mask from the predictor values so that `idx_left` and
# `idx_right` keep the order of `cand$idx`.
materialize_split <- function(cand, X, feature_names) {
  b <- cand$best
  idx <- cand$idx
  ix <- cand$index[[b$j]]
  col_vals <- X[[b$j]][idx]
  is_fac <- is.factor(col_vals) || is.character(col_vals)
  miss <- is.na(col_vals)
  obs <- !miss

  if (b$split_on_missing) {
    left_mask <- miss
    split_val <- NA
  } else {
    if (is_fac) {
      split_val <- ix$subsets[[b$k]]
      left_mask <- obs & (as.character(col_vals) %in% split_val)
    } else {
      split_val <- ix$cutpoints[b$k]
      left_mask <- obs & (as.numeric(col_vals) <= split_val)
    }
    if (identical(b$na_dir, "left")) left_mask <- left_mask | miss
  }

  list(
    gain = b$gain, var_name = feature_names[b$j], is_factor = is_fac,
    split_val = split_val, na_dir = b$na_dir,
    split_on_missing = b$split_on_missing,
    idx_left = idx[left_mask], idx_right = idx[!left_mask]
  )
}

# Best split of the observations in `sample_indices` on `residuals`, searched
# on its own, outside a fit. Returns the split record, or NULL when no split
# reduces the residual sum of squares.
find_best_split <- function(X, residuals, sample_indices, min_n = 5,
                            na_method = "omit") {
  cols <- prepare_columns(X)
  cand <- new_candidate(0L, 1L, sample_indices, build_node_index(cols, sample_indices))
  cand$best <- search_candidate(cand, residuals, cols, min_n, na_method == "mia")
  if (is.null(cand$best)) return(NULL)
  materialize_split(cand, X, colnames(X))
}

# Helper to predict sum of trees on new dataset X_new.
# Observations are routed as index sets, one node at a time, rather than one
# observation at a time.
predict_trees <- function(trees, X_new) {
  n <- nrow(X_new)
  total_pred <- numeric(n)
  if (length(trees) == 0) return(total_pred)

  for (tree in trees) {
    descend <- function(node, idx) {
      if (length(idx) == 0) return(invisible(NULL))
      if (node$is_leaf) {
        total_pred[idx] <<- total_pred[idx] + node$value
        return(invisible(NULL))
      }

      x_val <- X_new[[node$feature]][idx]
      miss <- is.na(x_val)

      if (isTRUE(node$split_on_missing)) {
        is_left <- miss
      } else {
        if (node$is_factor) {
          is_left <- as.character(x_val) %in% as.character(node$split_val)
        } else {
          is_left <- (x_val <= node$split_val)
        }
        if (any(miss)) {
          # Fits saved before 0.2.0 carry no `na_dir`; treat them like a
          # column that had no missing values in training.
          na_dir <- node$na_dir
          if (is.null(na_dir) || is.na(na_dir)) {
            stop(
              paste0("`new_data` has missing values in the predictor `",
                     node$feature, "` at a point in the tree where no direction was ",
                     "learned for them (either this branch was never reached by a ",
                     "missing value during training, or the model was fitted with ",
                     "na_method = \"omit\"). Impute them first (for example with ",
                     "`recipes::step_impute_*()`) or refit on data where a missing ",
                     "value of this predictor can reach this branch."),
              call. = FALSE
            )
          }
          is_left[miss] <- (na_dir == "left")
        }
      }

      descend(tree[[node$left_child]], idx[is_left])
      descend(tree[[node$right_child]], idx[!is_left])
    }
    descend(tree[[1]], seq_len(n))
  }

  return(total_pred)
}

# Subset helper for factors
get_factor_subsets <- function(levs) {
  n <- length(levs)
  if (n <= 1) return(list())
  # Return all non-empty proper subsets
  lapply(1:(2^(n-1) - 1), function(i) {
    levs[which(intToBits(i)[1:n] == 1)]
  })
}
