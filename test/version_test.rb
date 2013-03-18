require 'test_helper'

class VersionTest < RelixTest
  def test_comparisons
    major1, major2 = Relix::Version.new("1"), Relix::Version.new("2")
    assert_operator major1, :<, major2
    assert_operator major2, :>, major1
    assert_operator major1, :==, major1
    assert_operator major1, :==, Relix::Version.new("1.0")
    assert_operator major1, :==, Relix::Version.new("1.0.0")

    minor11, minor12 = Relix::Version.new("1.1"), Relix::Version.new("1.2")
    assert_operator minor11, :<, minor12
    assert_operator minor12, :>, minor11
    assert_operator minor11, :==, minor11
    assert_operator major1, :<, minor11
    assert_operator minor11, :>, major1
    assert_operator major2, :>, minor11
    assert_operator minor11, :<, major2
    assert_operator minor11, :==, Relix::Version.new("1.1.0")

    patch111, patch112 = Relix::Version.new("1.1.1"), Relix::Version.new("1.1.2")
    assert_operator patch111, :<, patch112
    assert_operator patch112, :>, patch111
    assert_operator patch111, :==, patch111
    assert_operator minor11, :<, patch111
    assert_operator patch111, :>, minor11
    assert_operator minor12, :>, patch111
    assert_operator patch111, :<, minor12
  end
end
