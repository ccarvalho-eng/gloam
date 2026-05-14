defmodule Gloam.RuntimeConfigTest do
  use ExUnit.Case, async: true

  test "disables timezone data autoupdate at runtime" do
    assert Application.fetch_env!(:tzdata, :autoupdate) == :disabled
  end
end
