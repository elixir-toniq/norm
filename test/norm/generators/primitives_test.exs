defmodule Norm.Generators.GeneratorTest do
  use ExUnit.Case, async: true
  import Norm

  alias Norm.Generator

  describe "generates primitive types" do
    test "generates values from spec(is_float())" do
      [output | _] = is_float() |> spec() |> gen() |> Enum.take(1)

      assert is_float(output)
    end
  end
end
