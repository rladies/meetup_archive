
source(here::here("scripts/utils.R"))
pkgs <- sapply(c("meetupr", "dplyr"), load_lib)

cat("Retrieving R-Ladies group information\n")
# Better than getting pro groups, because we want timezone...
rladies_groups <- meetupr::get_pro_groups("rladies") |> 
  #filter(name == "R-Ladies Global") |> 
  rename(country_acronym = country) |> 
  distinct()

chapters <- read.table(
  "https://raw.githubusercontent.com/rladies/starter-kit/master/Current-Chapters.csv", 
  sep = ",", header = TRUE, stringsAsFactors = FALSE) |>
  as_tibble() |> 
  mutate(urlname = basename(Meetup))  |> 
  select(-State.Region, -City, -Current_Organizers) |> 
  select(urlname, Status, Country, everything()) |> 
  mutate(across(-all_of(c("Website", "Slack")), basename)) |> 
  mutate(across(where(is.character), change_empty)) |> 
  rename_all(tolower) |> 
  mutate(github = file.path("rladies", github))

some_cols <- names(chapters)[-1:-3]

# Create chapters json
to_file <- chapters |> 
  left_join(rladies_groups, by="urlname") |> 
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
  filter(status == "active") |> 
  nest_by(country, .key = "chapters")

cat("\t writing 'data/chapters.json'\n")
jsonlite::write_json(to_file, 
                     here::here("data/chapters.json"),
                     pretty = TRUE)
