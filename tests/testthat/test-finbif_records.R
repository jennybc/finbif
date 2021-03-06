context("Downloading FinBIF records")

vcr::use_cassette(
  "finbif_records", {

    test_that(
      "returns valid data", {

        skip_on_cran()

        records <-
          finbif_records(filter = list(primary_habitat = list(M = c("V", "H"))))

        expect_output(print(records), "FinBIF")

        expect_output(print(records[[1]]), "FinBIF")

        expect_s3_class(
          finbif_records(c(collection = "HR.42"), order_by = "-date_start"),
          "finbif_records_list"
        )

        expect_s3_class(
          finbif_records(
            list(
              collection =
                finbif_collections(taxonomic_coverage == "Coleoptera")
            )
          ),
          "finbif_records_list"
        )

      }
    )

    test_that(
      "with count only returns valid data", {

        skip_on_cran()

        expect_s3_class(
          finbif_records(
            filter = list(
              primary_habitat = "M",
              coordinates_cell_100k = c(67, 32)
            ),
            count_only = TRUE
          ),
          "finbif_api"
        )

      }
    )

  },
  preserve_exact_body_bytes = TRUE
)

test_that(
  "returns errors appropriately", {

    expect_condition(finbif_records(n = 1e99))

    expect_condition(finbif_records(filter = c(not_a_filter = TRUE)))

    expect_condition(
      finbif_records(
        filter = list(coordinates = list(lat = c(60, 68), lon = c(20, 30)))
      )
    )

  }
)
