# Relix

A Redis-backed indexing layer that can be used with any (or no) backend data storage.


## Rationale

With the rise in popularity of non-relational databases, and the regular use of relational databases in non-relational ways, data indexing has become an aspect of data storage that you can't simply assume is handled for you. More and more applications are storing their data in databases that treat that stored data as opaque, and thus there's no query engine sitting on top of the data making sure that it can be quickly and flexibly looked up.

Relix is a layer that can be added on to any model to make all the normal types of querying you want to do: equality, less than/greater than, in set, range, limit, etc., quick and painless. Relix depends on Redis to be awesome at what it does - blazingly fast operations on basic data types - and layers on top of that pluggable indexing of your data for fast lookup.


## Philosophy

* Performance is paramount - be FAST.
* Leverage Redis and its strengths to the hilt. Never do in Relix what could be done in Redis.
* Be extremely tolerant to failure.
** Since we can't guarantee atomicity with the backing datastore, index early and clean up later.
** Make continuous index repair easy since the chaos monkey could attack at any time.
* Be pluggable; keep the core simple and allow easy extensibility


## Installation

If you're using bundler, add Relix to your Gemfile:

    gem 'relix'

Otherwise gem install:

    $ gem install relix

You can configure the Redis host, port and db like so:

    Relix.host = 'app-1'
    Relix.port = 10000
    Relix.db   = 5

Relix requires Redis 2.6 or later.


## Usage

To index something in a model, include the Relix module, declare the primary key (required), and declare any additional indexes you want:

    class Transaction
      include Relix

      attr_accessor :key, :account_key, :created_at

      relix do
        primary_key :key
        multi :account_key, order: :created_at
        unique :by_created_at, on: :key, order: :created_at
      end

      def initialize(key, account_key, created_at)
        @key = key
        @account_key = account_key
        @created_at = created_at

        # Trigger the actual indexing
        index!
      end
    end

    Transaction.new(1, 1, Time.parse('2011-09-30'))
    Transaction.new(2, 2, Time.parse('2011-09-29'))
    Transaction.new(3, 2, Time.parse('2011-10-01'))
    Transaction.new(4, 2, Time.parse('2011-08-30'))

Note the #index! call to trigger actual indexing.

Now that your indexes are declared, you can use an index to do a lookups:

    p Transaction.lookup{|q| q[:account_key].eq(1) }   # => [1]
    p Transaction.lookup{|q| q[:account_key].eq(2) }   # => [4,2,3]

The result is always an array of primary keys. You can also use a bare lookup to return all records:

    p Transaction.lookup       # => [1,2,3,4]

    # Also useful for counting:
    p Transaction.lookup.size  # => 4

Some indexes can be ordered by default:

    p Transaction.lookup{|q| q[:account_key].eq(2)}  # => [4,2,3]

Which can be combined with offset and limit:

    p Transaction.lookup{|q| q[:account_key].eq(2, limit: 1)}             # => [4]
    p Transaction.lookup{|q| q[:account_key].eq(2, limit: 1, offset: 1)}  # => [2]
    p Transaction.lookup{|q| q[:account_key].eq(2, limit: 1, offset: 2)}  # => [3]

Since the :primary_key index is ordered by insertion order, we've also declared a :by_created_at index on key that gives us the records ordered by the #created_at attribute:

    p Transaction.lookup{|q| q[:by_created_at].all}  # => [4,2,1,3]


## Querying

Relix uses a simple query language based on method chaining. A "root" query is passed in to the lookup block, and then query terms are chained off of it:

    class Person
      include Relix
      relix do
        primary_key :key
        multi :name, order: :birthdate
      end
    end

    people = Person.lookup{|q| q[:name].eq("Bob Smith")}

Basically you just specify an index and an operation against that index. In addition, you can specify options for the query, such as limit and offset, if supported by the index type. Relix only supports querying by a single index at a time.

Any ordered index can also be offset and limited:

    people = Person.lookup{|q| q[:name].eq("Bob Smith", offset: 5, limit: 5)}

In addition, rather than an offset, an indexed primary key can be specified as a starting place using from:

    person_id = Person.lookup{|q| q[:name].eq("Bob Smith")[2]}
    people = Person.lookup{|q| q[:name].eq("Bob Smith", from: person_id)}

The from option is exclusive - it does not return or count the key you pass to it.


## Indexing

### Inheritance

Indexes are inherited up the Ruby ancestor chain, so you can for instance set the primary_key in a base class and then not have to re-declare it in each subclass.

### Multiple Value Indexes

Indexes can be built over multiple attributes:

    relix do
      multi :storage_state_by_account, on: %w(storage_state account_id)
    end

When there are multiple attributes, they are specified in a hash:

    lookup do |q|
      q[:storage_state_by_account].eq(
        {storage_state: 'cached', account_id: 'bob'}, limit: 10)
    end

### Interrogative Accessors

Relix has some special handling for interrogative accessors (i.e. those ending with a `?`). When one is used, Relix is smart and does not require the `?` when querying:

    class Account
      include Relix
      relix do
        primary_key :key
        multi :active_and_admin, on: %w(active? admin?)
      end
    end

    accounts = Account.lookup{|q| q[:active_and_admin].eq(active: true, admin: true)}

It also auto-casts `nil` to `false` and any other object to `true` for interrogative accessors, so that lookups work like you'd expect them to in a Ruby context. If you don't want to auto-casting, just alias your interrogative to a non-interrogative name and index on that instead.

### Conditional Indexing

Relix allows you to decide on a per-object basis whether a given index should be built:

    class Person
      include Relix
      relix do
        primary_key :key
        multi :name, on: %w(first last), if: full_name?
      end

      def full_name?
        (first && last)
      end
    end

People will only be indexed now if they have both a first and a last name, otherwise they will not be included in the index at all. Note that this is also smart enough to deindex an object if its condition changes.

### Space efficiency

Model attributes that are indexed on but that never change can be marked as immutable to prevent them being stored (since they don't have to be reindexed). The primary key is marked immutable by default, but other attributes can be as well:

    relix do
      unique :token, immutable_attribute: true
    end

This can also provide concurrency benefits since the keys for the indexes on immutable attributes don't have to be watched for concurrent modification.


## Deindexing

You'll probably want to remove an object from the index at some point. To do that simply call `#deindex!` on it:

    person.deindex!

You can also remove something from the index even if you don't have the complete object in hand anymore; simply call `.deindex_by_primary_key!` on its class:

    Person.deindex_by_primary_key!(44)

The class-level `deindex_by_primary_key` cannot clean up immutable indexes other than the primary key (since the current value of immutable keys is not stored), so calling plain `deindex!` on an object is preferred.


## Index Types

### PrimaryKeyIndex

The primary key index is the only index that is required on a model. Under the covers it is stored very similarly to a UniqueIndex, and it is stably sorted in insertion order. It is declared using #primary_key within the relix block:

    relix do
      primary_key :id
    end

**Supported Operators**: eq, all
**Ordering**: insertion

### MultiIndex

Multi indexes allow multiple matching primary keys per indexed value, and are ideal for one to many relationships. They can include an ordering, and are declared using #multi in the relix block:

    relix do
      multi :account_id, order: :created_at
    end

**Supported Operators**: eq
**Ordering**: can be ordered on any numeric attribute (default is the to_i of the indexed value)

#### Values

If you declare the correct option, it's possible to pull the set of values that are being indexed on as well:

    relix.multi :account_id, index_values: true

    # Enables this call
    relix.lookup_values(:account_id)

This will yield all of the `account_ids` being indexed on, rather than the set of keys indexed by a particular set of `account_ids`. A typical use case would be fast iteration over grouped sub-models of a `many` relationship:

    User.lookup_values(:account_id).each do |account_id|
      users_for_account = User.lookup{|q| q[:account_id].eq(account_id)}
      # Aggregate processing for the users in the account
    end

The ordering of returned values is undefined.

### UniqueIndex

Unique indexes will raise an error if the same value is indexed twice for a different primary key. They also provide super fast lookups. They are declared using #unique in the relix block:

    relix do
      unique :email
    end

Unique indexes ignore nil values - they will not be indexed and an error is not raised if there is more than one object with a value of nil. A multi-value unique index will be completely skipped if any value in it is nil.

**Supported Operators**: eq, all
**Ordering**: can be ordered on any numeric attribute (default is the to_i of the indexed value)

### OrderedIndex

Ordered indexes are specifically designed to support range queries. Like a MultiIndex, they support multiple matching
primary keys per indexed value. They are declared using #ordered in the relix block:

    relix do
      ordered :birthdate
    end

**Supported Operators**: eq, lt, lte, gt, gte, order, limit, offset
**Ordering**: ordered ascending by the indexed value, but can be queried in
  reverse order if you use `order(:desc)`.

Ordered indexes support a flexible fluent interface for specifying the query:

    Person.lookup do |q|
      q[:birthdate].
        gte(Date.new(1990, 1, 1)).
        lt(Date.new(1991, 1, 1).
        order(:desc).
        limit(10)
    end

This query returns the primary keys of the 10 youngest people born in 1990.


## Keying

A big part of using Redis well is choosing solid keys; Relix has a pluggable keying infrastructure that makes it easy to use different key names for different situations. This actually rose out of the fact that the first release of Relix had a pathetic set of keys, and the need to support existing deployments while moving to something better going forward. Keyers are set on a per-model basis along with other configuration:

    relix do
      keyer Relix::Keyer::Compact
    end

You can set the default keyer like so:

    Relix.default_keyer(Relix::Keyer::Compact)

Keyers are inherited, with child classes will use their parent's keyer unless a keyer is explicitly set on the child.


### Standard

This keyer is nice and verbose, which makes it ideal for development since you can browse the Redis keyspace and see at a glance how the indexes are stored. **Standard is the default keyer.**


### Compact

Keys take up space, and especially since Redis holds the keyset in memory it can be a big boon with a large data set to keep key names short. The Compact keyer tries to balance a reasonable level of readability (we can't sacrifice the ability to debug production issues) with keeping keys as compact as possible.


### Legacy

This (eventually to be deprecated and removed) strategy exactly mirrors the keying supported by Relix when first released.


## Maintenance

### Index removal

Sometimes an index is no longer needed, or is being moved or renamed, and you'll want to clean up the old index data including both the index itself as well as the current values that are tracked for that index.

To remove an index, first change its declaration like so:

    class Transaction
      relix do
        obsolete { multi(:account_key, order: :created_at) }
      end
    end

This just wraps the original index declaration in an `obsolete` block. Doing this makes it so that the index is no longer updated (though it will still deindex), and also marks the index for removal within Relix.

Second, run `destroy_index` on the index:

    Transaction.relix.destroy_index(:account_key)

This will remove all related data from Redis. Note that `destroy_index` is idempotent, so while it's not recommended you run it multiple times (it iterates through the whole primary key space), it won't hurt anything if you do.

And finally: just delete the whole `obsolete` line from your relix declaration. The index is now dead - long live the index!
