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
#' fitting functions in `stats`. Rows with a missing value in a predictor are
#' dropped at fit time by [stats::model.frame()] and raise an error at
#' prediction time.
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
#' @param na_method Character. Either `"omit"` (the default; missing
#'   predictors are not supported and raise an error) or `"mia"` (missing
#'   predictors are kept in the model frame; a missing outcome is dropped with
#'   a warning). The split search does not yet use `"mia"` values specially.
#' @param ... Additional arguments, currently ignored. Case weights are not
#'   supported and passing `weights` raises an error.
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
fit_figs_engine <- function(X, y, max_splits = 10, max_trees = NULL, min_n = 5,
                            mode = "regression", na_method = "omit",
                            formula = NULL, terms = NULL,
                            xlevels = NULL, call = NULL) {
  n <- nrow(X)
  p <- ncol(X)
  
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
  
  trees <- list()
  residuals <- y_num
  total_splits <- 0
  
  while (total_splits < max_splits) {
    if (!is.null(max_trees) && length(trees) >= max_trees) {
      # Can only split inside existing trees if max_trees reached
      allow_new_tree <- FALSE
    } else {
      allow_new_tree <- TRUE
    }
    
    best_global_gain <- -Inf
    best_action <- NULL
    
    # 1. Candidate split on a NEW tree root
    if (allow_new_tree) {
      split_new <- find_best_split(X, residuals, seq_len(n), min_n = min_n, na_method = na_method)
      if (!is.null(split_new) && split_new$gain > best_global_gain) {
        best_global_gain <- split_new$gain
        best_action <- list(type = "new_tree", split = split_new)
      }
    }
    
    # 2. Candidate split on EXISTING tree leaves
    if (length(trees) > 0) {
      for (t_idx in seq_along(trees)) {
        tree <- trees[[t_idx]]
        for (n_idx in seq_along(tree)) {
          node <- tree[[n_idx]]
          if (node$is_leaf) {
            split_cand <- find_best_split(X, residuals, node$sample_indices, min_n = min_n, na_method = na_method)
            if (!is.null(split_cand) && split_cand$gain > best_global_gain) {
              best_global_gain <- split_cand$gain
              best_action <- list(
                type = "existing_tree",
                tree_idx = t_idx,
                node_idx = n_idx,
                split = split_cand
              )
            }
          }
        }
      }
    }
    
    if (is.null(best_action) || best_global_gain <= 1e-6) {
      break
    }
    
    sp <- best_action$split
    
    if (best_action$type == "new_tree") {
      root_node <- make_node(
        id = 1, is_leaf = FALSE, feature = sp$var_name, is_factor = sp$is_factor,
        split_val = sp$split_val, left_child = 2, right_child = 3, gain = sp$gain,
        na_dir = sp$na_dir, split_on_missing = sp$split_on_missing,
        value = 0, sample_indices = seq_len(n)
      )
      left_node <- make_node(
        id = 2, value = mean(residuals[sp$idx_left]), sample_indices = sp$idx_left
      )
      right_node <- make_node(
        id = 3, value = mean(residuals[sp$idx_right]), sample_indices = sp$idx_right
      )
      trees[[length(trees) + 1]] <- list(root_node, left_node, right_node)
    } else {
      t_idx <- best_action$tree_idx
      n_idx <- best_action$node_idx
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
        id = next_id, value = base_value + mean(residuals[sp$idx_left]),
        sample_indices = sp$idx_left
      )
      right_node <- make_node(
        id = next_id + 1, value = base_value + mean(residuals[sp$idx_right]),
        sample_indices = sp$idx_right
      )

      tree[[n_idx]] <- parent
      tree[[next_id]] <- left_node
      tree[[next_id + 1]] <- right_node
      trees[[t_idx]] <- tree
    }
    
    total_splits <- total_splits + 1
    
    # Update fitted predictions and residuals
    y_fitted <- predict_trees(trees, X)
    residuals <- y_num - y_fitted
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

# SSE reduction achieved by partitioning `res_sub` into `left_mask` and its
# complement, or NULL when either side holds fewer than `min_n` observations.
# `left_mask` must be a logical vector with no NA.
split_gain <- function(res_sub, ss_total, left_mask, min_n) {
  n_l <- sum(left_mask)
  n_r <- length(left_mask) - n_l
  if (n_l < min_n || n_r < min_n) return(NULL)
  res_l <- res_sub[left_mask]
  res_r <- res_sub[!left_mask]
  ss_total - (sum((res_l - mean(res_l))^2) + sum((res_r - mean(res_r))^2))
}

# Best split of the observations in `sample_indices` on the current residuals.
# Under na_method = "mia" a column with missing values also offers the three
# candidates of Twala et al. (2008): NA to the left of each cutpoint (A), NA
# to the right (B), and NA versus observed on its own (C). A column without
# missing values costs exactly what it did before.
find_best_split <- function(X, residuals, sample_indices, min_n = 5,
                            na_method = "omit") {
  if (length(sample_indices) < (2 * min_n)) return(NULL)

  res_sub <- residuals[sample_indices]
  ss_total <- sum((res_sub - mean(res_sub))^2)

  best_gain <- -Inf
  best_split <- NULL

  # Keep `left_mask` as the incumbent when its gain beats the best so far.
  consider <- function(left_mask, var_name, is_factor, split_val,
                       na_dir = NA_character_, split_on_missing = FALSE) {
    gain <- split_gain(res_sub, ss_total, left_mask, min_n)
    if (is.null(gain) || gain <= best_gain) return(invisible(NULL))
    best_gain <<- gain
    best_split <<- list(
      gain = gain, var_name = var_name, is_factor = is_factor,
      split_val = split_val, na_dir = na_dir, split_on_missing = split_on_missing,
      idx_left = sample_indices[left_mask], idx_right = sample_indices[!left_mask]
    )
    invisible(NULL)
  }

  for (j in seq_len(ncol(X))) {
    col_vals <- X[sample_indices, j]
    var_name <- colnames(X)[j]
    is_fac <- is.factor(col_vals) || is.character(col_vals)

    miss <- is.na(col_vals)
    obs <- !miss
    has_na <- na_method == "mia" && any(miss)

    # Split C: is the column missing or not, once per column.
    if (has_na) {
      consider(miss, var_name, is_fac, split_val = NA, split_on_missing = TRUE)
    }

    if (is_fac) {
      # Levels are taken from what is present in this node, not from the
      # declared level set: a factor with many unused levels would otherwise be
      # skipped as if it were high-cardinality. NA is never a level (D-F1).
      col_chr <- as.character(col_vals)
      levs <- levels(droplevels(as.factor(col_chr[obs])))
      if (length(levs) <= 1) next

      # For factors with <= 10 levels, test non-empty subsets
      if (length(levs) <= 10) {
        subsets <- get_factor_subsets(levs)
        for (sub in subsets) {
          in_sub <- obs & (col_chr %in% sub)
          if (has_na) {
            consider(in_sub | miss, var_name, TRUE, sub, na_dir = "left")
            consider(in_sub,        var_name, TRUE, sub, na_dir = "right")
          } else {
            consider(in_sub, var_name, TRUE, sub)
          }
        }
      }
    } else {
      # Continuous numeric feature
      # `as.numeric()` guards against integer overflow in the midpoints below,
      # which silently produces NA cutpoints for large integer predictors.
      col_num <- as.numeric(col_vals)
      x_obs <- col_num[obs]
      vals <- sort(unique(x_obs))
      if (length(vals) <= 1) next

      cutpoints <- (vals[-length(vals)] + vals[-1]) / 2
      if (length(cutpoints) > 30) {
        # Quantiles of the sample, not of `vals`: the unique values weight every
        # distinct level equally and so ignore where the data actually lie.
        cutpoints <- unique(stats::quantile(
          x_obs, probs = seq(0.05, 0.95, length.out = 30), names = FALSE
        ))
      }

      for (cut in cutpoints) {
        # `obs &` turns the NA comparisons into FALSE, so the masks never carry NA.
        below <- obs & (col_num <= cut)
        if (has_na) {
          consider(below | miss, var_name, FALSE, cut, na_dir = "left")
          consider(below,        var_name, FALSE, cut, na_dir = "right")
        } else {
          consider(below, var_name, FALSE, cut)
        }
      }
    }
  }

  if (best_gain <= 1e-6 || is.null(best_split)) return(NULL)
  return(best_split)
}

# Helper to predict sum of trees on new dataset X_new.
# Observations are routed as index sets, one node at a time, rather than one
# observation at a time: the engine re-predicts the whole sample after every
# accepted split, so this is the hot path of a fit.
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
                     node$feature, "`, which had none when the model was ",
                     "fitted, so no direction was learned for them. Impute ",
                     "them first (for example with `recipes::step_impute_*()`) ",
                     "or refit with `na_method = \"mia\"` on data that ",
                     "contain missing values."),
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
