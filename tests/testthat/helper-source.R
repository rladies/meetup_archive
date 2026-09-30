source(file.path("..", "..", "scripts", "archive_utils.R"))

fake_event <- function(id, date_time, status = "PAST") {
  list(id = id, dateTime = date_time, status = status)
}
