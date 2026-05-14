defmodule GloamWeb.RouterTest do
  use ExUnit.Case, async: false

  import Plug.Conn
  import Plug.Test

  alias Gloam.Storage.EventStore
  alias GloamWeb.Router

  @opts Router.init([])

  setup do
    storage_path =
      Path.join(
        System.tmp_dir!(),
        "gloam-router-#{System.os_time(:nanosecond)}-#{System.unique_integer([:positive])}"
      )

    previous_storage = Application.get_env(:gloam, :storage_path)
    previous_secret = Application.get_env(:gloam, :auth_secret)

    Application.put_env(:gloam, :storage_path, storage_path)
    Application.put_env(:gloam, :auth_secret, "router-test-secret")

    on_exit(fn ->
      restore_env(:storage_path, previous_storage)
      restore_env(:auth_secret, previous_secret)
      File.rm_rf(storage_path)
    end)

    %{storage_path: storage_path}
  end

  test "creates a session with a bearer token and snapshot" do
    conn =
      :post
      |> conn("/api/sessions", Jason.encode!(%{"player_id" => "player"}))
      |> put_req_header("content-type", "application/json")
      |> Router.call(@opts)

    assert conn.status == 201

    body = Jason.decode!(conn.resp_body)

    assert body["session_id"]
    assert body["token"]
    assert body["snapshot"]["type"] == "snapshot"
    assert body["snapshot"]["calendar"]["season"] == "emberwake"
  end

  test "serves session creation through a supervised Bandit listener" do
    port = open_port()
    start_supervised!({Bandit, plug: Router, ip: :loopback, port: port, startup_log: false})

    response =
      Req.post!("http://127.0.0.1:#{port}/api/sessions",
        json: %{"player_id" => "player"}
      )

    assert response.status == 201
    assert response.body["token"]
    assert response.body["snapshot"]["type"] == "snapshot"
  end

  test "returns an authorized snapshot" do
    created = create_session()

    conn =
      :get
      |> conn("/api/sessions/#{created["session_id"]}/snapshot")
      |> put_auth(created["token"])
      |> Router.call(@opts)

    assert conn.status == 200
    assert Jason.decode!(conn.resp_body)["snapshot"]["session_id"] == created["session_id"]
  end

  test "submits an authorized command and persists resulting events", %{
    storage_path: storage_path
  } do
    created = create_session()

    command = %{
      "id" => "cmd-1",
      "session_id" => created["session_id"],
      "actor_id" => "player",
      "type" => "travel",
      "target_id" => "blacksmith",
      "params" => %{},
      "source" => "player"
    }

    conn =
      :post
      |> conn("/api/sessions/#{created["session_id"]}/commands", Jason.encode!(command))
      |> put_req_header("content-type", "application/json")
      |> put_auth(created["token"])
      |> Router.call(@opts)

    assert conn.status == 202

    body = Jason.decode!(conn.resp_body)

    assert body["status"] == "accepted"
    assert body["events"] |> List.first() |> get_in(["event", "type"]) == "player_moved"

    assert {:ok, persisted} = EventStore.load(storage_path, created["session_id"])
    assert Enum.map(persisted, & &1.type) == [:session_started, :player_moved]
  end

  test "rejects command requests for a different session" do
    created = create_session()
    other = create_session()

    command = %{
      "id" => "cmd-1",
      "session_id" => other["session_id"],
      "actor_id" => "player",
      "type" => "travel",
      "target_id" => "blacksmith",
      "params" => %{},
      "source" => "player"
    }

    conn =
      :post
      |> conn("/api/sessions/#{created["session_id"]}/commands", Jason.encode!(command))
      |> put_req_header("content-type", "application/json")
      |> put_auth(created["token"])
      |> Router.call(@opts)

    assert conn.status == 403
    assert Jason.decode!(conn.resp_body)["error"]["code"] == "session_mismatch"
  end

  test "rejects command requests for a different actor" do
    created = create_session()

    command = %{
      "id" => "cmd-1",
      "session_id" => created["session_id"],
      "actor_id" => "intruder",
      "type" => "look",
      "target_id" => nil,
      "params" => %{},
      "source" => "player"
    }

    conn =
      :post
      |> conn("/api/sessions/#{created["session_id"]}/commands", Jason.encode!(command))
      |> put_req_header("content-type", "application/json")
      |> put_auth(created["token"])
      |> Router.call(@opts)

    assert conn.status == 403
    assert Jason.decode!(conn.resp_body)["error"]["code"] == "actor_mismatch"
  end

  test "rejects invalid create session params" do
    conn =
      :post
      |> conn("/api/sessions", Jason.encode!(%{"player_id" => 42}))
      |> put_req_header("content-type", "application/json")
      |> Router.call(@opts)

    assert conn.status == 400
    assert Jason.decode!(conn.resp_body)["error"]["code"] == "invalid_player_id"
  end

  test "rejects unsafe create session ids" do
    conn =
      :post
      |> conn("/api/sessions", Jason.encode!(%{"session_id" => "../outside"}))
      |> put_req_header("content-type", "application/json")
      |> Router.call(@opts)

    assert conn.status == 400
    assert Jason.decode!(conn.resp_body)["error"]["code"] == "invalid_session_id"
  end

  test "rejects unauthorized command requests" do
    created = create_session()

    conn =
      :post
      |> conn("/api/sessions/#{created["session_id"]}/commands", "{}")
      |> put_req_header("content-type", "application/json")
      |> Router.call(@opts)

    assert conn.status == 401
    assert Jason.decode!(conn.resp_body)["error"]["code"] == "missing_authorization"
  end

  defp create_session do
    conn =
      :post
      |> conn("/api/sessions", Jason.encode!(%{"player_id" => "player"}))
      |> put_req_header("content-type", "application/json")
      |> Router.call(@opts)

    Jason.decode!(conn.resp_body)
  end

  defp put_auth(conn, token) do
    put_req_header(conn, "authorization", "Bearer " <> token)
  end

  defp open_port do
    {:ok, socket} = :gen_tcp.listen(0, [:binary, active: false])
    {:ok, port} = :inet.port(socket)
    :ok = :gen_tcp.close(socket)
    port
  end

  defp restore_env(key, nil), do: Application.delete_env(:gloam, key)
  defp restore_env(key, value), do: Application.put_env(:gloam, key, value)
end
