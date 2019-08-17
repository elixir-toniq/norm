defmodule Norm.SpecTest do
  use ExUnit.Case, async: true
  import Norm
  import ExUnitProperties, except: [gen: 1]

  defmodule Foo do
    def hello?(str), do: str == "hello"

    def match?(x, given), do: x == given
  end

  describe "spec/1" do
    test "can compose specs with 'and'" do
      can_drink = spec(is_integer() and &(&1 >= 21))

      assert 21 == conform!(21, can_drink)
      assert {:error, errors} = conform("21", can_drink)
      assert errors == ["val: \"21\" fails: is_integer()"]
      assert {:error, errors} = conform(20, can_drink)
      assert errors == ["val: 20 fails: &(&1 >= 21)"]
    end

    test "and can only be used to compose predicates or other ands" do
      assert_raise ArgumentError, fn ->
        spec(is_integer() and :ok)
      end

      assert_raise ArgumentError, fn ->
        spec({spec(is_binary()), spec(is_integer())} and :ok)
      end

      assert_raise ArgumentError, fn ->
        spec({spec(is_binary()), spec(is_integer())} and &(&1 > 0))
      end

      assert_raise ArgumentError, fn ->
        spec(:ok and is_atom())
      end
    end

    test "or can compose with atoms or tuples" do
      s = spec(:ok or :error or (is_binary() and fn x -> x == "error" end))

      assert :ok == conform!(:ok, s)
      assert :error == conform!(:error, s)
      assert "error" == conform!("error", s)
      assert {:error, errors} = conform("foo", s)
      assert errors == [
        "val: \"foo\" fails: is not an atom.",
        "val: \"foo\" fails: is not an atom.",
        "val: \"foo\" fails: fn x -> x == \"error\" end"
      ]

      check all g <- gen(spec(:ok or :error or is_binary())) do
        assert g == :ok || g == :error || is_binary(g)
      end

      maybe = spec({spec(:ok), spec(is_binary())} or {spec(:error), spec(is_integer())})
      assert {:ok, "chris"} == conform!({:ok, "chris"}, maybe)

      check all m <- gen(maybe) do
        case m do
          {:ok, b} -> assert is_binary(b)
          {:error, i} -> assert is_integer(i)
        end
      end
    end

    test "'and' and 'or' can be chained" do
      s = spec(is_integer() and fn x -> x >= 21 end and fn x -> x < 30 end)

      check all i <- StreamData.integer(21..29) do
        assert i == conform!(i, s)
      end
    end

    test "works with remote functions" do
      require Integer

      evens = spec(is_integer() and Integer.is_even())
      assert 2 == conform!(2, evens)
      assert {:error, ["val: 3 fails: Integer.is_even()"]} == conform(3, evens)

      hello = spec(Foo.hello?())
      assert "hello" == conform!("hello", hello)
      assert {:error, ["val: \"foo\" fails: Foo.hello?()"]} == conform("foo", hello)

      foo = spec(Foo.match?("foo"))
      assert "foo" == conform!("foo", foo)
      assert {:error, ["val: \"bar\" fails: Foo.match?(\"foo\")"]} == conform("bar", foo)
    end

    @tag :skip
    test "and and or returned conformed values" do
      flunk "Not implemented"
    end

    test "can match atoms" do
      assert :ok == conform!(:ok, spec(:ok))
      assert {:error, errors} = conform("foo", spec(:ok))
      assert errors == ["val: \"foo\" fails: is not an atom."]
      assert {:error, errors} = conform(:mismatch, spec(:ok))
      assert errors == ["val: :mismatch fails: == :ok"]
    end

    test "can match patterns of tuples" do
      ok = spec({spec(:ok), spec(is_integer())})
      error = spec({spec(:error), spec(is_binary())})
      three = spec({spec(is_integer()), spec(is_integer()), spec(is_integer())})

      assert {:ok, 123}
      |> conform!(ok) == {:ok, 123}

      assert {:error, "something's wrong"}
      |> conform!(error) == {:error, "something's wrong"}

      assert {1, 2, 3} == conform!({1, 2, 3}, three)
      assert {:error, errors} = conform({1, :bar, "foo"}, three)
      assert errors == [
        "val: :bar fails: is_integer() in: 1",
        "val: \"foo\" fails: is_integer() in: 2"
      ]

      assert {:error, errors} = conform({:ok, "foo"}, ok)
      assert errors == ["val: \"foo\" fails: is_integer() in: 1"]

      assert {:error, errors} = conform({:ok, "foo", 123}, ok)
      assert errors == ["val: {:ok, \"foo\", 123} fails: incorrect tuple size"]

      assert {:error, errors} = conform({:ok, 123, "foo"}, ok)
      assert errors == ["val: {:ok, 123, \"foo\"} fails: incorrect tuple size"]
    end

    test "tuples can be composed with schema's and selections" do
      user = schema(%{name: spec(is_binary()), age: spec(is_integer())})
      ok = spec({spec(:ok), selection(user, [:name])})

      assert {:ok, %{name: "chris"}} == conform!({:ok, %{name: "chris", age: 31}}, ok)
      assert {:error, errors} = conform({:ok, %{age: 31}}, ok)
      assert errors == ["val: %{age: 31} fails: :required in: 1/:name"]
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

    test "works with 'and'" do
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

      assert gen(spec(is_integer() and fn i -> i > 0 end and &(&1 > 60)))
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

    property "works with atoms" do
      check all foo <- gen(spec(:foo)) do
        assert is_atom(foo)
        assert foo == :foo
      end

      check all a <- gen(spec(is_atom())) do
        assert is_atom(a)
      end
    end

    property "works with tuples" do
      ok = spec({spec(:ok), schema(%{name: spec(is_binary())})})

      check all tuple <- gen(ok) do
        assert {:ok, user} = tuple
        assert Map.keys(user) == [:name]
        assert is_binary(user.name)
      end

      assert_raise Norm.GeneratorError, fn ->
        gen(spec({spec(&(&1 > 0)), spec(is_binary())}))
      end

      ints = spec({spec(is_integer()), spec(is_integer()), spec(is_integer())})

      check all is <- gen(ints) do
        assert {a, b, c} = is
        assert is_integer(a)
        assert is_integer(b)
        assert is_integer(c)
      end
    end

    property "works with remote functions" do
      require Integer
      evens = spec(is_integer() and Integer.is_even())

      check all i <- gen(evens) do
        assert is_integer(i)
        assert rem(i, 2) == 0
      end
    end
  end
end
