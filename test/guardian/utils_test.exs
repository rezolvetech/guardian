defmodule Backoffice.Guardian.UtilsTest do
  @moduledoc false
  use ExUnit.Case, async: true

  test "stringify_keys" do
    assert Backoffice.Guardian.Utils.stringify_keys(nil) == %{}
    assert Backoffice.Guardian.Utils.stringify_keys(%{foo: "bar"}) == %{"foo" => "bar"}
    assert Backoffice.Guardian.Utils.stringify_keys(%{"foo" => "bar"}) == %{"foo" => "bar"}
  end

  test "timestamp" do
    {mgsec, sec, _usec} = :os.timestamp
    assert Backoffice.Guardian.Utils.timestamp == mgsec * 1_000_000 + sec
  end
end
