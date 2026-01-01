#!/usr/bin/env Rscript

# Archive R-Ladies Meetup Data (Raw JSON - GDPR Compliant)
# Creates timestamped archives using raw GraphQL responses
# Excludes personally identifiable information (member names, etc.)

library(dplyr)
library(purrr)
library(cli)
library(jose)

# Setup -------------------------------------------------------------------

# Create archive directory structure
archive_dir <- here::here("archive")

paths <- file.path(
  archive_dir,
  c("raw_data", "inactive_chapters")
) |>
  lapply(
    dir.create,
    showWarnings = FALSE,
    recursive = TRUE
  )


# Timestamp for this archive run
time <- Sys.time()
timestamp <- format(time, "%Y%m%d_%H%M%S")
time_str <- format(time, "%Y-%m-%d %H:%M:%S")
date_str <- format(time, "%Y-%m-%d")

cli_h1("R-Ladies Meetup Archive")
cli_alert_info("Starting archive process at {time_str}")

# Fetch All Events via Pro Network ----------------------------------------

cli_h2("Fetching all events via Meetup API")

cli_progress_step("Fetching events")
events_raw <- meetupr::get_pro_events(
  "rladies",
  asis = TRUE,
  date_after = sprintf("%s-01-01T00:00:00Z", format(time, "%Y")),
)

# Extract chapter list for processing
events <- events_raw |>
  map(~ .x$node)


# Split into yearly events files
# ---------------------------------

years <- unique(format(
  as.POSIXct(
    map_chr(events, "dateTime"),
    format = "%Y-%m-%dT%H:%M:%S"
  ),
  "%Y"
))

for (yr in years) {
  yearly_events <- events |>
    keep(function(event) {
      event_year <- format(
        as.POSIXct(event$dateTime, format = "%Y-%m-%dT%H:%M:%S"),
        "%Y"
      )
      event_year == yr
    })

  yearly_file <- here::here(
    archive_dir,
    "raw_data",
    paste0("events_", yr, ".json")
  )
  jsonlite::write_json(
    yearly_events,
    yearly_file,
    pretty = TRUE,
    auto_unbox = TRUE
  )
  cli_alert_success(
    "Saved {.val {length(yearly_events)}} events for year {yr}: {.file {basename(yearly_file)}}"
  )
}

all_events <- here::here(archive_dir, "raw_data") |>
  list.files(
    pattern = "^events_.*\\.json$",
    full.names = TRUE
  ) |>
  lapply(jsonlite::read_json) |>
  unlist(recursive = FALSE) |>
  c(events)


# Fetch Raw Chapter Data --------------------------------------------------

cli_h2("Fetching chapter data from Meetup")

# GraphQL query for pro network members (chapters)
chapters_query <- '
query proGroups(
  $urlname: ID!,
  $first: Int = 1000,
  $cursor: String
  ) {
  proNetwork(urlname: $urlname) {
    groupsSearch(input: {
      after: $cursor, 
      first: $first
      }) {
      totalCount
      pageInfo {
        hasNextPage
        endCursor
      }
      edges {
        node {
          id
          name
          urlname
          description
          lat
          lon
          city
          state
          country
          memberships {
            totalCount
          }
          foundedDate
          proJoinDate
          timezone
          joinMode
          who: customMemberLabel
          isPrivate
        }
      }
    }
  }
}
'

chapters_raw <- meetupr::meetupr_query(
  graphql = chapters_query,
  urlname = "rladies"
)
chapters_raw <- chapters_raw$data$proNetwork$groupsSearch$edges

# Extract chapter list for processing
chapters <- chapters_raw |>
  map(~ .x$node)

# Map any mangled/new Meetup urlnames back to the original (archived) urlname
# The JSON `old-chapters-map.json` contains entries where
#  - `urlname` is the current/mangled value (e.g. "notopic@544550") and
#  - `orig_urlname` is the original, human-friendly name (e.g. "rladies-curitiba").
# If a chapter currently has the mangled urlname, replace it with the original
# so archived directories use the familiar names.
map_urls <- jsonlite::read_json(here::here(
  "archive",
  "old-chapters-map.json"
))

chapters <- map(chapters, function(chapter) {
  # find entries where the map's `urlname` equals this chapter's urlname
  idx <- which(map_chr(map_urls, "urlname") == chapter$urlname)
  if (length(idx) > 0) {
    chapter$urlname <- map_urls[[idx]]$orig_urlname
  }
  chapter
})

# Helper to normalize any urlname (map current/mangled -> orig if present)
normalize_urlname <- function(u) {
  # handle vectorized input
  u_chr <- as.character(u)
  map_mangled <- map_chr(map_urls, "urlname")
  map_orig <- map_chr(map_urls, "orig_urlname")
  idx <- match(u_chr, map_mangled)
  res <- u_chr
  res[!is.na(idx)] <- map_orig[idx[!is.na(idx)]]
  res
}

# Define inactive as no events in last 12 months
inactive_cutoff <- Sys.Date() - lubridate::years(1)

# Parse events to find last activity per chapter
chapter_event_summary <- map_df(all_events, function(event) {
  tibble(
    urlname = normalize_urlname(event$group$urlname),
    event_date = as.Date(event$dateTime)
  )
}) |>
  group_by(urlname) |>
  summarise(
    n_events = n(),
    last_event_date = max(event_date, na.rm = TRUE),
    total_past_events = n(),
    first_event_date = min(event_date, na.rm = TRUE),
    status = if_else(
      is.finite(last_event_date) & last_event_date >= inactive_cutoff,
      "active",
      "inactive"
    ),
    .groups = "drop"
  )

chapters <- map(chapters, function(chapter) {
  idx <- which(chapter_event_summary$urlname %in% chapter$urlname)
  if (length(idx) > 0) {
    chapter$events <- list(
      totalCount = chapter_event_summary$n_events[idx],
      first_event = chapter_event_summary$first_event_date[idx],
      last_event = chapter_event_summary$last_event_date[idx]
    )
    chapter$status <- chapter_event_summary$status[idx]
  } else {
    chapter$events <- list(
      totalCount = 0,
      first_event = NA,
      last_event = NA
    )
    chapter$status <- "inactive"
  }
  return(chapter)
})

# Save raw chapters response
chapters_file <- here::here(
  archive_dir,
  "raw_data",
  "chapters.json"
)
jsonlite::write_json(
  chapters,
  chapters_file,
  pretty = TRUE,
  auto_unbox = TRUE
)
cli_alert_success("Saved raw chapters data: {.file {basename(chapters_file)}}")

cli_alert_info(
  "Found {.strong {length(chapters)}} chapters in R-Ladies network"
)


# Identify Inactive Chapters ----------------------------------------------

cli_h2("Identifying inactive chapters")

inactive_chapters <- chapter_event_summary |>
  filter(status == "inactive") |>
  arrange(last_event_date)

cli_alert_warning(
  "Found {.strong {nrow(inactive_chapters)}} inactive chapters (no events in 12+ months)"
)

# Archive Inactive Chapter Data -------------------------------------------

if (nrow(inactive_chapters) > 0) {
  cli_h3("Archiving inactive chapter data")

  for (chapter in inactive_chapters$urlname) {
    cli::cli_text("")
    cli::cli_rule("{.strong {chapter}}")
    # Create chapter-specific directory (normalize any pre-existing mangled dirs)
    chapter_dir <- here::here(archive_dir, "inactive_chapters", chapter)

    # If a previous run created a mangled directory name, try to move/merge it
    mangled_candidates <- map_chr(map_urls, "urlname")[
      map_chr(map_urls, "orig_urlname") == chapter
    ]
    for (m in mangled_candidates) {
      old_dir <- here::here(archive_dir, "inactive_chapters", m)
      if (dir.exists(old_dir) && !dir.exists(chapter_dir)) {
        file.rename(old_dir, chapter_dir)
      } else if (dir.exists(old_dir) && dir.exists(chapter_dir)) {
        # move missing files (events.json, metadata.json) into normalized dir
        for (f in c("events.json", "metadata.json")) {
          oldf <- file.path(old_dir, f)
          newf <- file.path(chapter_dir, f)
          if (file.exists(oldf) && !file.exists(newf)) {
            file.rename(oldf, newf)
          }
        }
        # remove old dir if empty
        if (length(list.files(old_dir, all.files = TRUE, no.. = TRUE)) == 0) {
          unlink(old_dir, recursive = TRUE)
        }
      }
    }

    dir.create(chapter_dir, showWarnings = FALSE, recursive = TRUE)

    # Extract events for this chapter from the full events list using normalized urlnames
    evt_indx <- map_lgl(all_events, function(event) {
      normalize_urlname(event$group$urlname) == chapter
    }) |>
      which()

    event_info <- inactive_chapters |> filter(urlname == chapter) |> as.list()
    event_info$urlname <- NULL

    chapter_events <- all_events[evt_indx]

    if (length(chapter_events) > 0) {
      cli::cli_alert_success(
        "Archiving {.val {length(chapter_events)}} events."
      )
      chapter_events_file <- here::here(chapter_dir, "events.json")
      jsonlite::write_json(
        chapter_events,
        chapter_events_file,
        pretty = TRUE,
        auto_unbox = TRUE
      )
    }

    chapter_idx <- map_lgl(chapters, function(x) {
      x$urlname == chapter
    }) |>
      which()

    if (length(chapter_idx) > 0) {
      chapter_metadata_file <- here::here(
        chapter_dir,
        "metadata.json"
      )

      pluck(chapters, chapter_idx) |>
        jsonlite::write_json(
          chapter_metadata_file,
          pretty = TRUE,
          auto_unbox = TRUE
        )
      cli::cli_alert_success(
        "Archiving chapter metadata."
      )
    } else {
      cli_alert_danger(
        "Chapter metadata not found."
      )
    }
  }
}


# Post-process: normalize any remaining mangled inactive chapter directories
cli_h2("Normalizing leftover mangled inactive chapter directories")
for (i in seq_along(map_urls)) {
  mangled <- map_urls[[i]]$urlname
  orig <- map_urls[[i]]$orig_urlname
  old_dir <- here::here(archive_dir, "inactive_chapters", mangled)
  new_dir <- here::here(archive_dir, "inactive_chapters", orig)

  if (dir.exists(old_dir) && !dir.exists(new_dir)) {
    ok <- file.rename(old_dir, new_dir)
    if (ok) {
      cli::cli_alert_info(
        "Renamed {.file {basename(old_dir)}} -> {.file {basename(new_dir)}}"
      )
    } else {
      cli::cli_alert_danger("Failed to rename {.file {basename(old_dir)}}")
    }
  } else if (dir.exists(old_dir) && dir.exists(new_dir)) {
    # move specific files if missing in new dir
    for (f in c("events.json", "metadata.json")) {
      oldf <- file.path(old_dir, f)
      newf <- file.path(new_dir, f)
      if (file.exists(oldf) && !file.exists(newf)) {
        file.rename(oldf, newf)
        cli::cli_alert_info(
          "Moved {.file {f}} from {.file {basename(old_dir)}} to {.file {basename(new_dir)}}"
        )
      }
    }
    # remove old dir if now empty
    if (length(list.files(old_dir, all.files = TRUE, no.. = TRUE)) == 0) {
      unlink(old_dir, recursive = TRUE)
      cli::cli_alert_info(
        "Removed empty mangled dir {.file {basename(old_dir)}}"
      )
    }
  }
}
cli_alert_success(
  "Archive process completed at {format(Sys.time(), '%Y-%m-%d %H:%M:%S')}"
)
