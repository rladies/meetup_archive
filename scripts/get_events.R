# If not running interactively,
# get token decrypted from env var
if (!interactive()) {
  meetupr::meetup_ci_load()
}

source(here::here("scripts/utils.R"))

library(tidyr)
library(dplyr)
library(lubridate)

## Get events ----
new_events <- meetupr::get_pro_events(
  "rladies",
  status = "upcoming",
  handle_multiples = "first",
) |>
  transmute(
    id,
    title,
    description,
    status,
    duration,
    image_url = featured_event_photo_url,
    link = event_url,
    going = rsvps_yes_count,
    time = date_time,
    group_name,
    group_urlname,
    venue_name = venues_name,
    venue_address = venues_address,
    venue_city = venues_city,
    venue_country = venues_country,
    venue_lat = venues_lat,
    venue_lon = venues_lon
  )


cancelled <- meetupr::get_pro_events(
  "rladies",
  status = "cancelled"
) |>
  pull(id)


# Read in existing json data
existing_events <- jsonlite::read_json(
  here::here("data/events.json"),
  simplifyVector = TRUE
) |>
  filter(!id %in% new_events$id)

# Read in chapters
groups <- jsonlite::read_json(
  here::here("data/chapters.json")
)


# Create df for json -----
events <- new_events |>
  transmute(
    id,
    group_urlname,
    title = title,
    body = sprintf(
      "<h6 class='entry-title mt-2' style='font-size: 1.5em !important';>%s</h6><p><i class='fa fa-users'></i>&emsp;%s</p><p class='text-truncate'>%s</p><center><a href='%s' target='_blank'><button class='btn btn-primary'>Event page</button></center></a>",
      title,
      going,
      description,
      link
    ),
    start = as.character(lubridate::force_tz(time, "UTC")),
    ds = lubridate::as.duration(duration),
    end = as.character(time + (ds %||% lubridate::dhours(2))),
    date = format(time, "%Y-%m-%d"),
    image_url,
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
    location = gsub(", , |, $", "", location),
    type = tolower(status),
    lat = venue_lat %||% NA,
    lon = venue_lon %||% NA,
    description
  ) |>
  select(-ds) |>
  bind_rows(existing_events) |>
  distinct() |>
  mutate(
    type = if_else(
      id %in% cancelled,
      "cancelled",
      type
    )
  )

cat("\t writing 'data/events.json'\n")
jsonlite::write_json(
  x = events,
  path = here::here("data/events.json"),
  pretty = TRUE
)

cat("Writing 'data/events_updated.json'\n")
jsonlite::write_json(
  x = data.frame(
    date = Sys.time(),
    n_events_past = filter(
      events,
      type == "PAST"
    ) |>
      nrow()
  ),
  path = here::here(
    "data/events_updated.json"
  ),
  pretty = TRUE
)
