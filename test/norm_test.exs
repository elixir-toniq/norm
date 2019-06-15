defmodule NormTest do
  use ExUnit.Case
  doctest Norm, import: true
  import Norm

  describe "schema/1" do
    test "creates a re-usable schema" do
      s = schema(%{name: spec(is_binary())})
      assert %{name: "Chris"} == conform!(%{name: "Chris"}, s)
      assert {:error, _errors} = conform(%{foo: "bar"}, s)
      assert {:error, _errors} = conform(%{name: 123}, s)

      user = schema(%{user: schema(%{name: spec(is_binary())})})
      assert %{user: %{name: "Chris"}} == conform!(%{user: %{name: "Chris"}}, user)
    end
  end

  describe "conform/2" do
    test "returns the correct data or exceptions" do
      # iex> conform(:atom, sand(string?(), lit("foo")))
      # {:error, ["val: :atom fails: string?()", "val: :atom fails: \"foo\""]}
      # iex> conform(:atom, sor(string?(), integer?()))
      # {:error, ["val: :atom fails: string?()", "val: :atom fails: integer?()"]}
      # iex> conform(42, is_integer())
      # {:ok, 42}
      # iex> conform(42, fn x -> x == 42 end)
      # {:ok, 42}
      # iex> conform(42, &(&1 >= 0))
      # {:ok, 42}
      # iex> conform(42, &(&1 >= 100))
      # {:error, ["val: 42 fails: &(&1 >= 100)"]}
      # iex> conform("foo", is_integer())
      # {:error, ["val: \"foo\" fails: is_integer()"]}
  # iex> conform(:atom, lit("string"))
  # {:error, ["val: :atom fails: \"string\""]}
  # iex> conform(1, string?())
  # {:error, ["val: 1 fails: string?()"]}
    end
  end

  describe "conform!" do
    test "returns data or throws exception" do
  # iex> conform!("foo", sand(string?(), lit("foo")))
  # "foo"
  # iex> conform!("foo", sor(string?(), integer?()))
  # "foo"
  # iex> conform!(1, sor(string?(), integer?()))
  # 1
  # iex> conform!(1, lit(1))
  # 1
  # iex> conform!("string", lit("string"))
  # "string"
  # iex> conform!(:atom, lit(:atom))
  # :atom
  # iex> conform!("foo", string?())
  # "foo"
    end
  end

  describe "gen" do
    test "uses the generator created by spec" do

    end

    test "returns an error if the generator can not be found" do

    end
  end
end
