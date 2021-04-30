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

  test "no function" do
    assert_raise ArgumentError, "contract for undefined function foo/0", fn ->
      defmodule NoFunction do
        use Norm

        @contract foo() :: spec(is_integer())
      end
    end
  end

  test "function definition without parentheses" do
    defmodule WithoutParentheses do
      use Norm

      @contract fun() :: spec(is_integer())
      def fun do
        42
      end
    end

    assert WithoutParentheses.fun() == 42
  end

  test "non-contract function definition without parentheses" do
    defmodule WithoutParentheses2 do
      use Norm

      @contract fun(int :: spec(is_integer())) :: spec(is_integer())
      def fun(int) do
        int * 2
      end

      def other do
        "Hello, world!"
      end
    end

    assert WithoutParentheses2.fun(50) == 100
    assert WithoutParentheses2.other() == "Hello, world!"
  end

  test "reflection" do
    defmodule Reflection do
      use Norm

      def int, do: spec(is_integer())

      @contract foo(a :: int(), int()) :: int()
      def foo(a, b), do: a + b
    end

    contract = Reflection.__contract__({:foo, 2})

    assert inspect(contract) ==
             "%Norm.Contract{args: [a: #Norm.Spec<is_integer()>, arg2: #Norm.Spec<is_integer()>], result: #Norm.Spec<is_integer()>}"
  end
end
