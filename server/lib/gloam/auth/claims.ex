defmodule Gloam.Auth.Claims do
  @moduledoc """
  Authorized identity and scopes extracted from a Gloam bearer token.
  """

  @type scope :: :session_read | :command_write | :events_stream | :admin_inspect

  @type t :: %__MODULE__{
          session_id: String.t(),
          player_id: String.t(),
          scopes: MapSet.t(scope()),
          expires_at: non_neg_integer(),
          jti: String.t()
        }

  defstruct [:session_id, :player_id, :scopes, :expires_at, :jti]
end
