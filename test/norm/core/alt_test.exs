defmodule Norm.Core.AltTest do
  use Norm.Case, async: true

  describe "generation" do
    test "returns one of the options" do
      spec = alt(s: spec(is_binary()), i: spec(is_integer()), a: spec(is_atom()))

      for {type, value} <- Enum.take(gen(spec), 5) do
        case type do
          :s ->
            assert is_binary(value)

          :i ->
            assert is_integer(value)

          :a ->
            assert is_atom(value)
        end
      end
    end
  end

  describe "inspect" do
    test "alts" do
      spec = alt(s: spec(is_binary()), i: spec(is_integer()))

      assert inspect(spec) ==
               "#Norm.Alt<[s: #Norm.Spec<is_binary()>, i: #Norm.Spec<is_integer()>]>"
    end
  end
end
