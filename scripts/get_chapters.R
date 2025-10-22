source(here::here("scripts/utils.R"))

library(dplyr)
library(httpuv)

rladies_groups <- meetupr::get_pro_groups("rladies") |>
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
