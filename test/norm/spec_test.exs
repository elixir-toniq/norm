defmodule Norm.SpecTest do
  use ExUnit.Case, async: true
  import Norm

  describe "spec/1" do
    test "can and specs" do
      can_drink = spec(is_integer() and &(&1 >= 21))

      assert 21 == conform!(21, can_drink)
      assert {:error, errors} = conform("21", can_drink)
      assert errors == ["val: \"21\" fails: is_integer()"]
      assert {:error, errors} = conform(20, can_drink)
      assert errors == ["val: 20 fails: &(&1 >= 21)"]
    end
  end

  describe "generation" do
    test "infers the type from the first predicate" do
      name = spec(fn x -> String.length(x) > 0 end and is_binary())

      assert_raise Norm.GeneratorError, fn ->
        Enum.take(gen(name), 3)
      end
    end

    test "throws an error if it can't infer the generator" do
      assert_raise Norm.GeneratorError, fn ->
        Enum.take(gen(spec(&(String.length(&1) > 0))), 1)
      end
    end

    test "throws an error if the filter is too vague" do
      assert_raise StreamData.FilterTooNarrowError, fn ->
        Enum.take(gen(spec(is_binary() and &(&1 =~ ~r/foobarbaz/))), 1)
      end
    end

    test "works with and" do
      name = spec(is_binary() and &(String.length(&1) > 0))
      for name <- Enum.take(gen(name), 3) do
        assert is_binary(name)
        assert String.length(name) > 0
      end

      age = spec(is_integer() and &(&1 > 0))
      for i <- Enum.take(gen(age), 3) do
        assert is_integer(i)
        assert i > 0
      end
    end

    test "works with 'or'" do
      name_or_age = spec(is_integer() or is_binary())
      for f <- Enum.take(gen(name_or_age), 10) do
        assert is_binary(f) || is_integer(f)
      end
    end

    test "'or' returns an error if it can't infer both generators" do
      assert_raise Norm.GeneratorError, fn ->
        Enum.take(gen(spec(is_integer() or &(&1 > 0))), 1)
      end
    end
  end
end
