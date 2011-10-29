# Redix

A Redis-backed indexing layer that can be used with any (or no) backend data storage.

## Big Fat Warning

I'm using README-driven development and Redix is a work in progress - until Redix reaches 1.0.0 **this README may not reflect reality**.

## Rationale

With the rise in popularity of non-relational databases, and the regular use of relational databases in non-relational ways, data indexing has become an aspect of data storage that you can't simply assume is handled for you. More and more applications are storing their data in databases that treat that stored data as opaque, and thus there's no query engine sitting on top of the data making sure that it can be quickly and flexibly looked up.

Redix is a layer that can be added on to any model to make all the normal types of querying you want to do: equality, less than/greater than, in set, range, limit, etc., quick and painless. Redix depends on Redis to be awesome at what it does - blazingly fast operations on basic data types - and layers on top of that pluggable indexing of your data for fast lookup.

## Philosophy

* Performance is paramount - be FAST.
* Leverage Redis and its strengths to the hilt. Never do in Redix what could be done in Redis.
* Be extremely tolerant to failure.
** Since we can't guarantee atomicity with the backing datastore, index early and clean up later.
** Make continuous index repair easy since the chaos monkey could attack at any time.
* Be pluggable; keep the core simple and allow easy extensibility

## Installation

If you're using bundler, add redix to your Gemfile:

    gem 'redix'

Otherwise gem install:

    $ gem install redix

## Usage

To index something in a model, include the Redix module, declare the primary key (required), and declare any additional indexes you want:

    class Transaction
      include Redix

      attr_accessor :key, :account_key, :amount, :created_at

      redix do
        primary_key :key
        multi :account_key, order: :created_at
        unique :by_amount, on: :key, order: :amount
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

    p Transaction.lookup{|q| q[:by_created_at].all}  # => 

## Querying

Redix uses a simple query language based on method chaining. A "root" query is passed in to the lookup block, and then query terms are chained off of it:

    class Person
      include Redix
      redix do
        primary_key :key
        multi :name, order: :birthdate
      end
    end

    people = Person.lookup{|q| q[:name].eq("Bob Smith")}

Basically you just specify an index, and an operation against that index. In addition, you can specify options for the query, such as limit and offset, if supported by the index type. Redix currently only supports querying by a single index at a time.

Any ordered index can also be offset and limited:

    people = Person.lookup{|q| q[:name].eq("Bob Smith", offset: 5, limit: 5)}

In addition, rather than an offset, an indexed object can be specified as a starting place using from:

    person_id = Person.lookup{|q| q[:name].eq("Bob Smith")[2]}
    people = Person.lookup{|q| q[:name].eq("Bob Smith", from: person_id)}

The from option is exclusive - it does not return or count the key you pass to it.


## Indexing

### Inheritance

Indexes are inherited up the Ruby ancestor chain, so you can for instance set the primary_key in a base class and then not have to re-declare it in each subclass.


### Multiple Value Indexes

Indexes can be built over multiple attributes:

    redix do
      multi :storage_state_by_account, on: %w(storage_state account_id)
    end

When there are multiple attributes, they are specified in a hash:

    lookup do |q|
      q[:storage_state_by_account].eq(
        {storage_state: 'cached', account_id: 'bob'}, limit: 10)
    end


## Index Types

### PrimaryKeyIndex

The primary key index is the only index that is required on a model. Under the covers it is stored very similarly to a UniqueIndex, and it is stably sorted in insertion order. It is declared using #primary_key within the redix block:

    redix do
      primary_key :id
    end

**Supported Operators**: eq, all
**Ordering**: insertion


### MultiIndex

Multi indexes allow multiple matching primary keys per indexed value, and are ideal for one to many relationships. They can include an ordering, and are declared using #multi in the redix block:

    redix do
      multi :account_id, order: :created_at
    end

**Supported Operators**: eq
**Ordering**: can be ordered on any numeric attribute (default is the to_i of the indexed value)


### UniqueIndex

Unique indexes will raise an error if the same value is indexed twice for a different primary key. They also provide super fast lookups. They are declared using #unique in the redix block:

    redix do
      unique :email
    end

Unique indexes ignore nil values - they will not be indexed and an error is not raised if there is more than one object with a value of nil. A multi-value unique index will be completely skipped if any value in it is nil.

**Supported Operators**: eq, all
**Ordering**: can be ordered on any numeric attribute (default is the to_i of the indexed value)