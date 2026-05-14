defmodule Gloam.Agents do
  @moduledoc """
  Public agent boundary for autonomous world behavior.
  """

  alias Gloam.Agents.{CommandProposal, Error, NPCSchedules, Proposals}

  @type proposal_result :: {:ok, CommandProposal.t()} | {:error, Error.t() | term()}

  @spec propose_command(map(), map()) :: proposal_result()
  defdelegate propose_command(attrs, context \\ %{}), to: Proposals

  @spec plan_npc_movements(map(), map()) ::
          {:ok, [NPCSchedules.movement()]} | {:error, Error.t() | term()}
  defdelegate plan_npc_movements(attrs, context \\ %{}), to: NPCSchedules, as: :plan_movements
end
