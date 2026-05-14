defmodule Gloam.Auth.Token do
  @moduledoc """
  Opaque signed bearer tokens for starter-kit session authentication.

  Tokens are not JWTs. They are compact signed Erlang terms intended for Gloam
  clients and servers that share a configured secret.
  """

  alias Gloam.Auth.{Claims, Error}

  @type mint_attrs :: %{
          required(:session_id) => String.t(),
          required(:player_id) => String.t(),
          required(:scopes) => [Claims.scope()],
          required(:ttl_seconds) => pos_integer(),
          required(:secret) => String.t(),
          optional(:now) => non_neg_integer()
        }

  @spec mint(mint_attrs()) :: {:ok, String.t()} | {:error, Error.t()}
  def mint(attrs) when is_map(attrs) do
    with :ok <- validate_secret(attrs.secret),
         :ok <- validate_ttl(attrs.ttl_seconds),
         {:ok, claims} <- build_claims(attrs) do
      payload = encode_payload(claims)
      signature = sign(payload, attrs.secret)
      {:ok, payload <> "." <> signature}
    end
  end

  @spec validate(String.t(), keyword()) :: {:ok, Claims.t()} | {:error, Error.t()}
  def validate(token, opts) when is_binary(token) and is_list(opts) do
    secret = Keyword.fetch!(opts, :secret)
    now = Keyword.get(opts, :now, now())

    with :ok <- validate_secret(secret),
         {:ok, payload, signature} <- split_token(token),
         :ok <- verify_signature(payload, signature, secret),
         {:ok, claims} <- decode_payload(payload),
         :ok <- verify_expiry(claims, now) do
      {:ok, claims}
    end
  end

  @spec require_scope(Claims.t(), Claims.scope()) :: :ok | {:error, Error.t()}
  def require_scope(%Claims{} = claims, scope) do
    if MapSet.member?(claims.scopes, scope) do
      :ok
    else
      {:error, Error.new(:missing_scope, "Token does not include required scope")}
    end
  end

  defp build_claims(attrs) do
    {:ok,
     %Claims{
       session_id: attrs.session_id,
       player_id: attrs.player_id,
       scopes: MapSet.new(attrs.scopes),
       expires_at: Map.get(attrs, :now, now()) + attrs.ttl_seconds,
       jti: generate_jti()
     }}
  end

  defp split_token(token) do
    case String.split(token, ".", parts: 2) do
      [payload, signature] -> {:ok, payload, signature}
      _parts -> {:error, Error.new(:invalid_token, "Token is malformed")}
    end
  end

  defp verify_signature(payload, signature, secret) do
    expected = sign(payload, secret)

    if secure_compare(signature, expected) do
      :ok
    else
      {:error, Error.new(:invalid_signature, "Token signature is invalid")}
    end
  end

  defp verify_expiry(%Claims{} = claims, now) do
    if now <= claims.expires_at do
      :ok
    else
      {:error, Error.new(:token_expired, "Token has expired")}
    end
  end

  defp validate_secret(secret) when is_binary(secret) and byte_size(secret) >= 16, do: :ok

  defp validate_secret(_secret) do
    {:error, Error.new(:weak_secret, "Token secret must be at least 16 bytes")}
  end

  defp validate_ttl(ttl) when is_integer(ttl) and ttl > 0, do: :ok

  defp validate_ttl(_ttl) do
    {:error, Error.new(:invalid_ttl, "Token TTL must be positive")}
  end

  defp encode_payload(%Claims{} = claims) do
    claims
    |> :erlang.term_to_binary()
    |> Base.url_encode64(padding: false)
  end

  defp decode_payload(payload) do
    with {:ok, binary} <- Base.url_decode64(payload, padding: false),
         {:ok, claims} <- binary_to_claims(binary) do
      {:ok, claims}
    else
      :error -> {:error, Error.new(:invalid_token, "Token payload is invalid")}
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  defp binary_to_claims(binary) do
    case :erlang.binary_to_term(binary, [:safe]) do
      %Claims{} = claims -> {:ok, claims}
      _other -> {:error, Error.new(:invalid_token, "Token payload is invalid")}
    end
  rescue
    ArgumentError -> {:error, Error.new(:invalid_token, "Token payload is invalid")}
  end

  defp sign(payload, secret) do
    :crypto.mac(:hmac, :sha256, secret, payload)
    |> Base.url_encode64(padding: false)
  end

  defp secure_compare(left, right) when byte_size(left) == byte_size(right) do
    left
    |> :binary.bin_to_list()
    |> Enum.zip(:binary.bin_to_list(right))
    |> Enum.reduce(0, fn {left_byte, right_byte}, acc ->
      Bitwise.bor(acc, Bitwise.bxor(left_byte, right_byte))
    end)
    |> Kernel.==(0)
  end

  defp secure_compare(_left, _right), do: false

  defp generate_jti do
    16
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  defp now do
    System.system_time(:second)
  end
end
