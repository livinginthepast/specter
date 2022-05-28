defmodule Specter.Native do
  @moduledoc false
  # This module is private, but function docs are provided for developers reading
  # the code.
  use Rustler, otp_app: :specter, crate: :specter_nif

  @opaque t() :: reference()
  @type peer_conn_t() :: Specter.PeerConnection.t()

  @doc """
  Initialize the NIF with RTC configuration, registering the current
  process for callbacks.
  """
  @spec init(Specter.init_options()) :: {:ok, t()} | {:error, term()}
  def init(args \\ []) do
    args = default_config(args)
    __init__(Enum.into(args, %{}))
  end

  @doc """
  Asynchronously adds the candidate to the given RTCPeerConnection.
  Sends back `{:ok, _uuid, :add_ice_candidate}` when successful.
  """
  @spec add_ice_candidate(t(), peer_conn_t(), Specter.PeerConnection.ice_candidate_t()) ::
          :ok | {:error, term()}
  def add_ice_candidate(_ref, _pc, _candidate), do: error()

  @doc """
  Adds track to peer connection.

  Sends back newly created rtp sender UUID.
  """
  @spec add_track(t(), peer_conn_t(), Specter.TrackLocalStaticSample.t()) ::
          :ok | {:error, term()}
  def add_track(_ref, _pc, _track), do: error()

  @doc """
  Closes an RTCPeerConnection represented by the given UUID.
  """
  @spec close_peer_connection(t(), peer_conn_t()) :: :ok | {:error, term()}
  def close_peer_connection(_ref, _pc), do: error()

  @doc """
  Create an answer from an RTCPeerConnection that has been given a remote description.
  """
  @spec create_answer(t(), peer_conn_t(), boolean) :: :ok | {:error, term()}
  def create_answer(_ref, _pc, _vad), do: error()

  @doc """
  Add a data channel to an RTCPeerConnection.
  """
  @spec create_data_channel(t(), peer_conn_t(), String.t()) ::
          :ok | {:error, term()}
  def create_data_channel(_ref, _pc, _label), do: error()

  @doc """
  Create an offer from an RTCPeerConnection.
  """
  @spec create_offer(t(), peer_conn_t(), bool(), bool()) :: :ok | {:error, term()}
  def create_offer(_ref, _pc, _vad, _ice_restart), do: error()

  @doc """
  Given an initialized NIF, get the current config back out into Elixir.

  - https://github.com/webrtc-rs/webrtc/blob/master/src/peer_connection/configuration.rs
  """
  @spec config(t()) :: {:ok, Specter.Config.t()} | {:error, term()}
  def config(_ref), do: error()

  @doc """
  Sends back state of peer connection.
  """
  @spec connection_state(t(), peer_conn_t()) :: :ok | {:error, term()}
  def connection_state(_ref, _pc), do: error()

  @doc """
  Sends back the current session description. Will be nil until the peer connection successfully
  negotiates ICE, even if an offer or answer has been set as the local description.
  """
  @spec current_local_description(t(), peer_conn_t()) :: :ok | {:error, term()}
  def current_local_description(_ref, _pc), do: error()

  @doc """
  Sends back the current remote session description. Will be nil until the peer connection successfully
  negotiates ICE, even if an offer or answer has been set as the remote description.
  """
  @spec current_remote_description(t(), peer_conn_t()) :: :ok | {:error, term()}
  def current_remote_description(_ref, _pc), do: error()

  @doc """
  Get the current stats of a peer connection.
  """
  @spec get_stats(t(), peer_conn_t()) :: :ok | {:error, term()}
  def get_stats(_ref, _pc), do: error()

  @doc """
  Sends back state of ICE connection.
  """
  @spec ice_connection_state(t(), peer_conn_t()) :: :ok | {:error, term()}
  def ice_connection_state(_ref, _pc), do: error()

  @doc """
  Sends back state of ICE gathering process.
  """
  @spec ice_gathering_state(t(), peer_conn_t()) :: :ok | {:error, term()}
  def ice_gathering_state(_ref, _pc), do: error()

  @doc """
  Sends back the pending or current session description, depending on the state of the connection.
  """
  @spec local_description(t(), peer_conn_t()) :: :ok | {:error, term()}
  def local_description(_ref, _pc), do: error()

  @doc """
  Checks whether the UUID representing a MediaEngine points to an initialized
  MediaEngine that has not been moved into a context owned by some other resource.
  """
  @spec media_engine_exists(t(), Specter.media_engine_t()) :: {:ok, boolean()} | {:error, term()}
  def media_engine_exists(_ref, _media_engine), do: error()

  @doc """
  A media engine with default codecs configured.

  - https://github.com/webrtc-rs/webrtc/blob/master/src/api/media_engine/mod.rs
  """
  @spec new_media_engine(t()) :: {:ok, Specter.media_engine_t()} | {:error, term()}
  def new_media_engine(_ref), do: error()

  @doc """
  An RTCPeerConnection.

  - https://github.com/webrtc-rs/webrtc/blob/master/src/peer_connection/mod.rs
  """
  @spec new_peer_connection(t(), Specter.api_t()) ::
          {:ok, peer_conn_t()} | {:error, term()}
  def new_peer_connection(_ref, _api), do: error()

  @doc """
  Creates an intercepter registry. This is a user configurable RTP/RTCP pipeline,
  and provides features such as NACKs and RTCP Reports.

  A registry must be created for each peer connection.

  - https://github.com/webrtc-rs/webrtc/blob/master/src/api/interceptor_registry/mod.rs
  """
  @spec new_registry(t(), Specter.media_engine_t()) ::
          {:ok, Specter.registry_t()} | {:error, term()}
  def new_registry(_ref, _media_engine), do: error()

  @doc """
  Creates an API.

  - https://github.com/webrtc-rs/webrtc/blob/master/src/api/mod.rs
  """
  @spec new_api(t(), Specter.media_engine_t(), Specter.registry_t()) ::
          {:ok, Specter.api_t()} | {:error, term()}
  def new_api(_ref, _media_engine, _registry), do: error()

  @doc """
  Creates new TrackLocalStaticSample.

  - https://github.com/webrtc-rs/webrtc/blob/master/src/track/track_local/track_local_static_sample.rs
  """
  @spec new_track_local_static_sample(t(), Specter.RtpCodecCapability.t(), String.t(), String.t()) ::
          {:ok, Specter.TrackLocalStaticSample.t()} | {:error, term()}
  def new_track_local_static_sample(_ref, _codec, _id, _stream_id), do: error()

  @doc """
  Checks whether the UUID representing an RTCPeerConnection points to an initialized
  instance.
  """
  @spec peer_connection_exists(t(), peer_conn_t()) ::
          {:ok, boolean()} | {:error, term()}
  def peer_connection_exists(_ref, _pc), do: error()

  @doc """
  Sends back the pending session description. May be nil after the peer connection successfully
  negotiates its connection.
  """
  @spec pending_local_description(t(), peer_conn_t()) :: :ok | {:error, term()}
  def pending_local_description(_ref, _pc), do: error()

  @doc """
  Sends back the pending remote session description. May be nil after the peer connection successfully
  negotiates its connection.
  """
  @spec pending_remote_description(t(), peer_conn_t()) :: :ok | {:error, term()}
  def pending_remote_description(_ref, _pc), do: error()

  @doc """
  Reads H264 file and writes it to the track.
  """
  @spec play_from_file_h264(t(), Specter.TrackLocalStaticSample.t(), Path.t()) ::
          :ok | {:error, term()}
  def play_from_file_h264(_ref, _track, _path), do: error()

  @doc """
  Checks whether the UUID representing a Registry points to an initialized
  Registry that has not been moved into a context owned by some other resource.
  """
  @spec registry_exists(t(), Specter.registry_t()) :: {:ok, boolean()} | {:error, term()}
  def registry_exists(_ref, _registry), do: error()

  @doc """
  Sends back the pending or current remote session description, depending on the state of the connection.
  """
  @spec remote_description(t(), peer_conn_t()) :: :ok | {:error, term()}
  def remote_description(_ref, _pc), do: error()

  @doc """
  Given a UUID representing an RTCPeerConnection and an offer or an answer from that same
  peer connection, set it as the local session description.
  """
  @spec set_local_description(t(), peer_conn_t(), Specter.PeerConnection.session_description_t()) ::
          :ok | {:error, term()}
  def set_local_description(_ref, _pc, _desc), do: error()

  @doc """
  Given a UUID representing an RTCPeerConnection and an offer from that peer connection or an
  answer from a different peer connection, set it on the peer connection as the remote session
  description.
  """
  @spec set_remote_description(t(), peer_conn_t(), Specter.PeerConnection.session_description_t()) ::
          :ok | {:error, term()}
  def set_remote_description(_ref, _pc, _desc), do: error()

  @doc """
  Sends back state of sesion parameters negotiation.
  """
  @spec signaling_state(t(), peer_conn_t()) :: :ok | {:error, term()}
  def signaling_state(_ref, _pc), do: error()

  ##
  ## PRIVATE
  ##

  @spec __init__(Specter.init_options()) :: {:ok, t()} | {:error, term()}
  defp __init__(_args), do: error()

  defp default_config(args),
    do: Keyword.put_new(args, :ice_servers, Application.get_env(:specter, :default_ice_servers))

  defp error, do: :erlang.nif_error(:nif_not_loaded)
end
