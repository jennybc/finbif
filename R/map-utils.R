#' 2-Dimensional Histogram
#'
#' Compute a histogram from xy data given set of breakpoints.
#'
#' @param xy Numeric. A `data.frame`, or object coercible to a `data.frame`
#'   with `as.data.frame()`, where the columns of the `data.frame` are,
#'   or can be, interpreted as XY coordinates.
#' @param breaks List. A list of vectors, one for each dimension of `xy`, where
#'   each vector gives the breakpoints between the histogram cells.
#'
#' @return A list with three components:
#' - `x` The X dimension breakpoints.
#' - `y` The Y dimension breakpoints.
#' - `z` A frequency table of the number of `xy` points in each cell.
#'
#' @examples
#' hist_xy(matrix(runif(50), 25), list(seq(0, 1, .2), seq(0, 1, .2)))
#' @export
hist_xy <- function(xy, breaks) {
  xy <- as.data.frame(xy)
  colnames(xy) <- c("x", "y")
  freq <- mapply(in_intervals, xy, breaks, SIMPLIFY = FALSE)
  list(x = breaks[[1]], y = breaks[[2]], z = table(freq))
}

#' @noRd
in_intervals <- function(x, breaks) {
  n <- length(breaks) - 1L
  factor(findInterval(x, breaks), seq_len(n))
}

#' Create XY Breakpoints
#'
#' Creates sets of equally spaced breakpoints for XY coordinate data.
#'
#' @param bbox Numeric vector. A vector of points of the form,
#'   `c(xmin, ymin, xmax, ymax)` giving the outer limits of the breakpoints when
#'   expanded to nearest multiple of `size`.
#' @param size Numeric. The size of the cells between the breakpoints.
#'
#' @return A list with two components:
#' - `x` The X dimension breakpoints.
#' - `y` The Y dimension breakpoints.
#' @examples
#' breaks_xy(c(5, -45, 67, 100), 10)
#' @export
breaks_xy <- function(bbox, size) {
  bbox <- bbox / size
  bbox[1:2] <- floor(bbox[1:2])
  bbox[3:4] <- ceiling(bbox[3:4])
  bbox <- bbox * size
  list(x = seq(bbox[[1]], bbox[[3]], size), y = seq(bbox[[2]], bbox[[4]], size))
}
