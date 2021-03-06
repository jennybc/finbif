# as.data.frame methods --------------------------------------------------------

#' Coerce a `finbif_records*` object to a `data.frame`
#'
#' Converts the result of a FinBIF query to a `data.frame`.
#'
#' @param x A `finbif_records*` object.
#' @param ... Additional arguments. Not used.
#' @param locale Character. A locale to use for columns with localised data.
#' @param quiet Logical. If `TRUE` (default) suppress progress indicator of
#'   conversion.
#' @return A `data.frame`.
#' @examples \dontrun{
#'
#' # Download the latest records from FinBIF
#' # and convert to a `data.frame`
#' resp <- finbif_records()
#' df <- as.data.frame(resp)
#' }
#' @importFrom methods as
#' @importFrom utils txtProgressBar setTxtProgressBar
#' @export
as.data.frame.finbif_records <-
  function(x,  ..., locale = getOption("finbif_locale")) {

    cols <- attr(x, "select")
    url  <- x[["response"]][["url"]]
    time <- x[["response"]][["date"]]

    x <- x[["content"]][["results"]]

    lst <- lapply(
      cols,
      function(col) {
        type      <- var_names[col, "type"]
        type_na   <- methods::as(NA, type)
        single    <- var_names[col, "single"]
        localised <- var_names[col, "localised"]
        el_names <- strsplit(col, "\\.")[[1L]]
        if (single) return(vapply(x, get_el_recurse, type_na, el_names, type))
        ans <- lapply(x, get_el_recurse, el_names, type)
        ans <- lapply(ans, unlist)
        if (localised) ans <- vapply(ans, with_locale, type_na, locale)
        ans
      }
    )

    names(lst) <- cols
    cols_split <- split(cols, var_names[cols, "single"])
    cols_split[["TRUE"]] <- c("ind", cols_split[["TRUE"]])
    lst <- c(list(ind = seq_along(x)), lst)
    df <- as.data.frame(lst[cols_split[["TRUE"]]], stringsAsFactors = FALSE)
    df[cols_split[["FALSE"]]] <- lst[cols_split[["FALSE"]]]
    df[["ind"]] <- NULL
    structure(df[cols], url = url, time = time)

  }

#' @noRd
with_locale <- function(x, locale) {
  if (identical(length(x), 1L)) return(x[[1L]])
  x[[intersect(c(locale, setdiff(supported_langs, locale)), names(x))[[1L]]]]
}

#' @rdname as.data.frame.finbif_records
#' @export
as.data.frame.finbif_records_list <-
  function(x, ..., locale = getOption("finbif_locale"), quiet = TRUE) {

    n <- length(x)
    if (!quiet) {
      pb <- utils::txtProgressBar(0L, n, style = 3L)
      on.exit(close(pb))
    }

    df <- lapply(
      seq_len(n),
      function(i) {
        if (!quiet) utils::setTxtProgressBar(pb, i)
        as.data.frame(x[[i]], locale = locale)
      }
    )

    url  <- do.call(c, lapply(df, attr, "url", TRUE))
    time <- do.call(c, lapply(df, attr, "time", TRUE))

    df <- do.call(rbind, df)

    if (inherits(x, "finbif_records_sample_list")) {
      records <- if (attr(x, "cache")) {
        sample_with_seed(nrow(df), nrow(df), gen_seed(x))
      } else {
        sample.int(nrow(df))
      }
      df <- df[records, ]
    }

    if (!attr(x, "record_id")) df[["unit.unitId"]] <- NULL

    structure(df, url = url, time = time)

  }

# accessor methods -------------------------------------------------------------

#' @noRd
#' @export
`[.finbif_occ` <- function(x, i, j, drop = FALSE) {

  mdrop  <- missing(drop)
  n_args <- nargs() - !mdrop
  has_i  <- !missing(i)
  has_j  <- !missing(j)

  rows <- seq_len(nrow(x))
  cols <- seq_len(ncol(x))

  if (n_args < 3L) {
    if (has_i) cols <- i
  } else {
    if (has_j) cols <- j
    if (has_i) rows <- i
  }

  ans <- if (has_j) NextMethod("[", drop = drop) else NextMethod("[")
  ans <-
    structure(as.data.frame(ans, stringsAsFactors = FALSE), class = class(x))
  attr <- attributes(x)
  attr[["row.names"]] <- as.integer(rows)
  mostattributes(ans) <- attr
  names(ans) <- if (is.character(cols)) cols else names(x)[cols]
  ans
}

# print methods ----------------------------------------------------------------

#' @noRd
#' @importFrom utils str
#' @export
print.finbif_api <- function(x, ...) {
  cat("<FinBIF ", x[["path"]], ">\n", sep = "")
  utils::str(x[["content"]])
  invisible(x)
}

#' @noRd
#' @export
print.finbif_api_list <- function(x, ...) {
  cat("<FinBIF ", x[[1]][["path"]], ">\n", sep = "")
  utils::str(x[[1]][["content"]])
  invisible(x)
}

#' @noRd
#' @export
print.finbif_taxa <- function(x, ...) {
  ranks <- names(x)
  nms   <- names(unlist(unname(x)))
  padl  <- if (is.null(ranks)) 0L else max(nchar(ranks)) + 2L
  padr  <- if (is.null(nms)) 0L else max(nchar(nms))
  for (i in seq_along(x)) {
    rank <- ranks[[i]]
    for (j in seq_along(x[[i]])) {
      taxon <- x[[i]][j]
      nm <- names(taxon)
      nm <- ifelse(is.null(nm), "", nm)
      cat(
        sprintf(
          paste0(
            "[%-", padl, "s"), ifelse(is.null(rank), "", paste0(rank, ": ")
          )
        ),
        sprintf(paste0("%-", padr, "s] "), nm),
        ifelse(is.na(taxon), "Not found\n", sprintf("ID: %s\n", taxon)),
        sep = ""
      )
    }
  }
  invisible(x)
}

#' @noRd
#' @export
print.finbif_metadata_df <- function(x, ..., right = FALSE) {
  df <- x
  sl <- max(9L, getOption("width") / ncol(df))
  for (col in names(df)) {
    if (is.character(df[[col]])) {
      df[[col]] <- truncate_string(df[[col]], max(sl, nchar(col)))
    }
  }
  print.data.frame(df, ..., right = right)
  invisible(x)
}

#' @noRd
#' @importFrom utils hasName head
#' @export
print.finbif_occ <- function(x, ...) {

  nrec_dnld <- attr(x, "nrec_dnld")
  nrec_avl  <- attr(x, "nrec_avl")
  ncols     <- ncol(x)
  nrows     <- nrow(x)
  dsply_nr  <- min(10L, nrows)

  if (length(nrec_dnld)) cat("Records downloaded: ", nrec_dnld, "\n", sep = "")
  if (length(nrec_avl)) cat("Records available: ", nrec_avl, "\n", sep = "")
  cat("A data.frame [", nrows, " x ", ncols, "]\n", sep = "")

  df <- x[seq_len(dsply_nr), , drop = FALSE]

  colname_widths <- vapply(names(df), nchar, integer(1L))

  df <- format_cols(df, colname_widths)

  widths <- apply(df, 2L, nchar)
  # Printed NA values are four characters wide, "<NA>"
  widths[is.na(widths)] <- 4L
  widths <- apply(widths, 2L, max, na.rm = TRUE)
  widths <- pmax(colname_widths, widths)

  dsply_nc <- 0L
  cumulative_width <- if (dsply_nr > 9L) 2L else 1L

  for (i in widths) {
    ind <- dsply_nc + 1L
    cumulative_width <- cumulative_width + 1L + widths[[ind]]
    if (cumulative_width > getOption("width")) break
    dsply_nc <- ind
  }

  dsply_cols <- seq_len(dsply_nc)

  df <- df[, dsply_cols]

  print.data.frame(df)

  extra_rows <- nrows - dsply_nr
  extra_cols <- ncols - dsply_nc

  print_extras(x, extra_rows, extra_cols, dsply_cols)

  invisible(x)

}

#' @noRd
format_cols <- function(df, colname_widths) {

  for (i in names(df)) {

    ind <- var_names[[if (attr(df, "dwc")) "dwc" else "translated_var"]] == i
    class  <- var_names[ind, "class"]
    single <- var_names[ind, "single"] || var_names[ind, "localised"]

    # Variables may not necessarily be in the var_names object
    if (length(class))
      if (!single) {
        df[[i]] <- vapply(
          df[[i]],
          function(x) length(Filter(isFALSE, is.na(x))), integer(1L)
        )
        df[[i]] <-
          paste0(df[[i]], " element", ifelse(length(df[[i]]) == 1L, "", "s"))
      } else {
        if (class == "uri") df[[i]] <- truncate_string_to_unique(df[[i]])
        if (class %in% c("character", "uri", "factor"))
          df[[i]] <- truncate_string(df[[i]])
        if (class %in% c("double", "integer"))
          df[[i]] <- formatC(
            df[[i]],
            colname_widths[[i]] - 2L, colname_widths[[i]],
            flag = "- "
          )
      }

  }

  df

}

#' @noRd
print_extras <- function(x, extra_rows, extra_cols, dsply_cols) {

  if (extra_rows == 0L && extra_cols == 0L) return(NULL)

  cat(
    "...with ", extra_rows, " more record", if (extra_rows == 1L) "" else "s",
    sep = ""
  )

  if (extra_cols == 0L) {
    cat("\n")
    return(NULL)
  }

  cat(
    " and ", extra_cols, " more variable", if (extra_cols == 1L) "" else "s",
    ":\n", sep = ""
  )

  # Can't tell in advance what the var names will be
  i <- 1L
  extra_names <- names(x)[-dsply_cols]
  cat(extra_names[[i]])
  nchars <- nchar(extra_names[[i]]) + 2L

  for (i in seq_along(extra_names)[-1L]) {
    nchars_ <- nchar(extra_names[[i]]) + 2L
    nchars  <- nchars + nchars_
    if (nchars > getOption("width")) {
      cat(",\n")
      nchars <- nchars_
    } else {
      cat(", ")
    }
    cat(extra_names[[i]])
  }

  cat("\n")
  NULL
}

# plot methods ----------------------------------------------------------------

#' @noRd
#' @importFrom graphics grid plot.default
#' @export
plot.finbif_occ <- function(
  x, ..., xlab = "Longitude", ylab = "Latitude",
  panel.first = grid(lwd = 2), # nolint
  asp = 1 / cos(mean(range(x["lat_wgs84"])) * pi / 180),
  pch = 19, cex = .5, las = 1
) {
  stopifnot(exists("lon_wgs84", x) && exists("lat_wgs84", x))
  graphics::plot.default(
    x[c("lon_wgs84", "lat_wgs84")], ..., xlab = xlab, ylab = ylab,
    panel.first = panel.first, asp = asp, cex = .5, las = 1, pch = pch
  )
}
