defmodule Gloam.Auth.Authorizer do
  @moduledoc """
  Authorization checks for commands and session access.
  """

  alias Gloam.Auth.{Claims, Error, Token}
  alias Gloam.Commands.Command

  @spec authorize_command(Claims.t(), Command.t()) :: :ok | {:error, Error.t()}
  def authorize_command(%Claims{} = claims, %Command{} = command) do
    with :ok <- Token.require_scope(claims, :command_write),
         :ok <- require_session(claims, command),
         :ok <- require_actor(claims, command) do
      :ok
    end
  end

  defp require_session(%Claims{session_id: session_id}, %Command{session_id: session_id}), do: :ok

  defp require_session(%Claims{}, %Command{}) do
    {:error, Error.new(:session_mismatch, "Token session does not match command session")}
  end

  defp require_actor(%Claims{player_id: player_id}, %Command{actor_id: player_id}), do: :ok

  defp require_actor(%Claims{}, %Command{}) do
    {:error, Error.new(:actor_mismatch, "Token player does not match command actor")}
  end
end
