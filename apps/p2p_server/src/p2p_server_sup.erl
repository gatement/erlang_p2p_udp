-module(p2p_server_sup).
-behaviour(supervisor).
%% API
-export([start_link/0]).
%% Supervisor callbacks
-export([init/1]).


%% ===================================================================
%% API functions
%% ===================================================================

start_link() ->
    supervisor:start_link(?MODULE, []).


init([]) ->
    TcpServer = {p2p_server_sup_tcp, {p2p_server_sup_tcp, start_link, []},
              permanent, brutal_kill, supervisor, [p2p_server_sup_tcp]},

    UdpServer = {p2p_server_sup_udp, {p2p_server_sup_udp, start_link, []},
              permanent, brutal_kill, supervisor, [p2p_server_sup_udp]},


    RestartStrategy = {one_for_one, 1000, 600},
  
    {ok, {RestartStrategy, [TcpServer, UdpServer]}}.


%% ===================================================================
%% Local Functions
%% ===================================================================
