source(here::here("scripts/utils.R"))

library(tidyr)
library(dplyr)
library(lubridate)

events <- list.files(
  here::here("archive", "raw_data"),
  "events_.*\\.json$",
  full.names = TRUE
) |>
  lapply(jsonlite::read_json) |>
  unlist(recursive = FALSE)


website_events <- purrr::map_df(events, function(x) {
  venues <- x$venues
  if (is.null(venues) || length(venues) == 0) {
    x$venues <- list(list(
      name = NA_character_,
      address = NA_character_,
      city = NA_character_,
      country = NA_character_,
      lat = NA_real_,
      lon = NA_real_
    ))
  }

  dplyr::tibble(
    id = x$id,
    title = x$title,
    description = x$description,
    status = tolower(x$status),
    image_url = if (!is.null(x$featured_event_photo)) {
      x$featured_event_photo$highres_link
    } else {
      NA_character_
    },
    link = x$eventUrl,
    going = x$rsvps$yesCount,

    duration = lubridate::as.duration(x$duration),
    datetime = lubridate::as_datetime(x$dateTime, tz = "UTC"),
    date = format(datetime, "%Y-%m-%d"),

    start = format(datetime, "%H:%M"),
    end = datetime + (duration %||% lubridate::dhours(2)),
    original_tz = substr(x$dateTime, 20, 26),

    group_name = x$group$name,
    group_urlname = x$group$urlname,

    venue_name = x$venues[[1]]$name,
    venue_address = x$venues[[1]]$address,
    venue_city = x$venues[[1]]$city,
    venue_country = country_name(x$venues[[1]]$country),
    venue_lat = x$venues[[1]]$lat,
    venue_lon = x$venues[[1]]$lon,
    location = ifelse(
      is.na(venue_name),
      "Not announced",
      paste(
        venue_name,
        venue_address %||% "",
        venue_city %||% "",
        toupper(venue_country) %||% "",
        sep = ", "
      )
    ),

    body = sprintf(
      "<h6 class='entry-title mt-2' style='font-size: 1.5em !important';>%s</h6><p><i class='fa fa-users'></i>&emsp;%s</p><p class='text-truncate'>%s</p><center><a href='%s' target='_blank'><button class='btn btn-primary'>Event page</button></center></a>",
      title,
      going,
      description,
      link
    )
  ) |>
    dplyr::mutate(
      end = format(end, "%H:%M"),
      location = gsub(", , |, $", "", location)
    )
})

# Create df for json -----
cli::cli_alert_info("Writing events data")
jsonlite::write_json(
  x = website_events,
  path = here::here("data/events.json"),
  pretty = TRUE
)

cli::cli_alert_info("Writing update note")
jsonlite::write_json(
  x = list(
    date = Sys.time(),
    n_events_past = dplyr::filter(
      website_events,
      status == "past"
    ) |>
      nrow()
  ),
  path = here::here(
    "data/updated.json"
  ),
  pretty = TRUE
)

# Read in chapters
cli::cli_alert_info("Processing chapters data")
chapters <- jsonlite::read_json(
  here::here("archive/raw_data/chapters.json")
) |>
  purrr::map(function(.x) {
    list(
      id = .x$id,
      name = .x$name,
      urlname = .x$urlname,
      country = country_name(.x$country),
      country_acronym = .x$country,
      state = .x$state,
      city = .x$city,
      members = .x$memberships_count,
      lat = .x$lat,
      lon = .x$lon,
      timezone = .x$timezone
    )
  })

jsonlite::write_json(
  chapters,
  path = here::here("data/chapters.json"),
  pretty = TRUE,
  auto_unbox = TRUE
)
