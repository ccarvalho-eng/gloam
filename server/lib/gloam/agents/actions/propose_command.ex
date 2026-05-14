defmodule Gloam.Agents.Actions.ProposeCommand do
  @moduledoc """
  Jido action that turns agent intent into a Gloam command proposal.
  """

  use Jido.Action,
    name: "gloam_propose_command",
    description: "Proposes a Gloam command for deterministic rule validation",
    schema: [
      agent_id: [type: :string, required: true],
      command: [type: :any, required: true],
      reason: [type: :string, default: ""],
      confidence: [type: :any, default: 1.0]
    ]

  alias Gloam.Agents.CommandProposal

  @impl Jido.Action
  def run(params, _context) do
    with {:ok, proposal} <- CommandProposal.new(params) do
      {:ok, %{proposal: CommandProposal.to_map(proposal)}}
    end
  end
end
