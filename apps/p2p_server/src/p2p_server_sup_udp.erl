-module(p2p_server_sup_udp).
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
    Server = {p2p_server_server_udp, {p2p_server_server_udp, start_link, []},
              permanent, 10000, worker, [p2p_server_server_udp]},

    {ok, {{one_for_one, 1000, 600}, [Server]}}.


%% ===================================================================
%% Local Functions
%% ===================================================================
