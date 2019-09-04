defmodule Norm.GeneratorTest do
  use ExUnit.Case, async: true
  import Norm

  alias Norm.Generator

  describe "null generators" do
    test "continue to work for conforming" do
      spec = Generator.new(spec(is_integer()), :null)

      assert 123 == conform!(123, spec)
      assert {:error, ["val: \"foo\" fails: is_integer()"]} = conform("foo", spec)
    end

    test "raises when generating" do
      spec = Generator.new(spec(is_integer()), :null)

      assert_raise Norm.GeneratorLibraryError, fn ->
        gen(spec)
      end
    end
  end
end
