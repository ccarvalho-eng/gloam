defmodule Gloam.Agents do
  @moduledoc """
  Public agent boundary for autonomous world behavior.
  """

  alias Gloam.Agents.{CommandProposal, Error, Proposals}

  @type proposal_result :: {:ok, CommandProposal.t()} | {:error, Error.t() | term()}

  @spec propose_command(map(), map()) :: proposal_result()
  defdelegate propose_command(attrs, context \\ %{}), to: Proposals
end
