describe("archive_window_start()", {
  it("returns UTC midnight the given number of days back", {
    now <- as.POSIXct("2026-09-29 15:30:00", tz = "UTC")
    expect_equal(
      archive_window_start(now, days = 90),
      as.POSIXct("2026-07-01 00:00:00", tz = "UTC")
    )
  })

  it("crosses into the previous year early in the year", {
    now <- as.POSIXct("2026-01-15 08:00:00", tz = "UTC")
    expect_equal(format(archive_window_start(now, days = 90), "%Y"), "2025")
  })
})

describe("event_datetime()", {
  it("parses both offset and Z timestamps as instants", {
    parsed <- event_datetime(list(
      fake_event("1", "2026-10-31T17:00:00-06:00"),
      fake_event("2", "2026-10-31T23:00:00Z")
    ))
    expect_equal(parsed[1], parsed[2])
  })
})

describe("merge_events()", {
  window_start <- as.POSIXct("2026-07-01", tz = "UTC")

  it("keeps archived events from before the window untouched", {
    archived <- list(fake_event("old", "2026-03-01T18:00:00+01:00"))
    fetched <- list(fake_event("new", "2026-08-01T18:00:00Z"))
    merged <- merge_events(archived, fetched, window_start)
    expect_identical(merged[[2]], archived[[1]])
  })

  it("refuses to merge an empty fetch", {
    archived <- list(fake_event("recent", "2026-08-01T18:00:00Z"))
    expect_error(
      merge_events(archived, list(), window_start),
      "no events since 2026-07-01"
    )
  })

  it("replaces archived events inside the window with fetched ones", {
    archived <- list(fake_event("a", "2026-08-01T18:00:00Z", "ACTIVE"))
    fetched <- list(fake_event("a", "2026-08-01T18:00:00Z", "PAST"))
    merged <- merge_events(archived, fetched, window_start)
    expect_length(merged, 1)
    expect_equal(merged[[1]]$status, "PAST")
  })

  it("drops archived events inside the window that Meetup no longer returns", {
    archived <- list(fake_event("deleted", "2026-08-01T18:00:00Z"))
    fetched <- list(fake_event("kept", "2026-08-02T18:00:00Z"))
    merged <- merge_events(archived, fetched, window_start)
    expect_equal(vapply(merged, `[[`, character(1), "id"), "kept")
  })

  it("does not duplicate an event returned from just before the window", {
    archived <- list(fake_event("edge", "2026-06-30T22:00:00-01:00"))
    fetched <- list(fake_event("edge", "2026-06-30T22:00:00-01:00"))
    expect_length(merge_events(archived, fetched, window_start), 1)
  })

  it("keeps archived events whose dateTime cannot be parsed", {
    archived <- list(fake_event("odd", "not a date"))
    fetched <- list(fake_event("new", "2026-08-01T18:00:00Z"))
    expect_length(merge_events(archived, fetched, window_start), 2)
  })

  it("puts fetched events ahead of older archived ones, newest first", {
    archived <- list(fake_event("old", "2026-03-01T18:00:00Z"))
    fetched <- list(
      fake_event("upcoming", "2026-11-01T18:00:00Z", "ACTIVE"),
      fake_event("recent", "2026-08-01T18:00:00Z")
    )
    merged <- merge_events(archived, fetched, window_start)
    expect_equal(
      vapply(merged, `[[`, character(1), "id"),
      c("upcoming", "recent", "old")
    )
  })

  it("counts each event once when rebuilding the full set", {
    archived <- list(
      fake_event("old", "2025-11-01T18:00:00Z"),
      fake_event("recent", "2026-08-01T18:00:00Z")
    )
    fetched <- list(
      fake_event("recent", "2026-08-01T18:00:00Z"),
      fake_event("upcoming", "2026-11-01T18:00:00Z", "ACTIVE")
    )
    merged <- merge_events(archived, fetched, window_start)
    ids <- vapply(merged, `[[`, character(1), "id")
    expect_setequal(ids, c("old", "recent", "upcoming"))
    expect_false(anyDuplicated(ids) > 0)
  })
})

describe("split_events_by_year()", {
  it("groups events by the year of their local dateTime", {
    events <- list(
      fake_event("a", "2025-12-31T23:30:00-05:00"),
      fake_event("b", "2026-01-02T10:00:00Z")
    )
    by_year <- split_events_by_year(events)
    expect_named(by_year, c("2025", "2026"))
    expect_equal(by_year[["2025"]][[1]]$id, "a")
  })
})
