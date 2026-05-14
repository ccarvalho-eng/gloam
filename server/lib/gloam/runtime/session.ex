defmodule Gloam.Runtime.Session do
  @moduledoc """
  Pure session state and event application.

  `Gloam.Runtime.SessionServer` will own this state in production. The pure
  module stays process-free so rules and replay behavior are easy to test.
  """

  alias Gloam.Commands.Command
  alias Gloam.Events.Event
  alias Gloam.Rules.{Engine, Error}
  alias Gloam.Agents
  alias Gloam.World.{Calendar, NPC}

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

  @spec replay(map(), String.t(), [Event.t()]) :: {:ok, t()}
  def replay(%{world: world, player: player}, session_id, events) when is_binary(session_id) do
    session = %__MODULE__{id: session_id, world: world, player: player}
    {:ok, apply_events(session, events)}
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

  @spec tick(t(), pos_integer()) :: {:ok, t(), [Event.t()]} | {:error, Error.t(), t(), []}
  def tick(%__MODULE__{} = session, minutes) do
    with :ok <- validate_tick_minutes(minutes),
         {:ok, calendar, facts} <- Calendar.advance(session.world.calendar, minutes) do
      correlation_id = tick_correlation_id()

      case scheduled_npc_events(session, calendar, correlation_id) do
        {:ok, npc_events} ->
          events = [tick_event(session, calendar, facts, minutes, correlation_id)] ++ npc_events

          {:ok, apply_events(session, events), events}

        {:error, %Error{} = error} ->
          {:error, error, session, []}
      end
    else
      {:error, %Error{} = error} -> {:error, error, session, []}
    end
  end

  @spec snapshot(t()) :: map()
  def snapshot(%__MODULE__{} = session) do
    %{
      session_id: session.id,
      world_id: session.world.id,
      calendar: session.world.calendar,
      player: session.player,
      npcs: session.world.npcs,
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

  defp validate_tick_minutes(minutes)
       when is_integer(minutes) and minutes > 0 and minutes <= 1_440,
       do: :ok

  defp validate_tick_minutes(_minutes) do
    {:error,
     Error.new(:invalid_tick_duration, "Tick duration must be between 1 and 1440 minutes")}
  end

  defp tick_event(session, calendar, facts, minutes, correlation_id) do
    Event.new!(%{
      session_id: session.id,
      type: :calendar_advanced,
      actor_id: "system",
      subject_id: session.world.id,
      correlation_id: correlation_id,
      data: %{calendar: calendar, facts: facts, minutes: minutes}
    })
  end

  defp scheduled_npc_events(%{world: %{npcs: npcs}} = session, calendar, correlation_id)
       when is_map(npcs) do
    case Agents.plan_npc_movements(%{npcs: session.world.npcs, time_band: calendar.time_band}) do
      {:ok, movements} ->
        {:ok, Enum.map(movements, &npc_moved_event(session, &1, correlation_id))}

      {:error, reason} ->
        {:error, npc_schedule_error(reason)}
    end
  end

  defp scheduled_npc_events(_session, _calendar, _correlation_id) do
    {:error, Error.new(:npc_schedule_planning_failed, "NPC schedule planning failed")}
  end

  defp npc_schedule_error(%{code: code, message: message, details: details}) do
    Error.new(code, message, details)
  end

  defp npc_schedule_error(%{code: code, message: message}) do
    Error.new(code, message)
  end

  defp npc_schedule_error(_reason) do
    Error.new(:npc_schedule_planning_failed, "NPC schedule planning failed")
  end

  defp npc_moved_event(session, %{npc: %NPC{} = npc, location_id: location_id}, correlation_id) do
    Event.new!(%{
      session_id: session.id,
      type: :npc_moved,
      actor_id: "system",
      subject_id: npc.id,
      correlation_id: correlation_id,
      data: %{npc: npc, location_id: location_id}
    })
  end

  defp tick_correlation_id do
    "tick-" <> Integer.to_string(System.unique_integer([:positive, :monotonic]))
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

  defp apply_event(
         %Event{type: :npc_moved, subject_id: npc_id, data: data} = event,
         session
       ) do
    npcs = update_npc_location(session.world.npcs, npc_id, data)
    world = %{session.world | npcs: npcs}
    append_event(%{session | world: world}, event)
  end

  defp apply_event(%Event{} = event, session) do
    append_event(session, event)
  end

  defp update_npc_location(npcs, npc_id, %{location_id: location_id, npc: %NPC{} = moved_npc}) do
    restored_npc = %{moved_npc | location_id: location_id}

    Map.update(npcs, npc_id, restored_npc, fn %NPC{} = npc ->
      %{npc | location_id: location_id}
    end)
  end

  defp update_npc_location(npcs, npc_id, %{location_id: location_id}) do
    Map.update(npcs, npc_id, nil, &update_existing_npc_location(&1, location_id))
    |> Map.reject(fn {_id, npc} -> is_nil(npc) end)
  end

  defp update_existing_npc_location(%NPC{} = npc, location_id),
    do: %{npc | location_id: location_id}

  defp update_existing_npc_location(nil, _location_id), do: nil

  defp append_event(session, event) do
    %{session | events: session.events ++ [event]}
  end
end
