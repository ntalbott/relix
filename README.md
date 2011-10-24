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

      attr_accessor :key, :account_key, :created_at

      redix do
        primary_key :key
        multi :account_key
        multi :created_at
        ordered :created_at, :numeric
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

Now that your indexes are declared, you can use the indexes to do lookups:

    p Transaction.lookup{|q| q[:account_key].eq(1) }   # => [1]
    p Transaction.lookup{|q| q[:account_key].eq(2) }   # => [2,3,4]

The result is always an array of primary keys. You can also use a bare lookup to return all records:

    p Transaction.lookup       # => [1,2,3,4]

    # Also useful for counting:
    p Transaction.lookup.size  # => 4

You can sort results (default sort is by primary key):

    p Transaction.lookup{|q| q[:account_key].eq(2).sort(:created_at)}  # => [4,2,3]

Which can be combined with offset and limit:

    p Transaction.lookup{|q| q[:account_key].eq(2).sort(:created_at).limit(1)}            # => [4]
    p Transaction.lookup{|q| q[:account_key].eq(2).sort(:created_at).limit(1).offset(1)}  # => [2]
    p Transaction.lookup{|q| q[:account_key].eq(2).sort(:created_at).limit(1).offset(2)}  # => [3]

## Indexes

### PrimaryKeyIndex

The primary key index is the only index that is required on a model. Under the covers it is a specialized UniqueIndex, and it is stably sorted in insertion order. It is declared using #primary_key within the redix block:

    redix do
      primary_key :id
    end

### MultiIndex

Multi indexes allow multiple matching primary keys per indexed value, and are ideal for one to many relationships. They provide no ordering, and are declared using #multi in the redix block:

    redix do
      multi :account_id
    end

### UniqueIndex

Unique indexes will raise an error if the same value is indexed twice for a different primary key. They also provide super fast lookups. They are declared using #unique in the redix block:

    redix do
      unique :email
    end

### OrderedIndex

Ordered indexes allow sorting, limiting, and offsetting, which are very useful for pagination. They are declared using #ordered in the redix block:

    redix do
      ordered :created_at
    end

## Query Language

Redix uses a simple query language based on method chaining. A "root" query is passed in to the lookup block, and then query terms are chained off of it:

    class Person
      include Redix
      redix do
        primary_key :key
        multi :name
        multi :birthdate
        ordered :birthdate
      end
    end

    people = Person.lookup do |q|
      q[:name].eq("Bob Smith")
      q.sort(:birthdate)
    end

Basically you just specify an index, and an operation against that index. In addition, you can specify general settings for the query, such as sort, limit and offset.

Allowable operations are #eq (equal), #ne (not equal), #gt (greater than), #lt (less than).

