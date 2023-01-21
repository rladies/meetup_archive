source(here::here("scripts/utils.R"))
library(meetupr)
library(dplyr)

get_groups <- function(){
  meetupr::get_pro_groups("rladies")
}

fetch_groups <- purrr::insistently(get_groups)

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
