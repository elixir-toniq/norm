defmodule Norm.Generators.GeneratorTest do
  use ExUnit.Case, async: true
  import Norm

  describe "generates primitive types" do
    test "generates values from spec(is_atom())" do
      spec = spec(is_atom())
      output = generate_value_for_spec(spec)

      assert is_atom(output)
    end

    test "generates values from spec(is_boolean())" do
      spec = spec(is_boolean())
      output = generate_value_for_spec(spec)

      assert is_boolean(output)
    end

    test "generates values from spec(is_binary())" do
      spec = spec(is_binary())
      output = generate_value_for_spec(spec)

      assert is_binary(output)
    end

    test "generates values from spec(is_bitstring())" do
      spec = spec(is_bitstring())
      output = generate_value_for_spec(spec)

      assert is_bitstring(output)
    end

    test "generates values from spec(is_float())" do
      spec = spec(is_float())
      output = generate_value_for_spec(spec)

      assert is_float(output)
    end

    test "generates values from spec(is_integer())" do
      spec = spec(is_integer())
      output = generate_value_for_spec(spec)

      assert is_integer(output)
    end
  end

  defp generate_value_for_spec(spec) do
    spec
    |> gen()
    |> Enum.take(1)
    |> hd()
  end
end
