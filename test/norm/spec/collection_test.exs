defmodule Norm.Spec.CollectionTest do
  use ExUnit.Case, async: true
  import Norm

  test "inspect" do
    spec = coll_of(spec(is_atom()))
    assert inspect(spec) == "#Norm.CollOf<#Norm.Spec<is_atom()>>"
  end
end
