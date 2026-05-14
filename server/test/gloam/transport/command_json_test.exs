defmodule Gloam.Transport.CommandJSONTest do
  use ExUnit.Case, async: true

  alias Gloam.Commands.Command
  alias Gloam.Transport.CommandJSON

  test "decodes a Godot command payload into a domain command" do
    payload = %{
      "id" => "cmd-1",
      "session_id" => "session-1",
      "actor_id" => "player",
      "type" => "travel",
      "target_id" => "blacksmith",
      "params" => %{},
      "source" => "player"
    }

    assert {:ok, %Command{} = command} = CommandJSON.decode(payload)
    assert command.id == "cmd-1"
    assert command.session_id == "session-1"
    assert command.actor_id == "player"
    assert command.type == :travel
    assert command.target_id == "blacksmith"
    assert command.params == %{}
    assert command.source == :player
  end

  test "rejects unknown command types without creating atoms" do
    payload = valid_payload(%{"type" => "become_admin"})

    assert {:error, error} = CommandJSON.decode(payload)
    assert error.code == :unknown_command_type
  end

  test "rejects unknown sources without creating atoms" do
    payload = valid_payload(%{"source" => "browser_console"})

    assert {:error, error} = CommandJSON.decode(payload)
    assert error.code == :unknown_command_source
  end

  test "rejects missing required fields" do
    payload = Map.delete(valid_payload(), "session_id")

    assert {:error, error} = CommandJSON.decode(payload)
    assert error.code == :missing_field
    assert error.details == %{field: "session_id"}
  end

  test "round trips command JSON strings" do
    json = Jason.encode!(valid_payload())

    assert {:ok, command} = CommandJSON.decode_json(json)
    assert Jason.encode!(CommandJSON.encode(command))
  end

  defp valid_payload(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "cmd-1",
        "session_id" => "session-1",
        "actor_id" => "player",
        "type" => "wait",
        "target_id" => nil,
        "params" => %{"minutes" => 30},
        "source" => "player"
      },
      overrides
    )
  end
end
