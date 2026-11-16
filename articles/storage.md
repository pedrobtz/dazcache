# How a cache stores keys and values

``` r

library(dazcache)
```

This article is for when you want to know what a cache’s directory
holds: to back it up, to read its files with other tools, or to be sure
two calls find the same entry. It assumes you have read Get started.

## The directory

A cache is one directory. The database holds every record and index;
values too large to keep in it are files under `blobs/`; `tmp/` is where
files are written before they are published.

``` text
prices/
├── cache.mdbx        every record and index
├── cache.mdbx-lck    the lock that coordinates processes
├── blobs/b7/b795…3745.rds
└── tmp/              files being written, before they are published
```

![A small value lives inside its record in cache.mdbx; a large one
becomes a file in blobs/ that the record points at.](storage.svg)

A small value lives inside its record in `cache.mdbx`; a large one
becomes a file in `blobs/` that the record points at.

## Small values and large ones

A value whose encoding is smaller than `inline_max` (32 KiB unless you
choose otherwise when the cache is created) is kept inside the database,
next to its record. Anything larger becomes a file.
[`cache_entries()`](https://pedrobtz.github.io/dazcache/reference/cache_entries.md)
shows which is which:

``` r

s <- cache(file.path(tempdir(), "storage"))
cache_set(s, "small", 1:10)
cache_set(s, "large", runif(1e5))
cache_entries(s)[, c("key", "bytes", "inline", "codec")]
#>     key  bytes inline codec
#> 1 large 800031  FALSE   rds
#> 2 small    133   TRUE   rds
```

The file’s name is the SHA-256 hash of its bytes, so identical values
are one file, however many keys hold them. A file is read-only and is
never changed in place; it is removed once no key refers to it.

``` r

cache_set(s, "large-copy", cache_get(s, "large"))
identical(cache_path(s, "large"), cache_path(s, "large-copy"))
#> [1] TRUE
```

## How a value is encoded

A **codec** turns a value into bytes and back. By default, a raw vector
or a single string is stored as its bytes
([`codec_raw()`](https://pedrobtz.github.io/dazcache/reference/codec.md)),
and anything else as RDS
([`codec_rds()`](https://pedrobtz.github.io/dazcache/reference/codec.md)),
so a file under `blobs/` with the `.rds` extension is what
[`readRDS()`](https://rdrr.io/r/base/readRDS.html) reads.
[`codec_file()`](https://pedrobtz.github.io/dazcache/reference/codec.md)
stores a file you already have, keeping its extension.

The codec is recorded with each entry, and a read always decodes with
the codec that wrote it, whatever the cache’s default is now.

## How a key is written

Every key becomes a text, and that text is the key in the database. A
string is its own text. Anything else is written in a fixed encoding,
the same in every session, R version and locale.
[`cache_key_chr()`](https://pedrobtz.github.io/dazcache/reference/cache_key.md)
shows it:

``` r

cache_key_chr(list(exchange = "XSWX", date = as.Date("2026-08-29")))
#> [1] "{date=d:2026-08-29,exchange=s:XSWX}"
```

The encoding is what makes equal values find the same entry:

- names in a list are sorted, so field order does not matter;
- a whole number is written the same as an integer or a double, so `1L`
  and `1` agree;
- a time is its instant, so the same moment in two time zones is one
  key.

``` r

cache_key_chr(list(b = 1L, a = 1)) == cache_key_chr(list(a = 1, b = 1L))
#> [1] TRUE
cache_key_chr(as.POSIXct("2026-08-29 12:00", tz = "UTC")) ==
  cache_key_chr(as.POSIXct("2026-08-29 14:00", tz = "Europe/Zurich"))
#> [1] TRUE
```

A key whose text is over 512 bytes is stored under the hash of its text
instead; you read it by the same value as any other key. An object the
encoding does not cover, such as an environment or a function, is
refused with a `dazcache_key_invalid` error rather than being keyed on
something that may change.

``` r

cache_close(s)
```

Next: [Operating a shared
cache](https://pedrobtz.github.io/dazcache/articles/shared-cache.md),
for what a cache guarantees when many processes use this directory at
once.
