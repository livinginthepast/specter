use rustler::{Env, Term};

mod atoms;
mod config;
mod state;

fn on_load(env: Env, _info: Term) -> bool {
    rustler::resource!(state::Ref, env);
    true
}

rustler::init!(
    "Elixir.Specter.Native",
    [
        state::get_config,
        state::init,
        state::media_engine_exists,
        state::new_api,
        state::new_media_engine,
        state::new_peer_connection,
        state::new_registry,
        state::registry_exists,
    ],
    load = on_load
);
