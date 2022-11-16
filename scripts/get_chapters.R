source(here::here("scripts/utils.R"))
library(meetupr)
library(dplyr)

cat("Retrieving R-Ladies group information\n")
rladies_groups <- meetupr::get_pro_groups("rladies") |> 
  rename(country_acronym = country) |> 
  distinct()

chapters <- read.table(
  "https://raw.githubusercontent.com/rladies/starter-kit/master/Current-Chapters.csv", 
  sep = ",", header = TRUE, stringsAsFactors = FALSE) |>
  as_tibble() |> 
  rename_all(tolower) |> 
  mutate(urlname = basename(meetup))  |> 
  select(-state.region, -city, -current_organizers) |> 
  select(urlname, status, country, everything()) |> 
  mutate(
    across(-c(website, slack), basename),
    across(where(is.character), change_empty),
    github = file.path("rladies", github)
  )

some_cols <- chapters |> 
  select(-urlname, -status, -country, -former_organizers) |> 
  names()

# Create chapters json
to_file <- chapters |> 
  left_join(rladies_groups, by = "urlname") |> 
  nest_by(across(-all_of(some_cols)), .key = "social_media") |> 
  ungroup() |> 
  transmute(name, 
            id,
            urlname,
            country,
            state, 
            city,
            members,
            status,
            lat = latitude,
            lon = longitude,
            timezone,
            status_text = status,
            status = ifelse(grepl("Retired", status),
                            "retired", tolower(status)),
            social_media = lapply(social_media, na_col_rm) 
  ) |> 
 # filter(status == "active") |> 
  nest_by(country, .key = "chapters")

cat("\t writing 'data/chapters.json'\n")
jsonlite::write_json(to_file, 
                     here::here("data/chapters.json"),
                     pretty = TRUE)
