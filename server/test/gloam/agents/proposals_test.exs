defmodule Gloam.Agents.ProposalsTest do
  use ExUnit.Case, async: true

  alias Gloam.Agents
  alias Gloam.Agents.{CommandProposal, Error}
  alias Gloam.Runtime.Session
  alias Gloam.World.Content

  test "runs a Jido action to propose an agent sourced command" do
    attrs = %{
      agent_id: "village-guide",
      reason: "The player asked for directions.",
      confidence: 1,
      command: %{
        "id" => "agent-cmd-1",
        "session_id" => "session-1",
        "actor_id" => "player",
        "type" => "travel",
        "target_id" => "blacksmith",
        "params" => %{},
        "source" => "player"
      }
    }

    assert {:ok, %CommandProposal{} = proposal} = Agents.propose_command(attrs)
    assert proposal.agent_id == "village-guide"
    assert proposal.reason == "The player asked for directions."
    assert proposal.confidence == 1.0
    assert proposal.command.id == "agent-cmd-1"
    assert proposal.command.source == :agent
    assert proposal.command.type == :travel
  end

  test "keeps rule authority in the session runtime" do
    {:ok, session, _events} = Session.start(Content.living_village(), session_id: "session-1")

    attrs = %{
      agent_id: "village-guide",
      command: %{
        "id" => "agent-cmd-1",
        "session_id" => "session-1",
        "actor_id" => "player",
        "type" => "travel",
        "target_id" => "blacksmith",
        "params" => %{}
      }
    }

    assert {:ok, proposal} = Agents.propose_command(attrs)
    assert {:ok, updated, events} = Session.submit_command(session, proposal.command)
    assert Enum.map(events, & &1.type) == [:player_moved]
    assert Session.snapshot(updated).player.location_id == "blacksmith"
  end

  test "rejects invalid proposed command payloads" do
    attrs = %{
      agent_id: "village-guide",
      command: %{
        "id" => "agent-cmd-1",
        "session_id" => "session-1",
        "actor_id" => "player",
        "type" => "rewrite_world",
        "params" => %{}
      }
    }

    assert {:error, %Error{code: :invalid_command_proposal}} = Agents.propose_command(attrs)
  end
end
