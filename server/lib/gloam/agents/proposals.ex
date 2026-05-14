defmodule Gloam.Agents.Proposals do
  @moduledoc """
  Public boundary for running agent proposal primitives.
  """

  alias Gloam.Agents.Actions.ProposeCommand
  alias Gloam.Agents.{CommandProposal, Error}

  @type proposal_result :: {:ok, CommandProposal.t()} | {:error, Error.t() | term()}

  @spec propose_command(map(), map()) :: proposal_result()
  def propose_command(attrs, context \\ %{}) when is_map(attrs) and is_map(context) do
    case Jido.Exec.run(ProposeCommand, attrs, context, max_retries: 0, log_level: :emergency) do
      {:ok, %{proposal: proposal}} -> CommandProposal.new(proposal)
      {:error, %Error{} = error} -> {:error, error}
      {:error, reason} -> normalize_error(reason)
    end
  end

  defp normalize_error(%{
         message: message,
         details: %{__struct__: Error, code: code, details: details}
       }) do
    {:error, Error.new(code, message, details)}
  end

  defp normalize_error(reason), do: {:error, reason}
end
