defmodule Norm.ContractTest do
  use ExUnit.Case, async: true

  test "success" do
    defmodule Success do
      use Norm

      @contract foo(n :: spec(is_integer())) :: spec(is_integer())
      def foo(n), do: n
    end

    assert Success.foo(42) == 42
  end

  test "arg mismatch" do
    defmodule ArgMismatch do
      use Norm

      @contract foo(n :: spec(is_integer())) :: spec(is_integer())
      def foo(n), do: n
    end

    assert_raise Norm.MismatchError, ~r/val: "42" fails: is_integer\(\)/, fn ->
      ArgMismatch.foo("42")
    end
  end

  test "result mismatch" do
    defmodule ResultMismatch do
      use Norm

      @contract foo(n :: spec(is_integer())) :: spec(is_binary())
      def foo(n), do: n
    end

    assert_raise Norm.MismatchError, ~r/val: 42 fails: is_binary\(\)/, fn ->
      ResultMismatch.foo(42)
    end
  end

  test "pre-conditions" do
    defmodule PreConditions do
      use Norm

      @contract foo(n :: spec(is_integer())) :: spec(is_integer()),
        requires: fn n -> n in 0..9 end
      def foo(n), do: n
    end

    assert_raise RuntimeError, "pre-condition failed: fn n -> n in 0..9 end", fn ->
      PreConditions.foo(42)
    end
  end

  test "post-conditions" do
    defmodule PostConditions do
      use Norm

      @contract foo(n :: spec(is_integer())) :: spec(is_integer()),
        ensures: fn _n, result -> result in 0..9 end
      def foo(n), do: n
    end

    assert_raise RuntimeError, "post-condition failed: fn _n, result -> result in 0..9 end", fn ->
      PostConditions.foo(42)
    end
  end

  test "with local functions" do
    defmodule WithLocalFunctions do
      use Norm

      def int(), do: spec(is_integer())

      def less_than_10(n), do: n < 10

      def less_than_20(n), do: n < 20

      @contract foo(n :: int()) :: int(),
        requires: fn n -> less_than_10(n) end,
        requires: fn n -> less_than_20(n) end,
        ensures: fn _n, res -> less_than_20(res) end
      def foo(n), do: n * n
    end

    assert WithLocalFunctions.foo(1) == 1

    assert_raise RuntimeError, "pre-condition failed: fn n -> less_than_10(n) end", fn ->
      WithLocalFunctions.foo(10)
    end

    assert_raise RuntimeError, "post-condition failed: fn _n, res -> less_than_20(res) end", fn ->
      WithLocalFunctions.foo(5)
    end
  end

  test "disable" do
    defmodule Disabled do
      use Norm

      def int(), do: spec(is_integer())

      @contract foo(n :: int()) :: int(),
        enabled: false
      def foo(n), do: n
    end

    assert Disabled.foo("bar") == "bar"
  end

  test "bad contract" do
    assert_raise ArgumentError, ~r/got: `@contract\(foo\(n\)\)`/, fn ->
      defmodule BadContract do
        use Norm

        @contract foo(n)
        def foo(n), do: n
      end
    end
  end

  test "bad arg" do
    assert_raise ArgumentError, ~r/`arg :: spec`, got: `spec\(is_integer\(\)\)`/, fn ->
      defmodule BadArg do
        use Norm

        @contract foo(spec(is_integer())) :: spec(is_integer())
        def foo(n), do: n
      end
    end
  end

  test "no function" do
    assert_raise ArgumentError, "contract for undefined function foo/0", fn ->
      defmodule NoFunction do
        use Norm

        @contract foo() :: spec(is_integer())
      end
    end
  end
end
