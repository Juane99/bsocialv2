#' Log Messages for bsocialv2 Operations
#'
#' Internal logging utility that outputs timestamped messages to the console.
#'
#' @param level Character. Log level (e.g., "INFO", "WARN", "ERROR").
#' @param ... Messages to concatenate and display.
#' @param .indent Integer. Number of spaces for indentation (default 0).
#'
#' @return NULL (invisibly). Called for its side effect of printing a message.
#' @keywords internal
bsocial_log <- function(level = "INFO", ..., .indent = 0) {
  ts <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  # Tolerante a llamadas antiguas sin "level"
  if (!is.character(level) || length(level) != 1 || nchar(level) > 8) {
    args <- c(level, list(...))
    level <- "INFO"
    msg_body <- paste(args, collapse = "")
  } else {
    msg_body <- paste(..., collapse = "")
  }
  msg <- paste0("[", ts, "][", level, "] ", paste0(rep(" ", .indent), collapse=""), msg_body)
  message(msg)
}
