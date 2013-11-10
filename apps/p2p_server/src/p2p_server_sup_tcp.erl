-module(p2p_server_sup_tcp).
-behaviour(supervisor).
%% API
-export([start_link/0]).
%% Supervisor callbacks
-export([init/1]).


%% ===================================================================
%% API functions
%% ===================================================================

start_link() ->
    {ok, SupPid} = supervisor:start_link({local, ?MODULE}, ?MODULE, []),

    %% start child servers for connection listening
    {ok, WorkerCount} = application:get_env(init_tcp_worker_count),
    start_childs(SupPid, WorkerCount),

    {ok, SupPid}.


init([]) ->
    {ok, Port} = application:get_env(tcp_port),
	TcpSocketOpts = [binary, {packet, 4}, {active, true}, {reuseaddr, true}, {keepalive, true}],
    {ok, LSocket} = gen_tcp:listen(Port, TcpSocketOpts),

    Server = {p2p_server_server_tcp, {p2p_server_server_tcp, start_link, [LSocket]},
              temporary, brutal_kill, worker, [p2p_server_server_tcp]},

    RestartStrategy = {simple_one_for_one, 1000, 600},
  
    {ok, {RestartStrategy, [Server]}}.


%% ===================================================================
%% Local Functions
%% ===================================================================
start_childs(_, 0) ->
    ok;
start_childs(SupPid, WorkerCount) ->
    supervisor:start_child(SupPid, []),
    start_childs(SupPid, WorkerCount - 1).

