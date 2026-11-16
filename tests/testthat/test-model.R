# The model-based test of the whole store; model_run() is in helper-model.R (#74).

test_that("the store reads as a model of it after every operation", {
  skip_on_cran()
  for (seed in c(74, 741, 7411)) model_run(seed, 250)
})
