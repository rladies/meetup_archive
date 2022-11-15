source(here::here("scripts/utils.R"))

pkgs <- sapply(c("meetupr", "tidyr", "dplyr", "lubridate"),
               load_lib)

## Get events ----

new_events <- meetupr::get_pro_events(
  "rladies",
  status = "UPCOMING",
  extra_graphql = 'image{baseUrl}'
) |> 
  rename(image_url = image_baseUrl)

cancelled <- meetupr::get_pro_events(
  "rladies",
  status = "CANCELLED"
  )


# Read in existing json data
existing_events <- jsonlite::read_json(
  here::here("data/events.json"),
  simplifyVector = TRUE) |>
  filter(!id %in% new_events$id)


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
    type = status,
    lat = venue_lat %||% NA,
    lon = venue_lon %||% NA,
    description
  ) |>
  select(-ds) |>
  bind_rows(existing_events) |>
  distinct() |> 
  mutate(
    status = if_else(id %in% cancelled$id,
                     "cancelled", status)
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
    n_events_past = filter(events, type  == "PAST") |> nrow(),
  ),
  path = here::here("data/events_updated.json"),
  pretty = TRUE
)
