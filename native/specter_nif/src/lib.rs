use rustler::{Env, Term};

mod atoms;
mod codec_capability;
mod config;
mod peer_connection;
mod state;
mod task;
mod track;
mod util;

fn on_load(env: Env, _info: Term) -> bool {
    match env_logger::try_init() {
        Ok(()) => log::debug!("Logger initialized succsessfully\r"),
        Err(_reason) => log::debug!("Logger already initialized. Ignoring.\r"),
    };
    state::load(env);
    true
}

rustler::init!(
    "Elixir.Specter.Native",
    [
        peer_connection::add_ice_candidate,
        peer_connection::add_track,
        peer_connection::close,
        peer_connection::connection_state,
        peer_connection::create_answer,
        peer_connection::create_data_channel,
        peer_connection::create_offer,
        peer_connection::get_current_local_description,
        peer_connection::get_current_remote_description,
        peer_connection::get_local_description,
        peer_connection::get_remote_description,
        peer_connection::get_pending_local_description,
        peer_connection::get_pending_remote_description,
        peer_connection::get_stats,
        peer_connection::ice_connection_state,
        peer_connection::ice_gathering_state,
        peer_connection::new,
        peer_connection::set_local_description,
        peer_connection::set_remote_description,
        peer_connection::signaling_state,
        state::get_config,
        state::init,
        state::media_engine_exists,
        state::new_api,
        state::new_media_engine,
        state::new_registry,
        state::new_track_local_static_sample,
        state::peer_connection_exists,
        state::registry_exists,
        track::play_from_file_h264,
    ],
    load = on_load
);
