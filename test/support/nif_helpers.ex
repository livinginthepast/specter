defmodule SpecterTest.NifHelpers do
  @moduledoc false
  import ExUnit.Assertions

  def create_data_channel(%{specter: specter, peer_connection: pc}),
    do: create_data_channel(specter, pc)

  def create_data_channel(%Specter{} = specter, pc) do
    :ok = Specter.PeerConnection.create_data_channel(specter, pc, "data")
    ExUnit.Assertions.assert_receive({:data_channel_created, ^pc})
    :ok
  end

  def create_offer(%{specter: specter, peer_connection: pc}) do
    :ok = Specter.PeerConnection.create_offer(specter, pc)
    ExUnit.Assertions.assert_receive({:offer, ^pc, offer})
    [offer: offer]
  end

  @doc """
  Initialize Specter. Adds `%{specter: specter}` to the test
  context.
  """
  def initialize_specter(_ctx) do
    {:ok, specter} = Specter.init()
    [specter: specter]
  end

  def init_api(%{specter: specter}) do
    [api: init_api(specter)]
  end

  def init_api(%Specter{} = specter) do
    {:ok, media_engine} = Specter.new_media_engine(specter)
    {:ok, registry} = Specter.new_registry(specter, media_engine)
    {:ok, api} = Specter.new_api(specter, media_engine, registry)

    api
  end

  def init_peer_connection(%{specter: specter, api: api}) do
    [peer_connection: init_peer_connection(specter, api)]
  end

  def init_peer_connection(%Specter{} = specter, api) do
    {:ok, pc} = Specter.PeerConnection.new(specter, api)
    assert_receive {:peer_connection_ready, ^pc}
    true = Specter.PeerConnection.exists?(specter, pc)
    pc
  end

  def negotiate_connection(specter, pc_offer, pc_answer) do
    :ok = Specter.PeerConnection.create_offer(specter, pc_offer)
    assert_receive {:offer, ^pc_offer, offer}
    :ok = Specter.PeerConnection.set_local_description(specter, pc_offer, offer)
    assert_receive {:ok, ^pc_offer, :set_local_description}

    :ok = wait_for_ice_gathering_complete(specter, pc_offer)

    :ok = Specter.PeerConnection.set_remote_description(specter, pc_answer, offer)
    assert_receive {:ok, ^pc_answer, :set_remote_description}

    :ok = Specter.PeerConnection.create_answer(specter, pc_answer)
    assert_receive {:answer, ^pc_answer, answer}
    :ok = Specter.PeerConnection.set_local_description(specter, pc_answer, answer)
    assert_receive {:ok, ^pc_answer, :set_local_description}

    :ok = wait_for_ice_gathering_complete(specter, pc_answer)

    assert_receive {:ice_candidate, ^pc_offer, candidate}
    :ok = Specter.PeerConnection.add_ice_candidate(specter, pc_answer, candidate)
    assert_receive {:ok, ^pc_answer, :add_ice_candidate}

    :ok = Specter.PeerConnection.set_remote_description(specter, pc_offer, answer)
    assert_receive {:ok, ^pc_offer, :set_remote_description}

    assert_receive {:ice_candidate, ^pc_answer, candidate}
    :ok = Specter.PeerConnection.add_ice_candidate(specter, pc_offer, candidate)
    assert_receive {:ok, ^pc_offer, :add_ice_candidate}

    :ok = wait_for_peer_connection_connected(specter, pc_offer)
    :ok = wait_for_peer_connection_connected(specter, pc_answer)

    :ok
  end

  def wait_for_ice_gathering_complete(specter, pc) do
    Moar.Retry.rescue_for!(5_000, fn ->
      :ok = Specter.PeerConnection.ice_gathering_state(specter, pc)
      assert_receive {:ice_gathering_state, ^pc, :complete}
    end)

    :ok
  end

  def wait_for_peer_connection_connected(specter, pc) do
    Moar.Retry.rescue_for!(5_000, fn ->
      :ok = Specter.PeerConnection.connection_state(specter, pc)
      assert_receive {:connection_state, ^pc, :connected}
    end)

    :ok
  end

  def find_stats(stats, prefix),
    do: Enum.find_value(stats, fn {key, value} -> String.starts_with?(key, prefix) && value end)

  def receive_stats(pc) do
    assert_receive {:stats, ^pc, stats_json}
    {:ok, stats} = Jason.decode(stats_json)
    assert map_size(stats) > 0, "Expected stats to have reports, found:\n#{stats_json}"
    stats
  end

  def assert_stats(specter, pc, prefix, stats) do
    :ok = Specter.PeerConnection.get_stats(specter, pc)

    expected =
      Moar.Map.stringify_keys(stats)
      |> Map.new(fn {k, v} -> {Moar.String.to_case(k, :lower_camel_case), v} end)

    pc
    |> receive_stats()
    |> find_stats(prefix)
    |> Map.take(Map.keys(expected))
    |> Moar.Assertions.assert_eq(expected)
  end
end
