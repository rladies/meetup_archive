archive_window_start <- function(now = Sys.time(), days = 90) {
  lubridate::floor_date(
    lubridate::with_tz(now, "UTC") - lubridate::days(days),
    "day"
  )
}

event_datetime <- function(events) {
  vapply(events, `[[`, character(1), "dateTime") |>
    lubridate::ymd_hms(quiet = TRUE)
}

event_year <- function(events) {
  substr(vapply(events, `[[`, character(1), "dateTime"), 1, 4)
}

merge_events <- function(archived, fetched, window_start) {
  if (length(fetched) == 0) {
    cli::cli_abort(c(
      "Meetup returned no events since {format(window_start, '%Y-%m-%d')}.",
      "x" = "Refusing to drop the archived events in that window."
    ))
  }
  fetched_ids <- vapply(fetched, `[[`, character(1), "id")
  archived_at <- event_datetime(archived)
  keep <- (is.na(archived_at) | archived_at < window_start) &
    !vapply(archived, `[[`, character(1), "id") %in% fetched_ids
  c(fetched, archived[keep])
}

split_events_by_year <- function(events) {
  split(events, event_year(events))
}
