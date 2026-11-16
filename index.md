# dazcache

dazcache is a persistent disk cache that every R process on one machine
can share: values outlive the session, expire, carry tags and stay under
a size limit.

- Sessions, scheduled jobs and parallel workers use one cache at once,
  over a local filesystem. Reads never wait, and each write is atomic,
  alone or in a transaction. It is built on
  [libmdbx](https://libmdbx.dqdkfa.ru/), through the
  [mdbx](https://github.com/pedrobtz/mdbx) package.
- A key can be a string, a date, a named list or a mix of these, written
  in a fixed text encoding, so the same values find the same entry in
  every session.
- Values of 32 KiB or more (by default) become read-only RDS files named
  by their content, stored once however many keys hold them, and
  readable in place by other tools.

## Installation

``` r

install.packages("dazcache")
```

The development version is on GitHub:

``` r

# install.packages("pak")
pak::pak("pedrobtz/dazcache")
```

## Usage

A cache is a directory. Open one, store a value for an hour (3600
seconds), and read it back:

``` r

library(dazcache)

s <- cache(file.path(tempdir(), "prices"))
cache_set(s, "XSWX/2026-08-29", c(101.2, 101.9), expire = 3600)
cache_get(s, "XSWX/2026-08-29")
#> [1] 101.2 101.9
```

A key with no entry is an error, unless you say what to return instead:

``` r

cache_get(s, "XNYS/2026-08-29", default = NULL)
#> NULL
```

dazcache also memoises functions, drops entries by tag and checks itself
for damage; [Get
started](https://pedrobtz.github.io/dazcache/articles/dazcache.html)
shows how.

## Learn more

- [Get
  started](https://pedrobtz.github.io/dazcache/articles/dazcache.html):
  keys, expiry, tags, memoising and large values, through one example.
- [Cache slow
  work](https://pedrobtz.github.io/dazcache/articles/caching-slow-work.html):
  memoise a slow function, keep the files it downloads, and use the
  cache from memoise and Shiny.
- [Operating a shared
  cache](https://pedrobtz.github.io/dazcache/articles/shared-cache.html):
  many processes, transactions, durability, size limits and repair.
- [How a cache stores keys and
  values](https://pedrobtz.github.io/dazcache/articles/storage.html):
  the directory, the files and the key encoding.
- [Reference](https://pedrobtz.github.io/dazcache/reference/): every
  function.

dazcache follows the design of Python’s
[diskcache](https://github.com/grantjenks/python-diskcache); for a cache
that lives only in one session’s memory, `cache_mem()` from
[cachem](https://cachem.r-lib.org/) is lighter.
