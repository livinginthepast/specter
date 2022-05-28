defmodule Specter.PeerConnection do
  @moduledoc """
  Represents an RTCPeerConnection managed in the NIF. A running Specter instance may
  have 0 or more peer connections at any time.

  Users of Specter might choose between different topologies based on their use cases:
  a Specter might be initialized per connection, and signaling messages passed between
  different instances of the NIF; a Specter may be initialized per "room," and all peer
  connections for that room created within the single NIF instance; a "room" may be split
  across Erlang nodes, with tracks forwarded between the nodes.
  """

  alias Specter.Native

  @typedoc """
  `t:Specter.PeerConnection.t/0` represents an instantiated RTCPeerConnection managed in the NIF.
  """
  @opaque t() :: String.t()

  @typedoc """
  Options for creating a webrtc answer. Values default to false.
  """
  @type answer_options_t() :: [] | [voice_activity_detection: bool]

  @typedoc """
  Options for creating a webrtc offer. Values default to false.
  """
  @type offer_options_t() :: [] | [voice_activity_detection: bool, ice_restart: bool]

  @typedoc """
  The type of an SDP message, either an `:offer` or an `:answer`.
  """
  @type sdp_type_t() :: :offer | :answer

  @typedoc """
  A UTF-8 encoded string encapsulating either an offer or an answer.
  """
  @type sdp_t() :: String.t()

  @typedoc """
  A UTF-8 encoded string encapsulating an Offer or an Answer in JSON. The keys are as
  follows:

  | key    | type |
  | ------ | ---- |
  | `type` | `offer`, `answer` |
  | `sdp`  | `sdp_t() |
  """
  @type session_description_t() :: String.t()

  @typedoc """
  An ICE candidate as JSON.
  """
  @type ice_candidate_t() :: String.t()

  @typedoc """
  Possible states of ICE connection.
  """
  @type ice_connection_state_t() ::
          :unspecified
          | :new
          | :checking
          | :connected
          | :completed
          | :disconnected
          | :failed
          | :closed

  @typedoc """
  Message sent as a result of a call to `ice_connection_state/2`.
  """
  @type ice_connection_state_msg_t() ::
          {:ice_connection_state, t(), ice_connection_state_t()}

  @typedoc """
  Possible states of ICE gathering process.
  """
  @type ice_gathering_state_t() :: :complete | :gathering | :new | :unspecified

  @typedoc """
  Message sent as a result of a call to `ice_gathering_state/2`.
  """
  @type ice_gathering_state_msg_t() ::
          {:ice_gathering_state, t(), ice_connection_state_t()}

  @typedoc """
  Possible states of session parameters negotiation.
  """
  @type signaling_state_t() ::
          :closed
          | :have_local_offer
          | :have_local_pranswer
          | :have_remote_offer
          | :have_remote_pranswer
          | :stable
          | :unspecified

  @typedoc """
  Message sent as a result of a call to `signaling_state/2`.
  """
  @type signaling_state_msg_t() :: {:signaling_state, t(), signaling_state_t()}

  @typedoc """
  Possible states of peer connection.
  """
  @type connection_state_t() ::
          :closed | :connected | :connecting | :disconnected | :failed | :new | :unspecified

  @typedoc """
  Message sent as a result of a call to `connection_state/2`.
  """
  @type connection_state_msg_t() :: {:connection_state, t(), connection_state_t()}

  @typedoc """
  Message sent as a result of a call to `add_track/3`.
  """
  @type rtp_sender_t() :: {:rtp_sender, t(), Specter.TrackLocalStaticSample.t(), String.t()}

  @doc """
  Creates a new RTCPeerConnection, using an API reference created with `new_api/3`. The
  functionality wrapped by this function is async, so `:ok` is returned immediately.
  Callers should listen for the `{:peer_connection_ready, peer_connection_t()}` message
  to receive the results of this function.

  | param     | type     | default |
  | --------- | -------- | ------- |
  | `specter` | `t()`    | |
  | `api`     | `opaque` | |

  ## Usage

      iex> {:ok, specter} = Specter.init(ice_servers: ["stun:stun.l.google.com:19302"])
      iex> {:ok, media_engine} = Specter.new_media_engine(specter)
      iex> {:ok, registry} = Specter.new_registry(specter, media_engine)
      iex> {:ok, api} = Specter.new_api(specter, media_engine, registry)
      iex> {:ok, pc} = Specter.PeerConnection.new(specter, api)
      ...>
      iex> {:ok, _pc} =
      ...>     receive do
      ...>       {:peer_connection_ready, ^pc} -> {:ok, pc}
      ...>     after
      ...>       500 -> {:error, :timeout}
      ...>     end
  """
  @spec new(Specter.t(), Specter.api_t()) :: {:ok, t()} | {:error, term()}
  def new(%Specter{native: ref}, api), do: Native.new_peer_connection(ref, api)

  @doc """
  Returns true or false, depending on whether the RTCPeerConnection is initialized.

  ## Usage

      iex> {:ok, specter} = Specter.init(ice_servers: ["stun:stun.l.google.com:19302"])
      iex> {:ok, media_engine} = Specter.new_media_engine(specter)
      iex> {:ok, registry} = Specter.new_registry(specter, media_engine)
      iex> {:ok, api} = Specter.new_api(specter, media_engine, registry)
      iex> {:ok, pc} = Specter.PeerConnection.new(specter, api)
      iex> assert_receive {:peer_connection_ready, ^pc}
      iex> Specter.PeerConnection.exists?(specter, pc)
      true

      iex> {:ok, specter} = Specter.init(ice_servers: ["stun:stun.l.google.com:19302"])
      iex> Specter.PeerConnection.exists?(specter, UUID.uuid4())
      false
  """
  @spec exists?(Specter.t(), t()) :: boolean() | no_return()
  def exists?(%Specter{native: ref}, peer_connection) do
    case Native.peer_connection_exists(ref, peer_connection) do
      {:ok, value} ->
        value

      {:error, error} ->
        raise "Unable to determine whether peer connection exists:\n#{inspect(error)}"
    end
  end

  @doc """
  Closes an open instance of an RTCPeerConnection.

  ## Usage

      iex> {:ok, specter} = Specter.init(ice_servers: ["stun:stun.l.google.com:19302"])
      iex> {:ok, media_engine} = Specter.new_media_engine(specter)
      iex> {:ok, registry} = Specter.new_registry(specter, media_engine)
      iex> {:ok, api} = Specter.new_api(specter, media_engine, registry)
      iex> {:ok, pc} = Specter.PeerConnection.new(specter, api)
      iex> assert_receive {:peer_connection_ready, ^pc}
      ...>
      iex> Specter.PeerConnection.close(specter, pc)
      :ok
      iex> {:ok, _pc} =
      ...>     receive do
      ...>       {:peer_connection_closed, ^pc} -> {:ok, pc}
      ...>     after
      ...>       500 -> {:error, :timeout}
      ...>     end
      ...>
      iex> Specter.PeerConnection.exists?(specter, pc)
      false
  """
  @spec close(Specter.t(), t()) :: :ok | {:error, term()}
  def close(%Specter{native: ref}, pc), do: Native.close_peer_connection(ref, pc)

  @doc """
  Given an ICE candidate, add it to the given peer connection. Assumes trickle ICE.
  Candidates must be JSON, with the keys `candidate`, `sdp_mid`, `sdp_mline_index`, and
  `username_fragment`.
  """
  @spec add_ice_candidate(Specter.t(), t(), ice_candidate_t()) :: :ok | {:error, term()}
  def add_ice_candidate(%Specter{native: ref}, pc, candidate),
    do: Native.add_ice_candidate(ref, pc, candidate)

  @doc """
  Adds track to peer connection.

  Sends back uuid of newly created rtp sender.
  This will send message `t:rtp_sender_msg_t/0`.

  ## Usage

      iex> {:ok, specter} = Specter.init()
      iex> {:ok, media_engine} = Specter.new_media_engine(specter)
      iex> {:ok, registry} = Specter.new_registry(specter, media_engine)
      iex> {:ok, api} = Specter.new_api(specter, media_engine, registry)
      iex> {:ok, pc} = Specter.PeerConnection.new(specter, api)
      iex> assert_receive {:peer_connection_ready, ^pc}
      iex> codec = %Specter.RtpCodecCapability{mime_type: "audio"}
      iex> {:ok, track} = Specter.TrackLocalStaticSample.new(specter, codec, "audio", "specter")
      iex> :ok = Specter.PeerConnection.add_track(specter, pc, track)
      iex> assert_receive {:rtp_sender, ^pc, ^track, _rtp_sender}
      ...>
      iex> {:error, :invalid_track} = Specter.PeerConnection.add_track(specter, pc, "invalid_track")
  """
  @spec add_track(Specter.t(), t(), Specter.TrackLocalStaticSample.t()) :: :ok | {:error | term()}
  def add_track(%Specter{native: ref}, pc, track) do
    Native.add_track(ref, pc, track)
  end

  @doc """
  Sends back state of peer connection.
  This will send message `t:connection_state_msg_t/0`.
  """
  @spec connection_state(Specter.t(), t()) :: :ok | {:error, term()}
  def connection_state(%Specter{native: ref}, pc) do
    Native.connection_state(ref, pc)
  end

  @doc """
  Given an RTCPeerConnection where the remote description has been assigned via
  `set_remote_description/4`, create an answer that can be passed to another connection.

  | param             | type                 | default |
  | ----------------- | -------------------- | ------- |
  | `specter`         | `t()`                | |
  | `peer_connection` | `opaque`             | |
  | `options`         | `answer_options_t()` | voice_activity_detection: false |

  """
  @spec create_answer(Specter.t(), t(), answer_options_t()) :: :ok | {:error, term()}
  def create_answer(%Specter{native: ref}, pc, opts \\ []),
    do:
      Native.create_answer(
        ref,
        pc,
        Keyword.get(opts, :voice_activity_detection, false)
      )

  @doc """
  Creates a data channel on an RTCPeerConnection.

  Note: this can be useful when attempting to generate a valid offer, but where no media
  tracks are expected to be sent or received. Callbacks from data channels have not yet
  been implemented.
  """
  @spec create_data_channel(Specter.t(), t(), String.t()) :: :ok | {:error, term()}
  def create_data_channel(%Specter{native: ref}, pc, label),
    do: Native.create_data_channel(ref, pc, label)

  @doc """
  Given an RTCPeerConnection, create an offer that can be passed to another connection.

  | param             | type                | default |
  | ----------------- | ------------------- | ------- |
  | `specter`         | `t()`               | |
  | `peer_connection` | `opaque`            | |
  | `options`         | `offer_options_t()` | voice_activity_detection: false |
  |                   |                     | ice_restart: false |

  """
  @spec create_offer(Specter.t(), t(), offer_options_t()) :: :ok | {:error, term()}
  def create_offer(%Specter{native: ref}, pc, opts \\ []),
    do:
      Native.create_offer(
        ref,
        pc,
        Keyword.get(opts, :voice_activity_detection, false),
        Keyword.get(opts, :ice_restart, false)
      )

  @doc """
  Sends back the value of the current session description on a peer connection. This will
  send back JSON representing an offer or an answer when the peer connection has had
  `set_local_description/3` called and has successfully negotiated ICE. In all other cases,
  `nil` will be sent.

  See `pending_local_description/2` and `local_description/2`.

  ## Usage

      iex> {:ok, specter} = Specter.init()
      iex> {:ok, media_engine} = Specter.new_media_engine(specter)
      iex> {:ok, registry} = Specter.new_registry(specter, media_engine)
      iex> {:ok, api} = Specter.new_api(specter, media_engine, registry)
      iex> {:ok, pc} = Specter.PeerConnection.new(specter, api)
      iex> assert_receive {:peer_connection_ready, ^pc}
      iex> Specter.PeerConnection.current_local_description(specter, pc)
      :ok
      iex> assert_receive {:current_local_description, ^pc, nil}
  """
  @spec current_local_description(Specter.t(), t()) :: :ok | {:error, term()}
  def current_local_description(%Specter{native: ref}, pc),
    do: Native.current_local_description(ref, pc)

  @doc """
  Sends back the value of the current remote session description on a peer connection. This will
  send back JSON representing an offer or an answer when the peer connection has had
  `set_remote_description/3` called and has successfully negotiated ICE. In all other cases,
  `nil` will be sent.

  See `current_remote_description/2` and `remote_description/2`.

  ## Usage

      iex> {:ok, specter} = Specter.init()
      iex> {:ok, media_engine} = Specter.new_media_engine(specter)
      iex> {:ok, registry} = Specter.new_registry(specter, media_engine)
      iex> {:ok, api} = Specter.new_api(specter, media_engine, registry)
      iex> {:ok, pc} = Specter.PeerConnection.new(specter, api)
      iex> assert_receive {:peer_connection_ready, ^pc}
      iex> Specter.PeerConnection.current_remote_description(specter, pc)
      :ok
      iex> assert_receive {:current_remote_description, ^pc, nil}
  """
  @spec current_remote_description(Specter.t(), t()) :: :ok | {:error, term()}
  def current_remote_description(%Specter{native: ref}, pc),
    do: Native.current_remote_description(ref, pc)

  @doc """
  Sends back a JSON encoded string representing the current stats of a peer connection.

  ## Usage

      iex> {:ok, specter} = Specter.init()
      iex> {:ok, media_engine} = Specter.new_media_engine(specter)
      iex> {:ok, registry} = Specter.new_registry(specter, media_engine)
      iex> {:ok, api} = Specter.new_api(specter, media_engine, registry)
      iex> {:ok, pc} = Specter.PeerConnection.new(specter, api)
      iex> assert_receive {:peer_connection_ready, ^pc}
      ...>
      iex> Specter.PeerConnection.get_stats(specter, pc)
      :ok
      iex> assert_receive {:stats, ^pc, json}
      iex> {:ok, _stats} = Jason.decode(json)
  """
  @spec get_stats(Specter.t(), t()) :: :ok | {:error, term()}
  def get_stats(%Specter{native: ref}, pc),
    do: Native.get_stats(ref, pc)

  @doc """
  Sends back state of ICE connection for given peer connection.
  This will send message `t:ice_connection_state_msg_t/0`
  """
  @spec ice_connection_state(Specter.t(), t()) :: :ok | {:error, term()}
  def ice_connection_state(%Specter{native: ref}, pc) do
    Native.ice_connection_state(ref, pc)
  end

  @doc """
  Sends back state of ICE gathering process.
  This will send message `t:ice_gathering_state_t/0`.
  """
  @spec ice_gathering_state(Specter.t(), t()) :: :ok | {:error, term()}
  def ice_gathering_state(%Specter{native: ref}, pc) do
    Native.ice_gathering_state(ref, pc)
  end

  @doc """
  Sends back the value of the local session description on a peer connection. This will
  send back JSON representing an offer or an answer when the peer connection has had
  `set_local_description/3` called. If ICE has been successfully negotated, the current
  local description will be sent back, otherwise the caller will receive the pending
  local description.

  See `current_local_description/2` and `pending_local_description/2`.

  ## Usage

      iex> {:ok, specter} = Specter.init()
      iex> {:ok, media_engine} = Specter.new_media_engine(specter)
      iex> {:ok, registry} = Specter.new_registry(specter, media_engine)
      iex> {:ok, api} = Specter.new_api(specter, media_engine, registry)
      iex> {:ok, pc} = Specter.PeerConnection.new(specter, api)
      iex> assert_receive {:peer_connection_ready, ^pc}
      ...>
      iex> Specter.PeerConnection.local_description(specter, pc)
      :ok
      iex> assert_receive {:local_description, ^pc, nil}
      ...>
      iex> :ok = Specter.PeerConnection.create_offer(specter, pc)
      iex> assert_receive {:offer, ^pc, offer}
      iex> :ok = Specter.PeerConnection.set_local_description(specter, pc, offer)
      iex> assert_receive {:ok, ^pc, :set_local_description}
      ...>
      iex> Specter.PeerConnection.local_description(specter, pc)
      :ok
      iex> assert_receive {:local_description, ^pc, ^offer}
  """
  @spec local_description(Specter.t(), t()) :: :ok | {:error, term()}
  def local_description(%Specter{native: ref}, pc),
    do: Native.local_description(ref, pc)

  @doc """
  Sends back the value of the session description on a peer connection that is pending
  connection, or nil.

  ## Usage

      iex> {:ok, specter} = Specter.init()
      iex> {:ok, media_engine} = Specter.new_media_engine(specter)
      iex> {:ok, registry} = Specter.new_registry(specter, media_engine)
      iex> {:ok, api} = Specter.new_api(specter, media_engine, registry)
      iex> {:ok, pc} = Specter.PeerConnection.new(specter, api)
      iex> assert_receive {:peer_connection_ready, ^pc}
      ...>
      iex> Specter.PeerConnection.pending_local_description(specter, pc)
      :ok
      iex> assert_receive {:pending_local_description, ^pc, nil}
      ...>
      iex> :ok = Specter.PeerConnection.create_offer(specter, pc)
      iex> assert_receive {:offer, ^pc, offer}
      iex> :ok = Specter.PeerConnection.set_local_description(specter, pc, offer)
      iex> assert_receive {:ok, ^pc, :set_local_description}
      ...>
      iex> Specter.PeerConnection.pending_local_description(specter, pc)
      :ok
      iex> assert_receive {:pending_local_description, ^pc, ^offer}
  """
  @spec pending_local_description(Specter.t(), t()) :: :ok | {:error, term()}
  def pending_local_description(%Specter{native: ref}, pc),
    do: Native.pending_local_description(ref, pc)

  @doc """
  Sends back the value of the remote session description on a peer connection on a peer
  that is pending connection, or nil.

  See `current_remote_description/2` and `pending_remote_description/2`.

  ## Usage

      iex> {:ok, specter} = Specter.init()
      iex> {:ok, media_engine} = Specter.new_media_engine(specter)
      iex> {:ok, registry} = Specter.new_registry(specter, media_engine)
      iex> {:ok, api} = Specter.new_api(specter, media_engine, registry)
      iex> {:ok, pc_offer} = Specter.PeerConnection.new(specter, api)
      iex> assert_receive {:peer_connection_ready, ^pc_offer}
      iex> :ok = Specter.PeerConnection.create_data_channel(specter, pc_offer, "foo")
      iex> assert_receive {:data_channel_created, ^pc_offer}
      iex> :ok = Specter.PeerConnection.create_offer(specter, pc_offer)
      iex> assert_receive {:offer, ^pc_offer, offer}
      ...>
      iex> {:ok, media_engine} = Specter.new_media_engine(specter)
      iex> {:ok, registry} = Specter.new_registry(specter, media_engine)
      iex> {:ok, api} = Specter.new_api(specter, media_engine, registry)
      iex> {:ok, pc_answer} = Specter.PeerConnection.new(specter, api)
      iex> assert_receive {:peer_connection_ready, ^pc_answer}
      ...>
      iex> Specter.PeerConnection.pending_remote_description(specter, pc_answer)
      :ok
      iex> assert_receive {:pending_remote_description, ^pc_answer, nil}
      ...>
      iex> :ok = Specter.PeerConnection.set_remote_description(specter, pc_answer, offer)
      iex> assert_receive {:ok, ^pc_answer, :set_remote_description}
      ...>
      iex> Specter.PeerConnection.pending_remote_description(specter, pc_answer)
      :ok
      iex> assert_receive {:pending_remote_description, ^pc_answer, ^offer}
  """
  @spec pending_remote_description(Specter.t(), t()) :: :ok | {:error, term()}
  def pending_remote_description(%Specter{native: ref}, pc),
    do: Native.pending_remote_description(ref, pc)

  @doc """
  Sends back the value of the remote session description on a peer connection. This will
  send back JSON representing an offer or an answer when the peer connection has had
  `set_remote_description/3` called. If ICE has been successfully negotated, the current
  remote description will be sent back, otherwise the caller will receive the pending
  remote description.

  See `current_remote_description/2` and `remote_description/2`.

  ## Usage

      iex> {:ok, specter} = Specter.init()
      iex> {:ok, media_engine} = Specter.new_media_engine(specter)
      iex> {:ok, registry} = Specter.new_registry(specter, media_engine)
      iex> {:ok, api} = Specter.new_api(specter, media_engine, registry)
      iex> {:ok, pc_offer} = Specter.PeerConnection.new(specter, api)
      iex> assert_receive {:peer_connection_ready, ^pc_offer}
      iex> :ok = Specter.PeerConnection.create_data_channel(specter, pc_offer, "foo")
      iex> assert_receive {:data_channel_created, ^pc_offer}
      iex> :ok = Specter.PeerConnection.create_offer(specter, pc_offer)
      iex> assert_receive {:offer, ^pc_offer, offer}
      ...>
      iex> {:ok, media_engine} = Specter.new_media_engine(specter)
      iex> {:ok, registry} = Specter.new_registry(specter, media_engine)
      iex> {:ok, api} = Specter.new_api(specter, media_engine, registry)
      iex> {:ok, pc_answer} = Specter.PeerConnection.new(specter, api)
      iex> assert_receive {:peer_connection_ready, ^pc_answer}
      ...>
      iex> Specter.PeerConnection.remote_description(specter, pc_answer)
      :ok
      iex> assert_receive {:remote_description, ^pc_answer, nil}
      ...>
      iex> :ok = Specter.PeerConnection.set_remote_description(specter, pc_answer, offer)
      iex> assert_receive {:ok, ^pc_answer, :set_remote_description}
      ...>
      iex> Specter.PeerConnection.remote_description(specter, pc_answer)
      :ok
      iex> assert_receive {:remote_description, ^pc_answer, ^offer}
  """
  @spec remote_description(Specter.t(), t()) :: :ok | {:error, term()}
  def remote_description(%Specter{native: ref}, pc),
    do: Native.remote_description(ref, pc)

  @doc """
  Given an offer or an answer session description, sets the local description on
  a peer connection. The description should be in the form of JSON with the keys
  `type` and `sdp`.

  | param             | type                        | default |
  | ----------------- | --------------------------- | ------- |
  | `specter`         | `t:t/0`                     | |
  | `peer_connection` | `opaque`                    | |
  | `description`     | `t:session_description_t()` | |
  """
  @spec set_local_description(Specter.t(), t(), session_description_t()) ::
          :ok | {:error, term()}
  def set_local_description(%Specter{native: ref}, pc, description),
    do: Native.set_local_description(ref, pc, description)

  @doc """
  Given an offer or an answer in the form of SDP generated by a remote party, sets
  the remote description on a peer connection. Expects a session description in the
  form of JSON with the keys `type` and `sdp`.

  | param             | type                        | default |
  | ----------------- | --------------------------- | ------- |
  | `specter`         | `t:t/0`                     | |
  | `peer_connection` | `opaque`                    | |
  | `description`     | `t:session_description_t/0` | |
  """
  @spec set_remote_description(Specter.t(), t(), session_description_t()) ::
          :ok | {:error, term()}
  def set_remote_description(%Specter{native: ref}, pc, description) do
    Native.set_remote_description(ref, pc, description)
  end

  @doc """
  Sends back state of session parameters negotiation.
  This will send message `t:signaling_state_msg_t/0`.
  """
  @spec signaling_state(Specter.t(), t()) :: :ok | {:error, term()}
  def signaling_state(%Specter{native: ref}, pc) do
    Native.signaling_state(ref, pc)
  end
end
