defmodule Norm.Core.SpecTest do
  use Norm.Case, async: true

  defmodule Foo do
    def hello?(str), do: str == "hello"

    def match?(x, given), do: x == given
  end

  describe "spec/1" do
    test "can compose specs with 'and'" do
      hex = spec(is_binary() and (&String.starts_with?(&1, "#")))

      assert "#000000" == conform!("#000000", hex)
      assert {:error, errors} = conform(nil, hex)
      assert errors == [%{spec: "is_binary()", input: nil, path: []}]
      assert {:error, errors} = conform("bad", hex)
      assert errors == [%{spec: "&(String.starts_with?(&1, \"#\"))", input: "bad", path: []}]
    end

    test "'and' and 'or' can be chained" do
      s = spec(is_integer() and (&(&1 >= 21)) and (&(&1 < 30)))

      check all(i <- StreamData.integer(21..29)) do
        assert i == conform!(i, s)
      end
    end

    test "works with remote functions" do
      require Integer

      evens = spec(is_integer() and Integer.is_even())
      assert 2 == conform!(2, evens)
      assert {:error, [%{spec: "Integer.is_even()", input: 3, path: []}]} == conform(3, evens)

      hello = spec(Foo.hello?())
      assert "hello" == conform!("hello", hello)
      assert {:error, [%{spec: "Foo.hello?()", input: "foo", path: []}]} == conform("foo", hello)

      foo = spec(Foo.match?("foo"))
      assert "foo" == conform!("foo", foo)
      assert {:error, [%{spec: "Foo.match?(\"foo\")", input: "bar", path: []}]} == conform("bar", foo)
    end

    test "supports eliding of parenthesis around functions" do
      require Integer

      evens = spec(is_integer and Integer.is_even)
      assert conform!(2, evens) == 2
      assert {:error, errors} = conform("1", evens)
      assert errors == [
        %{input: "1", path: [], spec: "is_integer()"}
      ]

      matcher = spec(Foo.match?("foo") and is_binary)
      assert conform!("foo", matcher) == "foo"
      assert {:error, errors} = conform("1", matcher)
      assert errors == [
        %{input: "1", path: [], spec: "Foo.match?(\"foo\")"}
      ]
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
        Enum.take(gen(spec(is_binary() and (&(&1 =~ ~r/foobarbaz/)))), 1)
      end
    end

    test "works with 'and'" do
      name = spec(is_binary() and (&(String.length(&1) > 0)))

      for name <- Enum.take(gen(name), 3) do
        assert is_binary(name)
        assert String.length(name) > 0
      end

      age = spec(is_integer() and (&(&1 > 0)))

      for i <- Enum.take(gen(age), 3) do
        assert is_integer(i)
        assert i > 0
      end

      assert gen(spec(is_integer() and fn i -> i > 0 end and (&(&1 > 60))))
    end

    test "works with 'or'" do
      name_or_age = spec(is_integer() or is_binary())

      for f <- Enum.take(gen(name_or_age), 10) do
        assert is_binary(f) || is_integer(f)
      end
    end

    test "'or' returns an error if it can't infer both generators" do
      assert_raise Norm.GeneratorError, fn ->
        Enum.take(gen(spec(is_integer() or (&(&1 > 0)))), 1)
      end
    end

    property "works with remote functions" do
      require Integer
      evens = spec(is_integer() and Integer.is_even())

      check all(i <- gen(evens)) do
        assert is_integer(i)
        assert rem(i, 2) == 0
      end
    end
  end

  describe "inspect" do
    test "predicate" do
      assert inspect(spec(is_integer())) == "#Norm.Spec<is_integer()>"
    end

    test "lambda" do
      assert inspect(spec(&(&1 >= 21))) == "#Norm.Spec<&(&1 >= 21)>"
    end

    test "and" do
      assert inspect(spec(is_integer() and (&(&1 >= 21)))) ==
               "#Norm.Spec<is_integer() and &(&1 >= 21)>"
    end

    test "or" do
      assert inspect(spec(is_integer() or is_float())) ==
               "#Norm.Spec<is_integer() or is_float()>"
    end
  end
end
