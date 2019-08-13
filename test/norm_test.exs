defmodule NormTest do
  use ExUnit.Case
  doctest Norm, import: true
  import Norm

  describe "gen" do
    @tag :skip
    test "uses the generator created by spec" do
    end

    @tag :skip
    test "returns an error if the generator can not be found" do
    end
  end

  describe "with_gen" do
    test "overrides the default generator" do
      spec = with_gen(spec(is_integer()), gen(spec(is_binary())))
      for str <- Enum.take(gen(spec), 5), do: assert is_binary(str)

      spec = with_gen(schema(%{foo: spec(is_integer())}), StreamData.constant("foo"))
      for str <- Enum.take(gen(spec), 5), do: assert str == "foo"
    end
  end

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

  describe "selection/1" do
    @tag :skip
    test "returns an error if passed a non-schema" do
      flunk "Not implemented yet"
    end

    @tag :skip
    test "specifies a subset of a schema" do
      flunk "Not implemented yet"
    end
  end

  describe "alt/1" do
    test "returns errors" do
      spec = alt(a: schema(%{name: spec(is_binary())}), b: spec(is_binary()))

      assert {:a, %{name: "alice"}} == conform!(%{name: "alice"}, spec)
      assert {:b, "foo"} == conform!("foo", spec)
      assert {:error, errors} = conform(%{name: :alice}, spec)
      assert errors == [
        "val: :alice fails: is_binary() in: :a/:name",
        "val: %{name: :alice} fails: is_binary() in: :b"
      ]
    end

    test "can generate data" do
      spec = alt(a: spec(is_binary()), b: spec(is_integer()))
      vals =
        spec
        |> gen()
        |> Enum.take(5)

      assert Enum.count(vals) == 5
      for val <- vals do
        assert is_binary(val) || is_integer(val)
      end
    end
  end

  describe "cat/1" do
    @tag :skip
    test "checks a list of options" do
      flunk "Not implemented"
    end
  end
end
