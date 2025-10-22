#!/usr/bin/env Rscript

# Archive R-Ladies Meetup Data (Raw JSON - GDPR Compliant)
# Creates timestamped archives using raw GraphQL responses
# Excludes personally identifiable information (member names, etc.)

library(meetupr)
library(dplyr)
library(jsonlite)
library(lubridate)
library(here)
library(purrr)
library(cli)

# Setup -------------------------------------------------------------------

# Create archive directory structure
archive_dir <- here("archive")
dir.create(archive_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(
  here(archive_dir, "raw_data"),
  showWarnings = FALSE,
  recursive = TRUE
)
dir.create(
  here(archive_dir, "inactive_chapters"),
  showWarnings = FALSE,
  recursive = TRUE
)

# Timestamp for this archive run
timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
date_str <- format(Sys.Date(), "%Y-%m-%d")

cli_h1("R-Ladies Meetup Archive")
cli_alert_info("Starting archive process at {timestamp}")

# Fetch Raw Chapter Data --------------------------------------------------

cli_h2("Fetching chapter data from Meetup")

# GraphQL query for pro network members (chapters)
chapters_query <- '
  query ($urlname: String!) {
    proNetworkByUrlname(urlname: $urlname) {
      id
      name
      urlname
      membersCount
      groupsCount
      members {
        edges {
          node {
            id
          }
        }
      }
    }
  }
'

chapters_raw <- meetupr::meetup_query(
  query = chapters_query,
  variables = list(urlname = "rladies")
)

# Save raw chapters response
chapters_file <- here(
  archive_dir,
  "raw_data",
  paste0(timestamp, "_chapters_raw.json")
)
write_json(chapters_raw, chapters_file, pretty = TRUE, auto_unbox = TRUE)
cli_alert_success("Saved raw chapters data: {.file {basename(chapters_file)}}")

# Extract chapter list for processing
chapters <- chapters_raw$data$proNetworkByUrlname$members$edges %>%
  map_df(~ .x$node)

cli_alert_info("Found {.strong {nrow(chapters)}} chapters in R-Ladies network")

# Fetch All Events via Pro Network ----------------------------------------

cli_h2("Fetching all events via pro network")

# GraphQL query for all pro network events
pro_events_query <- '
  query ($urlname: String!, $status: [EventStatus!]) {
    proNetworkByUrlname(urlname: $urlname) {
      id
      name
      urlname
      events(input: {status: $status, first: 10000}) {
        pageInfo {
          hasNextPage
          endCursor
        }
        count
        edges {
          node {
            id
            title
            description
            dateTime
            endTime
            duration
            eventUrl
            going
            status
            timezone
            group {
              id
              name
              urlname
            }
            venue {
              id
              name
              address
              city
              state
              country
              lat
              lon
              postalCode
            }
            featuredEventPhoto {
              id
              baseUrl
              highResUrl
            }
          }
        }
      }
    }
  }
'

cli_progress_step("Fetching PAST events")
past_events_raw <- meetupr::meetup_query(
  query = pro_events_query,
  variables = list(
    urlname = "rladies",
    status = list("PAST")
  )
)

cli_progress_step("Fetching UPCOMING events")
upcoming_events_raw <- meetupr::meetup_query(
  query = pro_events_query,
  variables = list(
    urlname = "rladies",
    status = list("UPCOMING")
  )
)

# Combine all events
all_events_raw <- list(
  past_events = past_events_raw,
  upcoming_events = upcoming_events_raw
)

# Save complete raw events data
events_file <- here(
  archive_dir,
  "raw_data",
  paste0(timestamp, "_events_raw.json")
)
write_json(all_events_raw, events_file, pretty = TRUE, auto_unbox = TRUE)

# Count events
past_count <- past_events_raw$data$proNetworkByUrlname$events$count %||%
  length(past_events_raw$data$proNetworkByUrlname$events$edges)
upcoming_count <- upcoming_events_raw$data$proNetworkByUrlname$events$count %||%
  length(upcoming_events_raw$data$proNetworkByUrlname$events$edges)
total_events <- past_count + upcoming_count

cli_alert_success("Saved raw events data: {.file {basename(events_file)}}")
cli_alert_info(
  "Total events: {.strong {total_events}} ({past_count} past, {upcoming_count} upcoming)"
)

# Identify Inactive Chapters ----------------------------------------------

cli_h2("Identifying inactive chapters")

# Extract all past events with their group info
past_events_list <- past_events_raw$data$proNetworkByUrlname$events$edges

if (length(past_events_list) > 0) {
  # Parse events to find last activity per chapter
  chapter_activity <- map_df(past_events_list, function(event) {
    tibble(
      urlname = event$node$group$urlname,
      event_date = as.Date(event$node$dateTime)
    )
  }) %>%
    group_by(urlname) %>%
    summarise(
      last_event_date = max(event_date, na.rm = TRUE),
      total_past_events = n(),
      first_event_date = min(event_date, na.rm = TRUE),
      .groups = "drop"
    )

  # Add chapters with no events
  chapters_no_events <- chapters %>%
    filter(!urlname %in% chapter_activity$urlname) %>%
    mutate(
      last_event_date = as.Date(NA),
      total_past_events = 0L,
      first_event_date = as.Date(NA)
    ) %>%
    select(urlname, last_event_date, total_past_events, first_event_date)

  chapter_activity <- bind_rows(chapter_activity, chapters_no_events)
} else {
  # No events found
  chapter_activity <- chapters %>%
    mutate(
      last_event_date = as.Date(NA),
      total_past_events = 0L,
      first_event_date = as.Date(NA)
    ) %>%
    select(urlname, last_event_date, total_past_events, first_event_date)
}

# Define inactive as no events in last 12 months
inactive_cutoff <- Sys.Date() - months(12)

inactive_chapters <- chapter_activity %>%
  filter(is.na(last_event_date) | last_event_date < inactive_cutoff) %>%
  arrange(last_event_date)

cli_alert_warning(
  "Found {.strong {nrow(inactive_chapters)}} inactive chapters (no events in 12+ months)"
)

# Archive Inactive Chapter Data -------------------------------------------

if (nrow(inactive_chapters) > 0) {
  cli_h2("Archiving inactive chapter data")

  cli_progress_bar("Archiving chapters", total = nrow(inactive_chapters))

  for (i in seq_len(nrow(inactive_chapters))) {
    chapter_urlname <- inactive_chapters$urlname[i]

    # Create chapter-specific directory
    chapter_dir <- here(archive_dir, "inactive_chapters", chapter_urlname)
    dir.create(chapter_dir, showWarnings = FALSE, recursive = TRUE)

    # Extract events for this chapter from the full events list
    chapter_past_events <- past_events_list[
      map_lgl(past_events_list, ~ .x$node$group$urlname == chapter_urlname)
    ]

    chapter_upcoming_events <- upcoming_events_raw$data$proNetworkByUrlname$events$edges[
      map_lgl(
        upcoming_events_raw$data$proNetworkByUrlname$events$edges,
        ~ .x$node$group$urlname == chapter_urlname
      )
    ]

    chapter_events <- list(
      past_events = chapter_past_events,
      upcoming_events = chapter_upcoming_events
    )

    # Save chapter-specific event data
    chapter_events_file <- here(chapter_dir, paste0(timestamp, "_events.json"))
    write_json(
      chapter_events,
      chapter_events_file,
      pretty = TRUE,
      auto_unbox = TRUE
    )

    # Get chapter metadata
    chapter_info <- chapters %>%
      filter(urlname == chapter_urlname)

    chapter_metadata_file <- here(
      chapter_dir,
      paste0(timestamp, "_metadata.json")
    )
    write_json(
      chapter_info,
      chapter_metadata_file,
      pretty = TRUE,
      auto_unbox = TRUE
    )

    # Create human-readable summary
    activity <- inactive_chapters %>% filter(urlname == chapter_urlname)

    summary <- list(
      chapter_name = chapter_info$name,
      urlname = chapter_urlname,
      archived_date = date_str,
      archived_timestamp = timestamp,
      last_event = as.character(activity$last_event_date),
      total_events = activity$total_past_events,
      first_event = as.character(activity$first_event_date),
      days_inactive = if (!is.na(activity$last_event_date)) {
        as.numeric(Sys.Date() - activity$last_event_date)
      } else {
        NA
      },
      members_count = chapter_info$membersCount %||% NA,
      city = chapter_info$city %||% NA,
      country = chapter_info$country %||% NA,
      created = chapter_info$created %||% NA,
      status = chapter_info$status %||% NA,
      restoration_notes = "Use events.json to restore complete chapter event history",
      privacy_note = "Archive contains only aggregate data, no personal information"
    )

    summary_file <- here(chapter_dir, paste0(timestamp, "_summary.json"))
    write_json(summary, summary_file, pretty = TRUE, auto_unbox = TRUE)

    cli_progress_update()
  }

  cli_progress_done()

  # Create master index of inactive chapters
  inactive_index <- inactive_chapters %>%
    left_join(chapters, by = "urlname") %>%
    select(
      urlname,
      name,
      city,
      country,
      last_event_date,
      total_past_events,
      first_event_date,
      membersCount,
      created,
      status
    ) %>%
    mutate(
      archived_date = date_str,
      days_inactive = if_else(
        !is.na(last_event_date),
        as.numeric(Sys.Date() - last_event_date),
        NA_real_
      )
    )

  index_file <- here(
    archive_dir,
    "inactive_chapters",
    paste0(timestamp, "_inactive_chapters_index.json")
  )
  write_json(inactive_index, index_file, pretty = TRUE)

  # Also save as CSV for easy viewing
  csv_file <- here(
    archive_dir,
    "inactive_chapters",
    paste0(timestamp, "_inactive_chapters_index.csv")
  )
  write.csv(inactive_index, csv_file, row.names = FALSE)

  cli_alert_success("Created inactive chapters index")
}

# Create Archive Manifest -------------------------------------------------

cli_h2("Creating archive manifest")

manifest <- list(
  archive_timestamp = timestamp,
  archive_date = date_str,
  total_chapters = nrow(chapters),
  active_chapters = nrow(chapters) - nrow(inactive_chapters),
  inactive_chapters = nrow(inactive_chapters),
  total_events = total_events,
  past_events = past_count,
  upcoming_events = upcoming_count,
  date_range = list(
    earliest_event = as.character(min(
      chapter_activity$first_event_date,
      na.rm = TRUE
    )),
    latest_event = as.character(max(
      chapter_activity$last_event_date,
      na.rm = TRUE
    ))
  ),
  inactive_cutoff_date = as.character(inactive_cutoff),
  data_source = "Meetup GraphQL API (pro network query)",
  query_method = "Single pro network events query (no per-chapter loops)",
  privacy_compliance = "GDPR compliant - no personal member data stored",
  data_collected = list(
    chapter_info = "name, location, member counts (aggregate only)",
    event_info = "title, description, date, venue, attendance counts (aggregate only)",
    excluded = "member names, attendee lists, individual RSVP data"
  ),
  r_version = paste(R.version$major, R.version$minor, sep = "."),
  meetupr_version = as.character(packageVersion("meetupr"))
)

manifest_file <- here(archive_dir, paste0(timestamp, "_manifest.json"))
write_json(manifest, manifest_file, pretty = TRUE, auto_unbox = TRUE)

cli_alert_success("Archive manifest saved")

# Archive Statistics ------------------------------------------------------

cli_h2("Archive Statistics")

cli_div(theme = list(ul = list("margin-left" = 2)))
cli_ul()
cli_li("Total chapters: {.strong {manifest$total_chapters}}")
cli_li("Active chapters: {.strong {manifest$active_chapters}}")
cli_li("Inactive chapters: {.strong {manifest$inactive_chapters}}")
cli_li("Total events: {.strong {manifest$total_events}}")
cli_ul()
cli_li("Past: {manifest$past_events}")
cli_li("Upcoming: {manifest$upcoming_events}")
cli_end()
cli_li(
  "Date range: {.val {manifest$date_range$earliest_event}} to {.val {manifest$date_range$latest_event}}"
)
cli_end()
cli_end()

cli_alert_info("Privacy: Only aggregate data stored, no personal information")

# Create README -----------------------------------------------------------

readme_content <- paste0(
  "# R-Ladies Meetup Data Archive (Raw GraphQL Responses)\n\n",
  "Archive created: ",
  date_str,
  " (",
  timestamp,
  ")\n\n",
  "## Summary\n\n",
  "- Total chapters: ",
  manifest$total_chapters,
  "\n",
  "- Active chapters: ",
  manifest$active_chapters,
  "\n",
  "- Inactive chapters: ",
  manifest$inactive_chapters,
  "\n",
  "- Total events archived: ",
  manifest$total_events,
  "\n",
  "  - Past: ",
  manifest$past_events,
  "\n",
  "  - Upcoming: ",
  manifest$upcoming_events,
  "\n",
  "- Event date range: ",
  manifest$date_range$earliest_event,
  " to ",
  manifest$date_range$latest_event,
  "\n\n",
  "## Privacy & GDPR Compliance\n\n",
  "This archive is GDPR compliant and contains NO personal information:\n\n",
  "- ✅ Stored: Chapter names, locations, aggregate member counts\n",
  "- ✅ Stored: Event titles, descriptions, dates, venues, aggregate attendance\n",
  "- ❌ NOT stored: Individual member names, email addresses, or profile data\n",
  "- ❌ NOT stored: Attendee lists or individual RSVP information\n\n",
  "Only aggregate, non-identifiable data is preserved.\n\n",
  "## Data Format\n\n",
  "All data is stored as raw JSON responses from the Meetup GraphQL API.\n",
  "Events are fetched using the pro network events query (single query for all chapters).\n\n",
  "## Directory Structure\n\n",
  "- `archive/raw_data/`: Complete timestamped snapshots\n",
  "  - `*_chapters_raw.json`: All chapter metadata from pro network\n",
  "  - `*_events_raw.json`: All events (past and upcoming) for entire network\n",
  "- `archive/inactive_chapters/[urlname]/`: Per-chapter archives\n",
  "  - `*_events.json`: All events for this specific chapter\n",
  "  - `*_metadata.json`: Chapter information from pro network\n",
  "  - `*_summary.json`: Human-readable summary\n",
  "- `archive/inactive_chapters/*_inactive_chapters_index.csv`: Master list\n\n",
  "## Inactive Chapter Criteria\n\n",
  "Chapters are considered inactive if they have not hosted an event in 12+ months.\n",
  "Cutoff date for this archive: ",
  as.character(inactive_cutoff),
  "\n\n",
  "## Restoration\n\n",
  "To restore an inactive chapter:\n",
  "1. Locate the chapter directory in `archive/inactive_chapters/[urlname]/`\n",
  "2. Use `*_events.json` - contains all past and upcoming events\n",
  "3. Use `*_metadata.json` - contains chapter settings and information\n",
  "4. The raw JSON can be used to reconstruct the chapter's Meetup page\n\n",
  "## Working with Raw Data\n\n",
  "```r\n",
  "# Load raw data\n",
  "library(jsonlite)\n",
  "events <- fromJSON('archive/inactive_chapters/chapter-name/*_events.json')\n\n",
  "# Access past events\n",
  "past <- events$past_events\n\n",
  "# Access upcoming events\n",
  "upcoming <- events$upcoming_events\n",
  "```\n\n",
  "## Archive Retention\n\n",
  "Archives are timestamped and retained indefinitely for historical preservation.\n"
)

readme_file <- here(archive_dir, "README.md")
writeLines(readme_content, readme_file)

# Final Summary -----------------------------------------------------------

cli_h1("Archive Complete")

cli_alert_success("Archive directory: {.path {archive_dir}}")
cli_alert_success("README created: {.file README.md}")
cli_text("")
cli_alert_info(
  "Raw data preserved in: {.path {file.path('archive', 'raw_data')}}"
)
cli_alert_info(
  "Inactive chapters archived in: {.path {file.path('archive', 'inactive_chapters')}}"
)
