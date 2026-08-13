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
#' outcome using the same sum-of-squares criterion, and the raw score is mapped
#' to a probability with the logistic function at prediction time.
#'
#' @param formula A formula specifying outcome and predictor variables.
#' @param data A data frame containing training data.
#' @param max_splits Integer. Maximum total number of splits across all trees in the sum. Default is 10.
#' @param max_trees Integer. Maximum number of trees allowed in the sum. Default is NULL (unconstrained up to max_splits).
#' @param min_n Integer. Minimum number of observations required in a node to split. Default is 5.
#' @param mode Character. Either `"regression"` or `"classification"`. Only
#'   two-class outcomes are supported in classification mode. Default is
#'   `"regression"`.
#' @param ... Additional arguments.
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
figs <- function(formula, data, max_splits = 10, max_trees = NULL, min_n = 5, mode = "regression", ...) {
  cl <- match.call()
  
  if (!is.data.frame(data)) {
    stop("`data` must be a data frame.", call. = FALSE)
  }
  
  mf <- stats::model.frame(formula = formula, data = data)
  y <- stats::model.response(mf)
  X <- mf[, -1, drop = FALSE]
  
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
    formula = formula,
    call = cl
  )
}

# Engine implementation
fit_figs_engine <- function(X, y, max_splits = 10, max_trees = NULL, min_n = 5, mode = "regression", formula = NULL, call = NULL) {
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
      split_new <- find_best_split(X, residuals, seq_len(n), min_n = min_n)
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
            split_cand <- find_best_split(X, residuals, node$sample_indices, min_n = min_n)
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

      left_node <- make_node(
        id = next_id, value = mean(residuals[sp$idx_left]), sample_indices = sp$idx_left
      )
      right_node <- make_node(
        id = next_id + 1, value = mean(residuals[sp$idx_right]), sample_indices = sp$idx_right
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
  
  fitted_vals <- predict_trees(trees, X)
  
  res <- list(
    trees = trees,
    mode = mode,
    classes = classes,
    max_splits = max_splits,
    total_splits = total_splits,
    feature_names = colnames(X),
    fitted_values = fitted_vals,
    formula = formula,
    call = call
  )
  
  class(res) <- "figsr_fit"
  return(res)
}

# Constructor guaranteeing every node carries the same field set, so consumers
# never have to test for missing components.
make_node <- function(id, is_leaf = TRUE, feature = NULL, is_factor = FALSE,
                      split_val = NULL, left_child = NULL, right_child = NULL,
                      gain = 0, value = 0, sample_indices = integer(0)) {
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
    sample_indices = sample_indices
  )
}

# Helper to find best split for a leaf subset
find_best_split <- function(X, residuals, sample_indices, min_n = 5) {
  if (length(sample_indices) < (2 * min_n)) return(NULL)
  
  res_sub <- residuals[sample_indices]
  ss_total <- sum((res_sub - mean(res_sub))^2)
  
  best_gain <- -Inf
  best_split <- NULL
  
  for (j in seq_len(ncol(X))) {
    col_vals <- X[sample_indices, j]
    var_name <- colnames(X)[j]
    is_fac <- is.factor(col_vals) || is.character(col_vals)
    
    if (is_fac) {
      col_fac <- as.factor(col_vals)
      levs <- levels(col_fac)
      if (length(levs) <= 1) next
      
      # For factors with <= 10 levels, test non-empty subsets
      if (length(levs) <= 10) {
        subsets <- get_factor_subsets(levs)
        for (sub in subsets) {
          left_mask <- col_fac %in% sub
          right_mask <- !left_mask
          n_l <- sum(left_mask)
          n_r <- sum(right_mask)
          if (n_l < min_n || n_r < min_n) next
          
          res_l <- res_sub[left_mask]
          res_r <- res_sub[right_mask]
          ss_l <- sum((res_l - mean(res_l))^2)
          ss_r <- sum((res_r - mean(res_r))^2)
          gain <- ss_total - (ss_l + ss_r)
          
          if (gain > best_gain) {
            best_gain <- gain
            best_split <- list(
              gain = gain, var_name = var_name, is_factor = TRUE,
              split_val = sub, idx_left = sample_indices[left_mask], idx_right = sample_indices[right_mask]
            )
          }
        }
      }
    } else {
      # Continuous numeric feature
      vals <- sort(unique(col_vals))
      if (length(vals) <= 1) next
      
      cutpoints <- (vals[-length(vals)] + vals[-1]) / 2
      if (length(cutpoints) > 30) {
        cutpoints <- stats::quantile(vals, probs = seq(0.05, 0.95, length.out = 30))
      }
      
      for (cut in cutpoints) {
        left_mask <- col_vals <= cut
        right_mask <- !left_mask
        n_l <- sum(left_mask)
        n_r <- sum(right_mask)
        if (n_l < min_n || n_r < min_n) next
        
        res_l <- res_sub[left_mask]
        res_r <- res_sub[right_mask]
        ss_l <- sum((res_l - mean(res_l))^2)
        ss_r <- sum((res_r - mean(res_r))^2)
        gain <- ss_total - (ss_l + ss_r)
        
        if (gain > best_gain) {
          best_gain <- gain
          best_split <- list(
            gain = gain, var_name = var_name, is_factor = FALSE,
            split_val = cut, idx_left = sample_indices[left_mask], idx_right = sample_indices[right_mask]
          )
        }
      }
    }
  }
  
  if (best_gain <= 1e-6 || is.null(best_split)) return(NULL)
  return(best_split)
}

# Helper to predict sum of trees on new dataset X_new
predict_trees <- function(trees, X_new) {
  if (length(trees) == 0) return(numeric(nrow(X_new)))
  
  total_pred <- numeric(nrow(X_new))
  for (tree in trees) {
    for (i in seq_len(nrow(X_new))) {
      node <- tree[[1]]
      while (!node$is_leaf) {
        var_name <- node$feature
        val <- node$split_val
        x_val <- X_new[i, var_name]
        
        if (node$is_factor) {
          is_left <- as.character(x_val) %in% as.character(val)
        } else {
          is_left <- (x_val <= val)
        }
        
        if (is_left) {
          node <- tree[[node$left_child]]
        } else {
          node <- tree[[node$right_child]]
        }
      }
      total_pred[i] <- total_pred[i] + node$value
    }
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
