source(here::here("scripts/utils.R"))

# If not running interactively,
# get token decrypted from env var
if (!interactive()) {
  source(here::here("scripts/meetup_auth.R"))
}

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
    members,
    lat = latitude,
    lon = longitude,
    timezone
  ) |>
  as_tibble()

jsonlite::write_json(
  rladies_groups,
  here::here("data/chapters_meetup.json"),
  pretty = TRUE,
  auto_unbox = TRUE
)
