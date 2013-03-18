require 'test_helper'

class KeyingTest < RelixTest
  def setup
    @m = Class.new do
      def self.name; "TestModel"; end
      include Relix
      relix do
        primary_key :key
        unique :email
        multi :parent
      end
      attr_accessor :key, :email, :parent
      def initialize(k,e,p); @key,@email,@parent = k,e,p; index! end
    end
  end

  def test_legacy_keys
    @m.relix.keyer(Relix::Keyer::Legacy)

    assert_equal "TestModel:current_values:1", @m.relix.current_values_name("1")
    assert_equal "TestModel:name", @m.relix.key_prefix("name")

    assert_equal "Relix::PrimaryKeyIndex:TestModel:primary_key",
      @m.relix.primary_key_index.name

    assert_equal "Relix::UniqueIndex:TestModel:email",
      @m.relix['email'].name
    assert_equal "Relix::UniqueIndex:TestModel:email:hash",
      @m.relix['email'].hash_name
    assert_equal "Relix::UniqueIndex:TestModel:email:zset",
      @m.relix['email'].sorted_set_name

    assert_equal "Relix::MultiIndex:TestModel:parent:fred",
      @m.relix['parent'].key_for('fred')
    assert_equal "Relix::MultiIndex:TestModel:parent",
      @m.relix['parent'].name
  end

  def test_standard_keys
    @m.relix.keyer(Relix::Keyer::Standard)

    assert_equal "TestModel:values:1", @m.relix.current_values_name("1")

    assert_equal "TestModel:key:primary_key",
      @m.relix.primary_key_index.name

    assert_equal "TestModel:email:unique",
      @m.relix['email'].name
    assert_equal "TestModel:email:unique:lookup",
      @m.relix['email'].hash_name
    assert_equal "TestModel:email:unique:ordering",
      @m.relix['email'].sorted_set_name

    assert_equal "TestModel:parent:multi:fred",
      @m.relix['parent'].key_for('fred')
    assert_equal "TestModel:parent:multi",
      @m.relix['parent'].name
  end

  def test_compact_keys_with_string
    @m.relix.keyer(Relix::Keyer::Compact, abbrev: "TM")

    assert_equal "TM:v:1", @m.relix.current_values_name("1")

    assert_equal "TM:key:p",
      @m.relix.primary_key_index.name

    assert_equal "TM:email:u",
      @m.relix['email'].name
    assert_equal "TM:email:u:lookup",
      @m.relix['email'].hash_name
    assert_equal "TM:email:u:ordering",
      @m.relix['email'].sorted_set_name

    assert_equal "TM:parent:m:fred",
      @m.relix['parent'].key_for('fred')
    assert_equal "TM:parent:m",
      @m.relix['parent'].name
  end

  def test_compact_keys_with_proc
    @m.relix.keyer(Relix::Keyer::Compact, abbrev: proc do |model_name|
      model_name[0..2]
    end)

    assert_equal "Tes:v:1", @m.relix.current_values_name("1")

    assert_equal "Tes:key:p",
      @m.relix.primary_key_index.name

    assert_equal "Tes:email:u",
      @m.relix['email'].name
    assert_equal "Tes:email:u:lookup",
      @m.relix['email'].hash_name
    assert_equal "Tes:email:u:ordering",
      @m.relix['email'].sorted_set_name

    assert_equal "Tes:parent:m:fred",
      @m.relix['parent'].key_for('fred')
    assert_equal "Tes:parent:m",
      @m.relix['parent'].name
  end

  def test_keyer_inheritance
    parent = Class.new do
      def self.name; "parent"; end
      include Relix
      relix do
        primary_key :key
        keyer Relix::Keyer::Legacy
      end
      attr_accessor :key
    end
    child = Class.new(parent) do
      def self.name; "child"; end
      relix do
        unique :email
      end
    end

    assert_equal "child:current_values:1", child.relix.current_values_name("1")
    assert_equal "Relix::PrimaryKeyIndex:parent:primary_key",
      child.relix.primary_key_index.name
    assert_equal "Relix::UniqueIndex:child:email",
      child.relix['email'].name

    parent.relix.keyer(Relix::Keyer::Standard)
    assert_equal "parent:values:1", child.relix.current_values_name("1")
    assert_equal "parent:key:primary_key",
      child.relix.primary_key_index.name
    assert_equal "child:email:unique",
      child.relix['email'].name

    child.relix.keyer(Relix::Keyer::Legacy)
    assert_equal "child:current_values:1", child.relix.current_values_name("1")
    assert_equal "parent:key:primary_key",
      child.relix.primary_key_index.name
    assert_equal "Relix::UniqueIndex:child:email",
      child.relix['email'].name

    child.relix.keyer(Relix::Keyer::Standard)
    assert_equal "child:values:1", child.relix.current_values_name("1")
    assert_equal "parent:key:primary_key",
      child.relix.primary_key_index.name
    assert_equal "child:email:unique",
      child.relix['email'].name
  end
end
