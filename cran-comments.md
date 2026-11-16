## Submission

This is the first submission of dazcache.

## Test environments

* local: macOS (aarch64), R 4.6.1, `R CMD check --as-cran` on the source
  tarball
* GitHub Actions (pedrobtz/r-actions `r-cmd-check.yml`), all with `--as-cran`:
  * macOS, Windows and Ubuntu (latest): R release
  * Windows (latest): R-devel
  * Ubuntu (latest): R oldrel-1 (4.5), the declared minimum
  * R-hub containers `clang23`, `ubuntu-clang` and `ubuntu-gcc16`: R-devel
    with CRAN's compilers
  * R-hub `nosuggests` container: R-devel with only the hard dependencies
    installed (CRAN's noSuggests flavor)
  * R-hub `nold` container: R-devel without long doubles (CRAN's noLD flavor)
* GitHub Actions (pedrobtz/r-actions `cran-special.yml`): CRAN's `rlibro`
  and `vnu` checks

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new release.

## Notes for the reviewer

* `Depends: R (>= 4.5.0)`: the package hashes with `tools::sha256sum()`,
  which R 4.5.0 added.

* Examples, tests and vignettes write only under `tempdir()`, and remove
  what they create.

* Tests that start several R processes (with 'callr' or `fork()`) to check
  behaviour across processes are skipped on CRAN, to stay within its time and
  CPU limits, except one that starts a single child process. They all run in
  the package's continuous integration.

* There are no published references describing the methods in this package.
  It follows the design of the 'Python' library 'diskcache'
  (<https://github.com/grantjenks/python-diskcache>).
