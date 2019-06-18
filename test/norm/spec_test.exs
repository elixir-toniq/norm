defmodule Norm.SpecTest do
  use ExUnit.Case, async: true
  import Norm

  describe "spec/1" do
    test "can and specs" do
      can_drink = spec(is_integer() and &(&1 >= 21))

      assert 21 == conform!(21, can_drink)
      assert {:error, errors} = conform("21", can_drink)
      assert errors == ["val: \"21\" fails: is_integer()"]
      assert {:error, errors} = conform(20, can_drink)
      assert errors == ["val: 20 fails: &(&1 >= 21)"]
    end
  end
end
