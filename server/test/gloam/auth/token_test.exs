defmodule Gloam.Auth.TokenTest do
  use ExUnit.Case, async: true

  alias Gloam.Auth.Token

  @secret "test-secret-that-is-long-enough"

  test "mints and validates a scoped session token" do
    {:ok, token} =
      Token.mint(%{
        session_id: "session-1",
        player_id: "player",
        scopes: [:session_read, :command_write],
        ttl_seconds: 60,
        secret: @secret,
        now: 1_000
      })

    assert {:ok, claims} = Token.validate(token, secret: @secret, now: 1_010)
    assert claims.session_id == "session-1"
    assert claims.player_id == "player"
    assert claims.scopes == MapSet.new([:session_read, :command_write])
    assert is_binary(claims.jti)
  end

  test "rejects expired tokens" do
    {:ok, token} =
      Token.mint(%{
        session_id: "session-1",
        player_id: "player",
        scopes: [:session_read],
        ttl_seconds: 10,
        secret: @secret,
        now: 1_000
      })

    assert {:error, error} = Token.validate(token, secret: @secret, now: 1_011)
    assert error.code == :token_expired
  end

  test "rejects tampered tokens" do
    {:ok, token} =
      Token.mint(%{
        session_id: "session-1",
        player_id: "player",
        scopes: [:session_read],
        ttl_seconds: 60,
        secret: @secret,
        now: 1_000
      })

    tampered = token <> "x"

    assert {:error, error} = Token.validate(tampered, secret: @secret, now: 1_001)
    assert error.code == :invalid_signature
  end

  test "rejects missing scopes" do
    {:ok, token} =
      Token.mint(%{
        session_id: "session-1",
        player_id: "player",
        scopes: [:session_read],
        ttl_seconds: 60,
        secret: @secret,
        now: 1_000
      })

    assert {:ok, claims} = Token.validate(token, secret: @secret, now: 1_001)
    assert {:error, error} = Token.require_scope(claims, :command_write)
    assert error.code == :missing_scope
  end
end
