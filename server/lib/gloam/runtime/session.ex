defmodule Gloam.Runtime.Session do
  @moduledoc """
  Pure session state and event application.

  `Gloam.Runtime.SessionServer` will own this state in production. The pure
  module stays process-free so rules and replay behavior are easy to test.
  """

  alias Gloam.Commands.Command
  alias Gloam.Events.Event
  alias Gloam.Rules.{Engine, Error}

  @type t :: %__MODULE__{
          id: String.t(),
          world: struct(),
          player: struct(),
          events: [Event.t()],
          seen_command_ids: MapSet.t(String.t())
        }

  defstruct [:id, :world, :player, events: [], seen_command_ids: MapSet.new()]

  @spec start(map(), keyword()) :: {:ok, t(), [Event.t()]}
  def start(%{world: world, player: player}, opts) do
    session_id = Keyword.fetch!(opts, :session_id)

    session = %__MODULE__{id: session_id, world: world, player: player}

    event =
      Event.new!(%{
        session_id: session_id,
        type: :session_started,
        actor_id: player.id,
        subject_id: world.id,
        data: %{}
      })

    updated = apply_events(session, [event])
    {:ok, updated, [event]}
  end

  @spec submit_command(t(), Command.t()) ::
          {:ok, t(), [Event.t()]} | {:error, Error.t(), t(), [Event.t()]}
  def submit_command(%__MODULE__{} = session, %Command{} = command) do
    if MapSet.member?(session.seen_command_ids, command.id) do
      {:ok, session, []}
    else
      plan_command(session, command)
    end
  end

  @spec snapshot(t()) :: map()
  def snapshot(%__MODULE__{} = session) do
    %{
      session_id: session.id,
      world_id: session.world.id,
      calendar: session.world.calendar,
      player: session.player,
      event_count: length(session.events)
    }
  end

  defp plan_command(session, command) do
    case Engine.plan(session, command) do
      {:ok, events} -> accept_command(session, command, events)
      {:error, error} -> reject_command(session, command, error)
    end
  end

  defp accept_command(session, command, events) do
    session =
      session
      |> mark_seen(command)
      |> apply_events(events)

    {:ok, session, events}
  end

  defp reject_command(session, command, error) do
    event =
      Event.new!(%{
        session_id: session.id,
        type: :command_rejected,
        actor_id: command.actor_id,
        subject_id: command.target_id,
        correlation_id: command.id,
        data: %{code: error.code, message: error.message, details: error.details}
      })

    session =
      session
      |> mark_seen(command)
      |> apply_events([event])

    {:error, error, session, [event]}
  end

  defp mark_seen(session, command) do
    %{session | seen_command_ids: MapSet.put(session.seen_command_ids, command.id)}
  end

  defp apply_events(session, events) do
    Enum.reduce(events, session, &apply_event/2)
  end

  defp apply_event(
         %Event{type: :player_moved, data: %{location_id: location_id}} = event,
         session
       ) do
    player = %{session.player | location_id: location_id}
    append_event(%{session | player: player}, event)
  end

  defp apply_event(%Event{type: :calendar_advanced, data: %{calendar: calendar}} = event, session) do
    world = %{session.world | calendar: calendar}
    append_event(%{session | world: world}, event)
  end

  defp apply_event(%Event{} = event, session) do
    append_event(session, event)
  end

  defp append_event(session, event) do
    %{session | events: session.events ++ [event]}
  end
end
