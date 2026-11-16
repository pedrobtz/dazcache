# The test suite's own oracles, shown to fire: a check that cannot report
# anything would let every "stays sound" assertion pass (#174).

test_that("store_violations() reports each kind of damage (#174)", {
  damage <- list(
    "no value row for" = function(s, e, txn) {
      engine_del(txn, engine_db(e, "values"), "inl")
    },
    "value size differs for" = function(s, e, txn) {
      engine_put(txn, engine_db(e, "values"), "inl", as.raw(1))
    },
    "dangling record" = function(s, e, txn) {
      p <- cache_path(s, "file")
      Sys.chmod(p, "0644")
      unlink(p)
    },
    "wrong file size for" = function(s, e, txn) {
      p <- cache_path(s, "file")
      Sys.chmod(p, "0644")
      writeBin(as.raw(1), p)
    },
    "refcount of" = function(s, e, txn) {
      db <- engine_db(e, "blobs")
      name <- basename(cache_path(s, "file"))
      row <- record_decode(engine_get(txn, db, name))
      row$refs <- row$refs + 1
      engine_put(txn, db, name, record_encode(row))
    },
    "no blobs row for" = function(s, e, txn) {
      engine_del(txn, engine_db(e, "blobs"), basename(cache_path(s, "file")))
    },
    "bytes_inline drifted" = function(s, e, txn) {
      store_counters_add(txn, list(bytes_inline = 1))
    },
    "bytes_blob drifted" = function(s, e, txn) {
      store_counters_add(txn, list(bytes_blob = 1))
    },
    "has rows no record implies" = function(s, e, txn) {
      engine_put(txn, engine_db(e, "tags"), tag_key("t", "ghost"), raw())
    },
    "is missing rows its records imply" = function(s, e, txn) {
      engine_del(txn, engine_db(e, "tags"), tag_key("t", "inl"))
    },
    "value row without an inline record" = function(s, e, txn) {
      engine_put(txn, engine_db(e, "values"), "orphan", as.raw(1:3))
    }
  )
  for (want in names(damage)) {
    s <- local_cache(inline_max = 100)
    cache_set(s, "inl", 1, tags = "t")
    cache_set(s, "file", runif(100))
    expect_identical(store_violations(s), character(), label = want)
    e <- s$engine
    engine_write(e, function(txn) damage[[want]](s, e, txn))
    found <- store_violations(s)
    expect_true(any(grepl(want, found, fixed = TRUE)), label = want)
  }
})
