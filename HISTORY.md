### 1.4.0

* Add #deindex_by_primary_key. (ntalbott)
* Add license. (ntalbott)

### 1.3.0

* Update redis-rb dependency to 3.0. (ntalbott)

### 1.2.1

* Handle out of memory errors better. (myronmarston)
* Property deindex immutable attributes. (myronmarston)
* Allow offsetting primary key lookup by a primary key. (ntalbott)

### 1.2.0

* Improved keyer inheritance, including better legacy
  support. (ntalbott)
* Improved memory efficiency by not storing unnecessary
  data. (myronmarston)
* Added Ordered Indexes for easy range queries. (myronmarston)

### 1.1.1

* Added keyers to the manifest file. (ntalbott)

### 1.1.0

* Fixed and tested concurrency support. (ntalbott)
* Added Relix::Error that all errors inherit from. (ntalbott)
* Added support for deindexing a model. (myronmarston)
* Bring sanity to key construction and make keyers pluggable. (ntalbott)

### 1.0.3

* Back the Rubygems dependency down some.

### 1.0.2

* Allow configuring the Redis host.

### 1.0.1

* Add all the new files in lib to gemspec.

### 1.0.0

* First official release.
