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


# Remove columns with only NA's
na_col_rm <- function(x) {
  indx <- apply(x, 2, function(y) all(is.na(y)))
  as_tibble(x[, !indx])
}

country_name <- function(code) {
  countrycode::countrycode(
    code,
    origin = "iso2c",
    destination = "un.name.en"
  )
}
