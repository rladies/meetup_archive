source(here::here("scripts/utils.R"))
library(meetupr)
library(dplyr)

fetch_groups <- purrr::insistently(
  ~meetupr::get_pro_groups("rladies"), 
  purrr::rate_backoff(
    max_times = 20,
    pause_base = 5
  )
)

rladies_groups <- fetch_groups() |> 
  rename(country_acronym = country) |> 
  distinct() |> 
  transmute(name, 
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

jsonlite::write_json(rladies_groups, 
                     here::here("data/chapters.json"),
                     pretty = TRUE,
                     auto_unbox = TRUE)
