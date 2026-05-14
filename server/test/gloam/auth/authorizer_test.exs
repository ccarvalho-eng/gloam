defmodule Gloam.Auth.AuthorizerTest do
  use ExUnit.Case, async: true

  alias Gloam.Auth.{Authorizer, Claims}
  alias Gloam.Commands.Command

  test "authorizes a command when session, actor, and scope match" do
    claims = claims(session_id: "session-1", player_id: "player", scopes: [:command_write])
    command = command(session_id: "session-1", actor_id: "player")

    assert :ok = Authorizer.authorize_command(claims, command)
  end

  test "rejects command scope mismatch" do
    claims = claims(session_id: "session-1", player_id: "player", scopes: [:session_read])
    command = command(session_id: "session-1", actor_id: "player")

    assert {:error, error} = Authorizer.authorize_command(claims, command)
    assert error.code == :missing_scope
  end

  test "rejects session mismatch" do
    claims = claims(session_id: "session-1", player_id: "player", scopes: [:command_write])
    command = command(session_id: "session-2", actor_id: "player")

    assert {:error, error} = Authorizer.authorize_command(claims, command)
    assert error.code == :session_mismatch
  end

  test "rejects actor mismatch" do
    claims = claims(session_id: "session-1", player_id: "player", scopes: [:command_write])
    command = command(session_id: "session-1", actor_id: "other")

    assert {:error, error} = Authorizer.authorize_command(claims, command)
    assert error.code == :actor_mismatch
  end

  defp claims(attrs) do
    %Claims{
      session_id: Keyword.fetch!(attrs, :session_id),
      player_id: Keyword.fetch!(attrs, :player_id),
      scopes: attrs |> Keyword.fetch!(:scopes) |> MapSet.new(),
      expires_at: 10_000,
      jti: "jti"
    }
  end

  defp command(attrs) do
    Command.new!(%{
      id: "cmd-1",
      session_id: Keyword.fetch!(attrs, :session_id),
      actor_id: Keyword.fetch!(attrs, :actor_id),
      type: :wait,
      target_id: nil,
      params: %{minutes: 1},
      source: :player
    })
  end
end
