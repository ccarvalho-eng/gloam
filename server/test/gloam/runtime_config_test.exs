defmodule Gloam.RuntimeConfigTest do
  use ExUnit.Case, async: true

  test "disables timezone data autoupdate at runtime" do
    assert Application.fetch_env!(:tzdata, :autoupdate) == :disabled
  end

  test "keeps automatic ticks disabled by default" do
    assert Application.fetch_env!(:gloam, :ticks)[:enabled] == false
  end
end
