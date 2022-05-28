defmodule Specter.PeerConnectionTest do
  use SpecterTest.Case
  doctest Specter.PeerConnection

  @uuid_regex ~r/\b[0-9a-f]{8}\b-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-\b[0-9a-f]{12}\b/i

  describe "add_ice_candidate" do
    setup [:initialize_specter, :init_api, :init_peer_connection]

    test "returns {:error, :not_found} when given a random api id", %{specter: specter} do
      assert {:error, :not_found} =
               Specter.PeerConnection.add_ice_candidate(specter, UUID.uuid4(), "")
    end

    test "sends error messages back to Elixir", %{specter: specter, peer_connection: pc_offer} do
      api = init_api(specter)
      pc_answer = init_peer_connection(specter, api)

      assert :ok = Specter.PeerConnection.create_data_channel(specter, pc_offer, "foo")
      assert :ok = Specter.PeerConnection.create_offer(specter, pc_offer)
      assert_receive {:offer, ^pc_offer, offer}
      assert :ok = Specter.PeerConnection.set_local_description(specter, pc_offer, offer)

      assert_receive {:ice_candidate, ^pc_offer, candidate}

      assert :ok = Specter.PeerConnection.add_ice_candidate(specter, pc_answer, candidate)
      assert_receive {:candidate_error, ^pc_answer, "remote description is not set"}
    end

    test "adds the candidate to a peer connection", %{specter: specter, peer_connection: pc_offer} do
      api = init_api(specter)
      pc_answer = init_peer_connection(specter, api)

      assert :ok = Specter.PeerConnection.create_data_channel(specter, pc_offer, "foo")
      assert_receive {:data_channel_created, ^pc_offer}
      assert :ok = Specter.PeerConnection.create_offer(specter, pc_offer)
      assert_receive {:offer, ^pc_offer, offer}
      assert :ok = Specter.PeerConnection.set_local_description(specter, pc_offer, offer)
      assert_receive {:ok, ^pc_offer, :set_local_description}

      assert :ok = Specter.PeerConnection.set_remote_description(specter, pc_answer, offer)
      assert_receive {:ok, ^pc_answer, :set_remote_description}

      assert :ok = Specter.PeerConnection.create_answer(specter, pc_answer)
      assert_receive {:answer, ^pc_answer, answer}
      assert :ok = Specter.PeerConnection.set_local_description(specter, pc_answer, answer)
      assert_receive {:ok, ^pc_answer, :set_local_description}

      assert_receive {:ice_candidate, ^pc_offer, candidate}
      assert :ok = Specter.PeerConnection.add_ice_candidate(specter, pc_answer, candidate)
      assert_receive {:ok, ^pc_answer, :add_ice_candidate}

      assert :ok = Specter.PeerConnection.set_remote_description(specter, pc_offer, answer)
      assert_receive {:ok, ^pc_offer, :set_remote_description}

      assert_receive {:ice_candidate, ^pc_answer, candidate}
      assert :ok = Specter.PeerConnection.add_ice_candidate(specter, pc_offer, candidate)
      assert_receive {:ok, ^pc_offer, :add_ice_candidate}
    end
  end

  describe "close" do
    setup [:initialize_specter, :init_api]

    test "returns {:error, :not_found} when given a random api id", %{specter: specter} do
      assert {:error, :not_found} = Specter.PeerConnection.close(specter, UUID.uuid4())
    end

    test "returns :ok, then receives a closed message", %{specter: specter, api: api} do
      assert {:ok, pc} = Specter.PeerConnection.new(specter, api)
      assert_receive {:peer_connection_ready, ^pc}

      assert :ok = Specter.PeerConnection.close(specter, pc)
      assert_receive {:peer_connection_closed, ^pc}
    end
  end

  describe "connection_state" do
    setup [:initialize_specter, :init_api, :init_peer_connection]

    test "sends `:new` just after creating a new peer connection back to elixir", %{
      specter: specter,
      peer_connection: peer_connection
    } do
      assert :ok = Specter.PeerConnection.connection_state(specter, peer_connection)
      assert_receive {:connection_state, ^peer_connection, :new}
    end
  end

  describe "create_answer" do
    setup [:initialize_specter, :init_api, :init_peer_connection]

    test "returns an error when peer connection does not exist", %{specter: specter} do
      assert {:error, :not_found} = Specter.PeerConnection.create_answer(specter, UUID.uuid4())
    end

    test "returns :ok and then sends an answer", %{
      specter: specter,
      peer_connection: peer_connection
    } do
      api = init_api(specter)
      pc_offer = init_peer_connection(specter, api)
      assert :ok = Specter.PeerConnection.create_data_channel(specter, pc_offer, "foo")
      assert_receive {:data_channel_created, ^pc_offer}
      assert :ok = Specter.PeerConnection.create_offer(specter, pc_offer)
      assert_receive {:offer, ^pc_offer, offer}

      assert :ok = Specter.PeerConnection.set_remote_description(specter, peer_connection, offer)
      assert_receive {:ok, ^peer_connection, :set_remote_description}

      assert :ok = Specter.PeerConnection.create_answer(specter, peer_connection)
      assert_receive {:answer, ^peer_connection, answer}
      assert is_binary(answer)

      assert {:ok, answer_json} = Jason.decode(answer)
      assert %{"type" => "answer", "sdp" => _sdp} = answer_json
    end
  end

  describe "create_data_channel" do
    setup [:initialize_specter, :init_api, :init_peer_connection]

    test "returns an error when peer connection does not exist", %{specter: specter} do
      assert {:error, :not_found} =
               Specter.PeerConnection.create_data_channel(specter, UUID.uuid4(), "foo")
    end

    test "sends an :ok message to elixir, and adds it to offers", %{
      specter: specter,
      peer_connection: peer_connection
    } do
      assert :ok = Specter.PeerConnection.create_offer(specter, peer_connection)
      assert_receive {:offer, ^peer_connection, offer}
      refute String.contains?(offer, "ice-ufrag")
      refute String.contains?(offer, "ice-pwd")
      refute String.contains?(offer, "webrtc-datachannel")

      assert :ok = Specter.PeerConnection.create_data_channel(specter, peer_connection, "foo")
      assert_receive {:data_channel_created, ^peer_connection}

      assert :ok = Specter.PeerConnection.create_offer(specter, peer_connection)
      assert_receive {:offer, ^peer_connection, offer}
      assert {:ok, offer_json} = Jason.decode(offer)

      assert String.contains?(offer_json["sdp"], "ice-ufrag")
      assert String.contains?(offer_json["sdp"], "ice-pwd")

      assert String.contains?(
               offer_json["sdp"],
               "m=application 9 UDP/DTLS/SCTP webrtc-datachannel"
             )
    end
  end

  describe "create_offer" do
    setup [:initialize_specter, :init_api, :init_peer_connection]

    test "returns an error when peer connection does not exist", %{specter: specter} do
      assert {:error, :not_found} = Specter.PeerConnection.create_offer(specter, UUID.uuid4())
    end

    test "returns :ok and then sends an offer json", %{
      specter: specter,
      peer_connection: peer_connection
    } do
      assert :ok = Specter.PeerConnection.create_offer(specter, peer_connection)
      assert_receive {:offer, ^peer_connection, offer}
      assert is_binary(offer)

      assert {:ok, offer_json} = Jason.decode(offer)
      assert %{"type" => "offer", "sdp" => _sdp} = offer_json
    end

    test "returns :ok with VAD", %{
      specter: specter,
      peer_connection: peer_connection
    } do
      assert :ok =
               Specter.PeerConnection.create_offer(specter, peer_connection,
                 voice_activity_detection: true
               )

      assert_receive {:offer, ^peer_connection, offer}
      assert is_binary(offer)

      # assert offer is different... somehow? maybe after more interactions are available, the generated
      # SDP will actually be different.
    end

    test "returns error with ice_restart before ICE has started", %{
      specter: specter,
      peer_connection: peer_connection
    } do
      assert :ok =
               Specter.PeerConnection.create_offer(specter, peer_connection, ice_restart: true)

      assert_receive {:offer_error, ^peer_connection, "ICEAgent does not exist"}
    end
  end

  describe "current_local_description" do
    setup [:initialize_specter, :init_api, :init_peer_connection]

    test "returns an error when peer connection does not exist", %{specter: specter} do
      assert {:error, :not_found} =
               Specter.PeerConnection.current_local_description(specter, UUID.uuid4())
    end

    test "sends the current local description back to elixir", %{
      specter: specter,
      peer_connection: pc
    } do
      assert :ok = Specter.PeerConnection.current_local_description(specter, pc)
      assert_receive {:current_local_description, ^pc, nil}

      assert :ok = Specter.PeerConnection.create_offer(specter, pc)
      assert_receive {:offer, ^pc, offer}

      assert :ok = Specter.PeerConnection.set_local_description(specter, pc, offer)
      assert_receive {:ok, ^pc, :set_local_description}

      ## asserting non-nil current desc requires successful ICE negotiation
      # assert :ok = Specter.current_local_description(specter, pc)
      # refute_receive {:current_local_description, ^pc, nil}
    end
  end

  describe "current_remote_description" do
    setup [
      :initialize_specter,
      :init_api,
      :init_peer_connection,
      :create_data_channel,
      :create_offer
    ]

    test "returns an error when peer connection does not exist", %{specter: specter} do
      assert {:error, :not_found} =
               Specter.PeerConnection.current_remote_description(specter, UUID.uuid4())
    end

    test "sends the current remote description back to elixir", %{
      specter: specter,
      offer: offer
    } do
      api = init_api(specter)
      pc = init_peer_connection(specter, api)
      assert :ok = Specter.PeerConnection.current_remote_description(specter, pc)
      assert_receive {:current_remote_description, ^pc, nil}

      assert :ok = Specter.PeerConnection.set_remote_description(specter, pc, offer)
      assert_receive {:ok, ^pc, :set_remote_description}

      ## asserting non-nil current desc requires successful ICE negotiation
      # assert :ok = Specter.current_remote_description(specter, pc)
      # refute_receive {:current_remote_description, ^pc, nil}
    end
  end

  describe "exists?" do
    setup [:initialize_specter, :init_api]

    test "is false when the peer connection does not exist", %{specter: specter} do
      refute Specter.PeerConnection.exists?(specter, UUID.uuid4())
    end

    test "is true when the peer connection exists", %{specter: specter, api: api} do
      assert {:ok, pc} = Specter.PeerConnection.new(specter, api)
      assert_receive {:peer_connection_ready, ^pc}

      assert Specter.PeerConnection.exists?(specter, pc)
    end

    test "is false after a peer connection closes", %{specter: specter, api: api} do
      assert {:ok, pc} = Specter.PeerConnection.new(specter, api)
      assert_receive {:peer_connection_ready, ^pc}

      assert Specter.PeerConnection.exists?(specter, pc)

      assert :ok = Specter.PeerConnection.close(specter, pc)
      assert_receive {:peer_connection_closed, ^pc}

      refute Specter.PeerConnection.exists?(specter, pc)
    end
  end

  describe "get_stats" do
    setup [
      :initialize_specter,
      :init_api,
      :init_peer_connection,
      :create_data_channel
    ]

    test "returns an error when peer connection does not exist", %{specter: specter} do
      assert {:error, :not_found} = Specter.PeerConnection.get_stats(specter, UUID.uuid4())
    end

    test "returns json of all stats", %{specter: specter, peer_connection: pc_offer} do
      assert :ok = Specter.PeerConnection.get_stats(specter, pc_offer)
      stats = receive_stats(pc_offer)

      assert %{
               "data_channels_accepted" => 0,
               "data_channels_closed" => 0,
               "data_channels_opened" => 0,
               "data_channels_requested" => 1,
               "type" => "peer-connection"
             } = find_stats(stats, "PeerConnection-")

      api = init_api(specter)
      pc_answer = init_peer_connection(specter, api)
      assert :ok = create_data_channel(specter, pc_answer)
      assert :ok = negotiate_connection(specter, pc_offer, pc_answer)

      assert_stats(specter, pc_offer, "PeerConn",
        data_channels_accepted: 1,
        data_channels_closed: 0,
        data_channels_opened: 1,
        data_channels_requested: 1
      )

      assert_stats(specter, pc_answer, "PeerConn",
        data_channels_accepted: 1,
        data_channels_closed: 0,
        data_channels_opened: 1,
        data_channels_requested: 1
      )

      assert :ok = Specter.PeerConnection.get_stats(specter, pc_offer)
      stats = receive_stats(pc_offer)

      assert %{
               "bytes_received" => bytes_received,
               "bytes_sent" => bytes_sent
             } = find_stats(stats, "ice_transport")

      assert bytes_received > 0
      assert bytes_sent > 0
    end
  end

  describe "ice_connection_state" do
    setup [:initialize_specter, :init_api, :init_peer_connection]

    test "sends `:new` just after creating a new peer connection back to elixir", %{
      specter: specter,
      peer_connection: peer_connection
    } do
      assert :ok = Specter.PeerConnection.ice_connection_state(specter, peer_connection)
      assert_receive {:ice_connection_state, ^peer_connection, :new}
    end
  end

  describe "ice_gathering_state" do
    setup [:initialize_specter, :init_api, :init_peer_connection]

    test "sends `:new` just after creating a new peer connection back to elixir", %{
      specter: specter,
      peer_connection: peer_connection
    } do
      assert :ok = Specter.PeerConnection.ice_gathering_state(specter, peer_connection)
      assert_receive {:ice_gathering_state, ^peer_connection, :new}
    end
  end

  describe "local_description" do
    setup [:initialize_specter, :init_api, :init_peer_connection]

    test "returns an error when peer connection does not exist", %{specter: specter} do
      assert {:error, :not_found} =
               Specter.PeerConnection.local_description(specter, UUID.uuid4())
    end

    test "sends the pending local description back to elixir before ICE finishes", %{
      specter: specter,
      peer_connection: pc
    } do
      assert :ok = Specter.PeerConnection.local_description(specter, pc)
      assert_receive {:local_description, ^pc, nil}

      assert :ok = Specter.PeerConnection.create_offer(specter, pc)
      assert_receive {:offer, ^pc, offer}

      assert :ok = Specter.PeerConnection.set_local_description(specter, pc, offer)
      assert_receive {:ok, ^pc, :set_local_description}

      assert :ok = Specter.PeerConnection.local_description(specter, pc)
      assert_receive {:local_description, ^pc, ^offer}
    end
  end

  describe "new" do
    setup [:initialize_specter, :init_api]

    test "returns a UUID, then sends a :peer_connection_ready", %{specter: specter, api: api} do
      assert {:ok, pc} = Specter.PeerConnection.new(specter, api)
      assert_receive {:peer_connection_ready, ^pc}

      assert is_binary(pc)
      assert String.match?(pc, @uuid_regex)
    end

    test "returns {:error, :not_found} when given a random api id", %{specter: specter} do
      assert {:error, :not_found} = Specter.PeerConnection.new(specter, UUID.uuid4())
    end
  end

  describe "pending_local_description" do
    setup [:initialize_specter, :init_api, :init_peer_connection]

    test "returns an error when peer connection does not exist", %{specter: specter} do
      assert {:error, :not_found} =
               Specter.PeerConnection.pending_local_description(specter, UUID.uuid4())
    end

    test "sends the pending local description back to elixir before ICE finishes", %{
      specter: specter,
      peer_connection: pc
    } do
      assert :ok = Specter.PeerConnection.pending_local_description(specter, pc)
      assert_receive {:pending_local_description, ^pc, nil}

      assert :ok = Specter.PeerConnection.create_offer(specter, pc)
      assert_receive {:offer, ^pc, offer}

      assert :ok = Specter.PeerConnection.set_local_description(specter, pc, offer)
      assert_receive {:ok, ^pc, :set_local_description}

      assert :ok = Specter.PeerConnection.pending_local_description(specter, pc)
      assert_receive {:pending_local_description, ^pc, ^offer}
    end
  end

  describe "pending_remote_description" do
    setup [
      :initialize_specter,
      :init_api,
      :init_peer_connection,
      :create_data_channel,
      :create_offer
    ]

    test "returns an error when peer connection does not exist", %{specter: specter} do
      assert {:error, :not_found} =
               Specter.PeerConnection.pending_remote_description(specter, UUID.uuid4())
    end

    test "sends the pending remote description back to elixir before ICE finishes", %{
      specter: specter,
      offer: offer
    } do
      api = init_api(specter)
      pc = init_peer_connection(specter, api)
      assert :ok = Specter.PeerConnection.pending_remote_description(specter, pc)
      assert_receive {:pending_remote_description, ^pc, nil}

      assert :ok = Specter.PeerConnection.set_remote_description(specter, pc, offer)
      assert_receive {:ok, ^pc, :set_remote_description}

      assert :ok = Specter.PeerConnection.pending_remote_description(specter, pc)
      assert_receive {:pending_remote_description, ^pc, ^offer}
    end
  end

  describe "remote_description" do
    setup [
      :initialize_specter,
      :init_api,
      :init_peer_connection,
      :create_data_channel,
      :create_offer
    ]

    test "returns an error when peer connection does not exist", %{specter: specter} do
      assert {:error, :not_found} =
               Specter.PeerConnection.remote_description(specter, UUID.uuid4())
    end

    test "sends the pending remote description back to elixir before ICE finishes", %{
      specter: specter,
      offer: offer
    } do
      api = init_api(specter)
      pc = init_peer_connection(specter, api)
      assert :ok = Specter.PeerConnection.remote_description(specter, pc)
      assert_receive {:remote_description, ^pc, nil}

      assert :ok = Specter.PeerConnection.set_remote_description(specter, pc, offer)
      assert_receive {:ok, ^pc, :set_remote_description}

      assert :ok = Specter.PeerConnection.remote_description(specter, pc)
      assert_receive {:remote_description, ^pc, ^offer}
    end
  end

  describe "set_local_description" do
    setup [:initialize_specter, :init_api, :init_peer_connection]

    test "returns an error when peer connection does not exist", %{specter: specter} do
      assert {:error, :not_found} =
               Specter.PeerConnection.set_local_description(specter, UUID.uuid4(), "")
    end

    test "returns an error when given invalid json", %{specter: specter, peer_connection: pc} do
      assert {:error, :invalid_json} =
               Specter.PeerConnection.set_local_description(specter, pc, "{blah:")
    end

    test "sends :ok when given a valid offer", %{specter: specter, peer_connection: pc} do
      assert :ok = Specter.PeerConnection.create_offer(specter, pc)
      assert_receive {:offer, ^pc, offer}

      assert :ok = Specter.PeerConnection.set_local_description(specter, pc, offer)
      assert_receive {:ok, ^pc, :set_local_description}
    end

    test "sends :invalid_local_description when given an invalid session", %{
      specter: specter,
      peer_connection: pc
    } do
      assert :ok =
               Specter.PeerConnection.set_local_description(
                 specter,
                 pc,
                 ~S[{"type":"offer","sdp":"derp"}]
               )

      assert_receive {:invalid_local_description, ^pc, "SdpInvalidSyntax: derp"}
    end
  end

  describe "set_remote_description" do
    setup [:initialize_specter, :init_api, :init_peer_connection]

    @valid_offer_sdp """
    v=0
    o=- 2927307686215094172 2 IN IP4 127.0.0.1
    s=-
    t=0 0
    a=extmap-allow-mixed
    a=msid-semantic: WMS
    a=ice-ufrag:ZZZZ
    a=ice-pwd:AU/SQPupllyS0SDG/eRWDCfA
    a=fingerprint:sha-256 B7:D5:86:B0:92:C6:A6:03:80:C8:59:47:25:EC:FF:3F:57:F5:97:EF:76:B9:AA:14:B7:8C:C9:B3:4D:CA:1B:0A
    """
    @valid_offer Jason.encode!(%{type: "offer", sdp: @valid_offer_sdp})

    test "returns :ok when given an offer", %{specter: specter, peer_connection: peer_connection} do
      assert :ok =
               Specter.PeerConnection.set_remote_description(
                 specter,
                 peer_connection,
                 @valid_offer
               )

      assert_receive {:ok, ^peer_connection, :set_remote_description}
      refute_received {:error, ^peer_connection, :invalid_remote_description}
    end

    test "sends an error message when SDP in invalid", %{specter: specter, peer_connection: pc} do
      assert :ok =
               Specter.PeerConnection.set_remote_description(
                 specter,
                 pc,
                 ~S[{"type":"offer","sdp":"Hello world"}]
               )

      assert_receive {:invalid_remote_description, ^pc, "SdpInvalidSyntax: Hello world"}
    end

    test "returns an error when peer connection does not exist", %{specter: specter} do
      assert {:error, :not_found} =
               Specter.PeerConnection.set_remote_description(specter, UUID.uuid4(), @valid_offer)
    end

    test "returns an error when given invalid json", %{specter: specter, peer_connection: pc} do
      assert {:error, :invalid_json} =
               Specter.PeerConnection.set_remote_description(specter, pc, ~S[{"type:"offer","sd}])
    end
  end

  describe "signaling_state" do
    setup [:initialize_specter, :init_api, :init_peer_connection]

    test "sends `:stable` just after creating a new peer connection back to elixir", %{
      specter: specter,
      peer_connection: peer_connection
    } do
      assert :ok = Specter.PeerConnection.signaling_state(specter, peer_connection)
      assert_receive {:signaling_state, ^peer_connection, :stable}
    end
  end
end
