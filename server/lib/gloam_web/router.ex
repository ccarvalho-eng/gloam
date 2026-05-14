defmodule GloamWeb.Router do
  @moduledoc """
  HTTP API for Gloam clients.
  """

  use Plug.Router

  alias Gloam.Auth.{Authorizer, Claims, Error, Token}
  alias Gloam.Runtime.{SessionServer, Sessions}
  alias Gloam.Transport.{CommandJSON, MessageJSON}

  @id_pattern ~r/\A[A-Za-z0-9_-]+\z/
  @max_id_bytes 128

  plug(Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason
  )

  plug(:match)
  plug(:dispatch)

  get "/" do
    json(conn, %{
      "name" => "Gloam",
      "status" => "ok",
      "endpoints" => %{
        "create_session" => "POST /api/sessions",
        "snapshot" => "GET /api/sessions/:id/snapshot",
        "command" => "POST /api/sessions/:id/commands",
        "health" => "GET /health"
      }
    })
  end

  get "/health" do
    json(conn, %{"status" => "ok"})
  end

  post "/api/sessions" do
    with {:ok, attrs} <- create_session_attrs(conn.body_params),
         {:ok, pid} <- Sessions.get_or_start(attrs.session_id),
         {:ok, token} <- mint_session_token(attrs.session_id, attrs.player_id) do
      snapshot = SessionServer.snapshot(pid)

      conn
      |> put_status(201)
      |> json(%{
        "session_id" => attrs.session_id,
        "token" => token,
        "snapshot" => MessageJSON.snapshot(snapshot)
      })
    else
      {:error, %Error{} = error} -> send_create_session_error(conn, error)
      {:error, error} -> send_error(conn, 500, error)
    end
  end

  get "/api/sessions/:session_id/snapshot" do
    with {:ok, claims} <- authenticate(conn),
         :ok <- authorize_session_read(claims, session_id),
         {:ok, pid} <- Sessions.get_or_start(session_id) do
      json(conn, %{"snapshot" => MessageJSON.snapshot(SessionServer.snapshot(pid))})
    else
      {:error, %Error{} = error} -> send_auth_error(conn, error)
      {:error, error} -> send_error(conn, 500, error)
    end
  end

  post "/api/sessions/:session_id/commands" do
    with {:ok, claims} <- authenticate(conn),
         {:ok, command} <- CommandJSON.decode(conn.body_params),
         :ok <- authorize_command_path(session_id, command),
         :ok <- Authorizer.authorize_command(claims, command),
         {:ok, pid} <- Sessions.get_or_start(session_id) do
      respond_to_command(conn, SessionServer.submit_command(pid, command))
    else
      {:error, %Gloam.Transport.Error{} = error} -> send_transport_error(conn, error)
      {:error, %Error{} = error} -> send_auth_error(conn, error)
      {:error, error} -> send_error(conn, 500, error)
    end
  end

  match _ do
    send_error(conn, 404, %{code: :not_found, message: "Route not found", details: %{}})
  end

  defp respond_to_command(conn, {:ok, events}) do
    conn
    |> put_status(202)
    |> json(%{
      "status" => "accepted",
      "events" => Enum.map(events, &MessageJSON.event/1)
    })
  end

  defp respond_to_command(conn, {:error, error, events}) do
    conn
    |> put_status(422)
    |> json(%{
      "status" => "rejected",
      "error" => error_json(error),
      "events" => Enum.map(events, &MessageJSON.event/1)
    })
  end

  defp create_session_attrs(params) do
    session_id = Map.get(params, "session_id", new_session_id())
    player_id = Map.get(params, "player_id", "player")

    with :ok <- validate_create_id(session_id, :invalid_session_id, "Session id is invalid"),
         :ok <- validate_create_id(player_id, :invalid_player_id, "Player id is invalid") do
      {:ok, %{session_id: session_id, player_id: player_id}}
    end
  end

  defp validate_create_id(value, code, message)
       when is_binary(value) and byte_size(value) in 1..@max_id_bytes do
    if Regex.match?(@id_pattern, value) do
      :ok
    else
      {:error, Error.new(code, message)}
    end
  end

  defp validate_create_id(_value, code, message) do
    {:error, Error.new(code, message)}
  end

  defp authenticate(conn) do
    conn
    |> get_req_header("authorization")
    |> bearer_token()
    |> validate_bearer_token()
  end

  defp bearer_token(["Bearer " <> token]), do: {:ok, token}

  defp bearer_token(_headers),
    do: {:error, Error.new(:missing_authorization, "Authorization header is required")}

  defp validate_bearer_token({:ok, token}) do
    Token.validate(token, secret: auth_secret())
  end

  defp validate_bearer_token({:error, error}), do: {:error, error}

  defp authorize_session_read(%Claims{session_id: session_id} = claims, session_id) do
    Token.require_scope(claims, :session_read)
  end

  defp authorize_session_read(%Claims{}, _session_id) do
    {:error, Error.new(:session_mismatch, "Token session does not match request session")}
  end

  defp authorize_command_path(session_id, %{session_id: session_id}), do: :ok

  defp authorize_command_path(_session_id, _command) do
    {:error, Error.new(:session_mismatch, "Command session does not match request session")}
  end

  defp mint_session_token(session_id, player_id) do
    Token.mint(%{
      session_id: session_id,
      player_id: player_id,
      scopes: [:session_read, :command_write, :events_stream],
      ttl_seconds: 3_600,
      secret: auth_secret()
    })
  end

  defp auth_secret do
    Application.get_env(:gloam, :auth_secret, "local-development-gloam-secret")
  end

  defp send_transport_error(conn, error) do
    send_error(conn, 400, error)
  end

  defp send_create_session_error(conn, error) do
    send_error(conn, 400, error)
  end

  defp send_auth_error(conn, %Error{code: :missing_authorization} = error) do
    send_error(conn, 401, error)
  end

  defp send_auth_error(conn, %Error{code: :token_expired} = error) do
    send_error(conn, 401, error)
  end

  defp send_auth_error(conn, error) do
    send_error(conn, 403, error)
  end

  defp send_error(conn, status, error) do
    conn
    |> put_status(status)
    |> json(%{"error" => error_json(error)})
  end

  defp error_json(%{code: code, message: message, details: details}) do
    %{
      "code" => to_string(code),
      "message" => message,
      "details" => stringify_details(details)
    }
  end

  defp stringify_details(details) when is_map(details) do
    Map.new(details, fn {key, value} -> {to_string(key), value} end)
  end

  defp json(conn, payload) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(conn.status || 200, Jason.encode!(payload))
  end

  defp new_session_id do
    "session-" <> Base.url_encode64(:crypto.strong_rand_bytes(12), padding: false)
  end
end
