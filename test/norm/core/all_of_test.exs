defmodule Norm.Core.AllOfTest do
  use Norm.Case, async: true

  describe "conforming" do
    test "all specs must hold true" do
      all = all_of([spec(is_atom), spec(fn x -> x == :foo end)])

      assert :foo == conform!(:foo, all)
      assert {:error, errors} = conform(:bar, all)
      assert errors == [
        %{input: :bar, path: [], spec: "fn x -> x == :foo end"}
      ]

      assert {:error, errors} = conform("bar", all)
      assert errors == [
        %{input: "bar", path: [], spec: "is_atom()"},
        %{input: "bar", path: [], spec: "fn x -> x == :foo end"}
      ]
    end
  end

  describe "generation" do
    @tag :skip
    test "generated values conform to all of the specs" do
      pos_numbers = all_of([spec(is_integer), spec(fn x -> x > 0 end)])

      check all num <- gen(pos_numbers) do
        assert is_integer(num)
        assert num > 0
      end
    end
  end
end
