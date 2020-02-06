defmodule Norm.Core.AnyOfTest do
  use Norm.Case, async: true

  describe "conforming" do
    test "returns the first match" do
      union = one_of([:foo, spec(is_binary())])

      assert :foo == conform!(:foo, union)
      assert "chris" == conform!("chris", union)
      assert {:error, errors} = conform(123, union)

      assert errors == [
        %{spec: "is not an atom.", input: 123, path: []},
        %{spec: "is_binary()", input: 123, path: []}
      ]
    end

    test "accepts nil if part of the union" do
      union = one_of([spec(is_nil()), spec(is_binary())])

      assert nil == conform!(nil, union)
      assert "foo" == conform!("foo", union)
      assert {:error, errors} = conform(42, union)

      assert errors == [
        %{spec: "is_nil()", input: 42, path: []},
        %{spec: "is_binary()", input: 42, path: []}
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

  test "inspect" do
    union = one_of([:foo, spec(is_binary())])
    assert inspect(union) == "#Norm.OneOf<[:foo, #Norm.Spec<is_binary()>]>"
  end
end
