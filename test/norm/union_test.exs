defmodule Norm.UnionTest do
  use ExUnit.Case, async: true
  import ExUnitProperties, except: [gen: 1]
  import Norm

  describe "conforming" do
    test "returns the first match" do
      union = one_of([:foo, spec(is_binary())])

      assert :foo == conform!(:foo, union)
      assert "chris" == conform!("chris", union)
      assert {:error, errors} = conform(123, union)

      assert errors == [
               "val: 123 fails: is not an atom.",
               "val: 123 fails: is_binary()"
             ]
    end

    test "accepts nil if part of the union" do
      union = one_of([nil, spec(is_binary())])

      assert nil == conform!(nil, union)
      assert "foo" == conform!("foo", union)
      assert {:error, errors} = conform(42, union)

      assert errors == [
               "val: 42 fails: is_nil()",
               "val: 42 fails: is_binary()"
             ]
    end
  end

  describe "generation" do
    property "randomly selects one of the options" do
      union = one_of([:foo, spec(is_binary())])

      check all(e <- gen(union)) do
        assert e == :foo || is_binary(e)
      end
    end
  end
end
