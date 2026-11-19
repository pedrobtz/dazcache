# Get started with dazcache

``` r

library(dazcache)
```

We will build a small cache of market prices: store quotes under keys,
find them again, let them expire, drop a group of them at once, and
memoise the slow function that fetches them. By the end you will know
the handful of functions most code needs. Running a cache across many
processes, and how it is stored, are left to the articles listed at the
end.

## Open a cache

A **cache** is a directory.
[`cache()`](https://pedrobtz.github.io/dazcache/reference/cache.md)
opens it, creating it if needed, and every R process on the machine that
opens the same directory sees the same entries. Its handle, `s` here, is
what every other function takes first.

``` r

dir <- file.path(tempdir(), "prices")
s <- cache(dir)
```

## Store and read values

[`cache_set()`](https://pedrobtz.github.io/dazcache/reference/cache_set.md)
stores a value under a **key** and returns the cache, so writes chain.
[`cache_get()`](https://pedrobtz.github.io/dazcache/reference/cache_get.md)
reads a value back.

``` r

s |>
  cache_set("XSWX/2026-08-28", c(100.8, 101.4)) |>
  cache_set("XSWX/2026-08-29", c(101.2, 101.9))

cache_get(s, "XSWX/2026-08-29")
#> [1] 101.2 101.9
```

Asking for a key that has no entry is the mistake you will make first.
It is an error, so a missing value never passes for a real one:

``` r

cache_get(s, "XNYS/2026-08-29")
#> Error in `cache_get()`:
#> ! No entry for key "XNYS/2026-08-29".
#> ℹ Supply `default` to return a value instead of erroring.
```

Supply `default` when a miss is expected, or ask with
[`cache_has()`](https://pedrobtz.github.io/dazcache/reference/cache_get.md)
first. A stored `NULL` is a value like any other, so the two never get
confused.

``` r

cache_get(s, "XNYS/2026-08-29", default = NULL)
#> NULL
cache_has(s, c("XSWX/2026-08-29", "XNYS/2026-08-29"))
#> [1]  TRUE FALSE
```

## Choose keys

A string is its own key, and a `"group/item"` convention gives you
prefixes to list by:

``` r

cache_keys(s, prefix = "XSWX/")
#> [1] "XSWX/2026-08-28" "XSWX/2026-08-29"
```

A key can also be a number, a date or a named list. The same values
always find the same entry, whatever order the fields are written in:

``` r

cache_set(s, list(exchange = "XNYS", date = as.Date("2026-08-29")), c(57.8, 58.1))
cache_get(s, list(date = as.Date("2026-08-29"), exchange = "XNYS"))
#> [1] 57.8 58.1
```

## Expire and drop entries

An entry can **expire**: after a number of seconds, a `difftime`, or at
a `POSIXct` time. An expired entry is gone for every reader at once.
Here, an intraday quote is good for an hour, and one with `expire = 0`
is gone as soon as it is written:

``` r

cache_set(s, "XSWX/live", 101.6, expire = as.difftime(1, units = "hours"))
cache_set(s, "XSWX/stale", 101.5, expire = 0)
cache_has(s, c("XSWX/live", "XSWX/stale"))
#> [1]  TRUE FALSE
```

**Tags** group entries for invalidation. Tag the quotes that came from
one feed, and drop them all when that feed turns out to be wrong:

``` r

cache_set(s, "XLON/2026-08-28", 7.41, tags = "feed-b")
cache_set(s, "XLON/2026-08-29", 7.44, tags = "feed-b")
cache_evict(s, tag = "feed-b")
cache_keys(s, prefix = "XLON/")
#> character(0)
```

## Memoise a function

Most quotes come from somewhere slow.
[`cache_memoise()`](https://pedrobtz.github.io/dazcache/reference/cache_memoise.md)
wraps a function so that each call is looked up first and computed only
on a miss. The results outlive the session, and every process using the
cache shares them. The second call below reads the first call’s result:

``` r

fetch_quotes <- function(exchange, date) {
  Sys.sleep(0.5)
  set.seed(as.integer(date))
  round(runif(2, 50, 150), 1)
}
quotes <- cache_memoise(fetch_quotes, s)

system.time(quotes("XTKS", as.Date("2026-08-29")))
#>    user  system elapsed 
#>   0.002   0.000   0.503
system.time(quotes("XTKS", as.Date("2026-08-29")))
#>    user  system elapsed 
#>   0.001   0.000   0.001
```

A call is keyed on the function’s name, here `fetch_quotes`, the name it
was passed as, and on its arguments. The key does not depend on the
function’s code: when the function changes meaning, give it a new
`version`, and its calls get new keys.

``` r

cache_memoise_key(quotes, "XTKS", as.Date("2026-08-29"))
#> [1] "fetch_quotes/v1/{date=d:2026-08-29,exchange=s:XTKS}"
quotes <- cache_memoise(fetch_quotes, s, version = 2)
cache_memoise_key(quotes, "XTKS", as.Date("2026-08-29"))
#> [1] "fetch_quotes/v2/{date=d:2026-08-29,exchange=s:XTKS}"
```

## Large values and the catalogue

A year of ticks is too large to keep inside the database. A value of 32
KiB or more (`inline_max`) is stored as a read-only RDS file, and
[`cache_path()`](https://pedrobtz.github.io/dazcache/reference/cache_path.md)
gives that file to tools that read it in place:

``` r

ticks <- runif(1e5, 100, 102)
cache_set(s, "XSWX/2026/ticks", ticks)
path <- cache_path(s, "XSWX/2026/ticks")
identical(readRDS(path), ticks)
#> [1] TRUE
```

[`cache_entries()`](https://pedrobtz.github.io/dazcache/reference/cache_entries.md)
lists what the cache holds as a data frame: each key, its size in bytes
as stored, whether it lives inside the database, and when it expires. A
key that is not a string is listed by its text form, which [How a cache
stores keys and
values](https://pedrobtz.github.io/dazcache/articles/storage.html)
explains.

``` r

cache_entries(s)[, c("key", "bytes", "inline", "expires")]
#>                                                   key  bytes inline
#> 1                                     XSWX/2026-08-28     47   TRUE
#> 2                                     XSWX/2026-08-29     47   TRUE
#> 3                                     XSWX/2026/ticks 800031  FALSE
#> 4                                           XSWX/live     39   TRUE
#> 5 fetch_quotes/v1/{date=d:2026-08-29,exchange=s:XTKS}     47   TRUE
#> 6                 {date=d:2026-08-29,exchange=s:XNYS}     47   TRUE
#>               expires
#> 1                <NA>
#> 2                <NA>
#> 3                <NA>
#> 4 2026-11-19 15:54:17
#> 5                <NA>
#> 6                <NA>
```

When you are done, close the cache. Its entries stay on disk for the
next process.

``` r

cache_close(s)
```

## Where next

- [Cache slow
  work](https://pedrobtz.github.io/dazcache/articles/caching-slow-work.html):
  memoise a slow function across sessions, keep downloaded files, and
  use the cache from memoise and Shiny.
- [Operating a shared
  cache](https://pedrobtz.github.io/dazcache/articles/shared-cache.html):
  many processes, transactions, durability, size limits and repair.
- [How a cache stores keys and
  values](https://pedrobtz.github.io/dazcache/articles/storage.html):
  the directory, the files and the key encoding.
- [Reference](https://pedrobtz.github.io/dazcache/reference/): every
  function, with its arguments.
