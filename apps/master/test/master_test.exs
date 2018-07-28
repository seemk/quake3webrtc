defmodule MasterTest do
  use ExUnit.Case
  doctest Master

  test "greets the world" do
    assert Master.hello() == :world
  end
end
