defmodule Gloam.Agents.NPCSchedules do
  @moduledoc """
  Agent boundary for deterministic NPC schedule movement proposals.
  """

  alias Gloam.Agents.Actions.PlanNPCSchedules
  alias Gloam.Agents.WorldBrain
  alias Gloam.Agents.Error
  alias Jido.Agent.Directive

  @type movement :: %{required(:npc) => struct(), required(:location_id) => String.t()}

  @spec plan_movements(map(), map()) :: {:ok, [movement()]} | {:error, Error.t() | term()}
  def plan_movements(attrs, context \\ %{}) when is_map(attrs) and is_map(context) do
    case plan_with_brain(attrs, context) do
      {:ok, _brain, movements} -> {:ok, movements}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec plan_with_brain(map(), map()) ::
          {:ok, Jido.Agent.t(), [movement()]} | {:error, Error.t() | term()}
  def plan_with_brain(attrs, context \\ %{}) when is_map(attrs) and is_map(context) do
    brain = WorldBrain.new(state: Map.merge(%{movements: []}, attrs))

    {brain, directives} =
      WorldBrain.cmd(brain, {PlanNPCSchedules, attrs, context}, max_retries: 0)

    case directive_error(directives) do
      nil -> {:ok, brain, Map.get(brain.state, :movements, [])}
      reason -> normalize_error(reason)
    end
  end

  defp directive_error([%Directive.Error{error: error} | _directives]), do: error
  defp directive_error([_directive | directives]), do: directive_error(directives)
  defp directive_error([]), do: nil

  defp normalize_error(%{message: message}) do
    {:error, Error.new(:npc_schedule_planning_failed, message)}
  end

  defp normalize_error(reason), do: {:error, reason}
end
