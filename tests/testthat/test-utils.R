context("Checking utilities")

test_that(
  "setting seed works", {

    rm(".Random.seed", pos = 1L)

    sample_with_seed(10, 10, 123)

    expect_false(exists(".Random.seed", 1L))

  }
)

test_that(
  "getting locale works", {

    Sys.setenv(LANGUAGE = "Finnish-Finland")

    expect_match(get_locale(), "fi")

  }
)
