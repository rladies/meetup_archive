library(dplyr)
library(tidyr)
library(ggplot2)
library(lubridate)
library(jsonlite)
library(here)
library(stringr)
library(rmarkdown)

# Load data
events <- read_json(
  here("data/events.json"),
  simplifyVector = TRUE
)
chapters <- read_json(
  here("data/chapters.json"),
  simplifyVector = TRUE
)

# R-Ladies brand colors
rladies_colors <- list(
  purple = "#88398A",
  dark_purple = "#562457",
  light_purple = "#F4A6D7",
  grey = "#d3d3d3",
  black = "#222222"
)

# R-Ladies ggplot2 theme
theme_rladies <- function(base_size = 12) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title = element_text(
        color = rladies_colors$purple,
        face = "bold",
        size = rel(1.2)
      ),
      plot.subtitle = element_text(
        color = rladies_colors$dark_purple,
        size = rel(1)
      ),
      axis.title = element_text(color = rladies_colors$dark_purple),
      panel.grid.minor = element_blank(),
      legend.position = "bottom"
    )
}

# Set as default theme
theme_set(theme_rladies())

# R-Ladies color scale for discrete values
scale_fill_rladies <- function(...) {
  scale_fill_manual(
    values = unlist(rladies_colors),
    ...
  )
}

scale_color_rladies <- function(...) {
  scale_color_manual(
    values = unlist(rladies_colors),
    ...
  )
}

# Helper functions
calculate_active_chapters <- function(events, months = 6) {
  cutoff_date <- Sys.Date() - months(months)
  events |>
    mutate(event_date = as.Date(date)) |>
    filter(
      event_date >= cutoff_date,
      !type %in% c("cancelled", "CANCELLED")
    ) |>
    distinct(group_urlname) |>
    nrow()
}
