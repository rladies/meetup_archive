source(here::here("scripts/utils.R"))

library(dplyr)

fetch_groups <- purrr::insistently(
  ~ meetupr::get_pro_groups("rladies"),
  purrr::rate_backoff(
    max_times = 20,
    pause_base = 5
  )
)

rladies_groups <- fetch_groups() |>
  rename(country_acronym = country) |>
  distinct() |>
  transmute(
    name,
    id,
    urlname,
    country_acronym,
    state,
    city,
    members = memberships_count,
    lat,
    lon,
    timezone
  ) |>
  as_tibble()

jsonlite::write_json(
  rladies_groups,
  here::here("data/chapters_meetup.json"),
  pretty = TRUE,
  auto_unbox = TRUE
)
