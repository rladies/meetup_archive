# If not running interactively,
# get token decrypted from env var
if (!interactive()) {
  source(here::here("scripts/meetup_auth.R"))
}

source(here::here("scripts/utils.R"))
library(tidyr)
library(dplyr)
library(lubridate)

## Get events ----
fetch_events <- purrr::insistently(
  ~ meetupr::get_pro_events(
    "rladies",
    status = "UPCOMING",
    extra_graphql = 'image{baseUrl}'
  ),
  purrr::rate_backoff(
    max_times = 20,
    pause_base = 5
  )
)

new_events <- fetch_events() |>
  rename(image_url = image_baseUrl)


cancelled <- meetupr::get_pro_events(
  "rladies",
  status = "CANCELLED"
)


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


# Create df for json
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
    start = as.character(force_tz(time, "UTC")),
    ds = lubridate::as.duration(duration),
    end = as.character(time + (ds %||% lubridate::dhours(2))),
    date = format(new_events$time, "%Y-%m-%d"),
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
      id %in% cancelled$id,
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
