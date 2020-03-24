#' Convert to knitr_kable + kableExtra object
#'
#' @description Function converts a gtsummary object to a knitr_kable + kableExtra object.
#' A user can use this function if they wish to add customized formatting
#' available via [knitr::kable] and {kableExtra}. Note that {gtsummary}
#' uses the standard markdown `**` to bold headers, and they may need to be
#' changed manually with kableExtra output.
#'
#' @inheritParams as_kable
#' @export
#' @return A {kableExtra} object
#' @seealso [as_gt] [as_kable] [as_tibble]
#' @author Daniel D. Sjoberg
#' @examples
#' trial %>%
#'   tbl_summary(by = trt) %>%
#'   as_kable_extra()

as_kable_extra <- function(x, include = everything(), return_calls = FALSE, ...) {
  # creating list of kableExtra calls --------------------------------------------------
  kable_extra_calls <- table_header_to_kable_extra_calls(x = x, ...)
  if (return_calls == TRUE) return(kable_extra_calls)

  # converting to charcter vector ----------------------------------------------
  include <- var_input_to_string(data = vctr_2_tibble(names(kable_extra_calls)),
                                 select_input = !!rlang::enquo(include))

  # making list of commands to include -----------------------------------------
  # this ensures list is in the same order as names(x$kable_calls)
  include <- names(kable_extra_calls) %>% intersect(include)
  # user cannot exclude the first 'kable' command
  include <- "tibble" %>% union(include)

  # taking each kable function call, concatenating them with %>% separating them
  kable_extra_calls[include] %>%
    # removing NULL elements
    unlist() %>%
    compact() %>%
    # concatenating expressions with %>% between each of them
    reduce(function(x, y) expr(!!x %>% !!y)) %>%
    # evaluating expressions
    eval()
}

table_header_to_kable_extra_calls <- function(x, ...) {
  table_header <- x$table_header

  # getting kable calls
  kable_extra_calls <-
    table_header_to_kable_calls(x = x, ...)

  # add_indent -----------------------------------------------------------------
  tab_style_indent <-
    table_header %>%
    filter(!is.na(.data$indent), .data$column == "label") %>%
    pull(.data$indent)

  if (length(tab_style_indent) > 0) {
    indent_index <-
      expr(with(x$table_body, !!parse_expr(tab_style_indent))) %>%
      eval() %>%
      which()

    kable_extra_calls[["add_indent"]] <- expr(kableExtra::add_indent(!!indent_index))
  }

  # add_header_above -----------------------------------------------------------
  if (sum(!is.na(table_header$spanning_header)) > 0) {
    header0 <- table_header %>%
      filter(.data$hide == FALSE) %>%
      select(.data$spanning_header) %>%
      mutate(spanning_header = ifelse(is.na(.data$spanning_header),
                                      " ",
                                      .data$spanning_header)) %>%
      group_by(.data$spanning_header) %>%
      dplyr::summarise(n = n()) %>%
      ungroup()
    header <- header0$n %>% set_names(header0$spanning_header)

    kable_extra_calls[["add_header_above"]] <-
      expr(kableExtra::add_header_above(!!header))
  }

  # footnote -------------------------------------------------------------------
  vct_footnote_abbrev <- table_header %>%
    filter(!is.na(.data$footnote_abbrev)) %>%
    pull(.data$footnote_abbrev)
  if (length(vct_footnote_abbrev) > 0)
    vct_footnote_abbrev <- paste(vct_footnote_abbrev, collapse = ", ")
  vct_footnote <- table_header %>%
    filter(!is.na(.data$footnote)) %>%
    pull(.data$footnote) %>%
    unique() %>%
    c(vct_footnote_abbrev)

  if( length(vct_footnote > 0))
    kable_extra_calls[["footnote"]] <-
    expr(kableExtra::footnote(number = !!vct_footnote))

  kable_extra_calls
}
