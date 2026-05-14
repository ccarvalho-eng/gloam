defmodule Gloam.Rules.Engine do
  @moduledoc """
  Deterministic command validation and event planning.
  """

  alias Gloam.Commands.Command
  alias Gloam.Events.Event
  alias Gloam.Rules.Error
  alias Gloam.Runtime.Session
  alias Gloam.World.Calendar

  @type plan :: [Event.t()]

  @spec plan(Session.t(), Command.t()) :: {:ok, plan()} | {:error, Error.t()}
  def plan(%Session{} = session, %Command{session_id: session_id})
      when session_id != session.id do
    {:error, Error.new(:session_mismatch, "Command session does not match current session")}
  end

  def plan(%Session{} = session, %Command{actor_id: actor_id})
      when actor_id != session.player.id do
    {:error, Error.new(:actor_mismatch, "Command actor is not allowed for this session")}
  end

  def plan(%Session{} = session, %Command{type: :travel} = command) do
    current_location = Map.fetch!(session.world.locations, session.player.location_id)
    target_location = Map.get(session.world.locations, command.target_id)

    plan_travel(session, command, current_location, target_location)
  end

  def plan(%Session{} = session, %Command{type: :wait} = command) do
    minutes = Map.get(command.params, :minutes, 60)

    with :ok <- validate_wait_minutes(minutes),
         {:ok, calendar, facts} <- Calendar.advance(session.world.calendar, minutes) do
      {:ok, [calendar_event(session, command, calendar, facts, minutes)]}
    end
  end

  def plan(%Session{} = session, %Command{type: type} = command)
      when type in [:look, :inspect, :talk] do
    {:ok, [simple_event(session, command)]}
  end

  def plan(_session, %Command{}) do
    {:error, Error.new(:unknown_command, "Command type is not supported")}
  end

  defp plan_travel(_session, _command, _current_location, nil) do
    {:error, Error.new(:unknown_location, "Target location does not exist")}
  end

  defp plan_travel(session, command, current_location, target_location) do
    if target_location.id in current_location.exits do
      {:ok, [travel_event(session, command, target_location.id)]}
    else
      {:error, Error.new(:invalid_exit, "Target location is not reachable from current location")}
    end
  end

  defp validate_wait_minutes(minutes)
       when is_integer(minutes) and minutes > 0 and minutes <= 1_440,
       do: :ok

  defp validate_wait_minutes(_minutes) do
    {:error,
     Error.new(:invalid_wait_duration, "Wait duration must be between 1 and 1440 minutes")}
  end

  defp travel_event(session, command, location_id) do
    Event.new!(%{
      session_id: session.id,
      type: :player_moved,
      actor_id: command.actor_id,
      subject_id: location_id,
      correlation_id: command.id,
      data: %{location_id: location_id}
    })
  end

  defp calendar_event(session, command, calendar, facts, minutes) do
    Event.new!(%{
      session_id: session.id,
      type: :calendar_advanced,
      actor_id: command.actor_id,
      subject_id: session.world.id,
      correlation_id: command.id,
      data: %{calendar: calendar, facts: facts, minutes: minutes}
    })
  end

  defp simple_event(session, command) do
    Event.new!(%{
      session_id: session.id,
      type: command.type,
      actor_id: command.actor_id,
      subject_id: command.target_id,
      correlation_id: command.id,
      data: %{}
    })
  end
end
