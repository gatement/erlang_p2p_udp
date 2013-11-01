-module(p2p_client_sup).
-behaviour(supervisor).
%% API
-export([start_link/0]).
%% Supervisor callbacks
-export([init/1]).


%% ===================================================================
%% API functions
%% ===================================================================

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).


init([]) ->
    Server = {p2p_client_server, {p2p_client_server, start_link, []},
              permanent, 10000, worker, [p2p_client_server]},

    {ok, {{one_for_one, 300, 100}, [Server]}}.


%% ===================================================================
%% Local Functions
%% ===================================================================
