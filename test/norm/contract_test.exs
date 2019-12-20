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
