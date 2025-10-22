library(httpuv)

# Define helper functions ----
# change empty to NA
change_empty <- function(x) {
  ifelse(x == "", NA, x)
}

# default value if given is NA
`%||%` <- function(a, b) {
  ifelse(!is.na(a), a, b)
}

# Clean-up chapter name and create link
get_chapter <- function(x) {
  y <- sapply(x, function(x) strsplit(x, "/")[[1]][4])
  unname(y)
}

# Force UTC timezone
force_utc <- function(datetime, tz) {
  x <- as_datetime(datetime, tz = tz)
  with_tz(x, "UTC")
}

# Remove columns with only NA's
na_col_rm <- function(x) {
  indx <- apply(x, 2, function(y) all(is.na(y)))
  as_tibble(x[, !indx])
}
