#' Dials Parameter for Maximum Splits
#'
#' @param range A numeric vector of length 2 for lower and upper limits.
#' @param trans A trans object.
#'
#' @return A `dials` parameter object.
#' @export
max_splits <- function(range = c(2L, 20L), trans = NULL) {
  dials::new_quant_param(
    type = "integer",
    range = range,
    inclusive = c(TRUE, TRUE),
    trans = trans,
    label = c(max_splits = "Maximum Total Tree Splits"),
    finalize = NULL
  )
}

#' Dials Parameter for Maximum Trees
#'
#' @param range A numeric vector of length 2 for lower and upper limits.
#' @param trans A trans object.
#'
#' @return A `dials` parameter object.
#' @export
max_trees <- function(range = c(1L, 10L), trans = NULL) {
  dials::new_quant_param(
    type = "integer",
    range = range,
    inclusive = c(TRUE, TRUE),
    trans = trans,
    label = c(max_trees = "Maximum Number of Trees in Sum"),
    finalize = NULL
  )
}
