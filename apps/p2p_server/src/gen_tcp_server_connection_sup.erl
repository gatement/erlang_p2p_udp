-module(gen_tcp_server_connection_sup).
-behaviour(supervisor).
%% API
-export([start_link/3, start_child/1]).
%% Supervisor callbacks
-export([init/1]).


%% ===================================================================
%% API functions
%% ===================================================================

start_link(SupName, Callback, Port) ->
    {ok, SupervisorPid} = supervisor:start_link({local, SupName}, ?MODULE, [Callback, Port]),

    %% start child servers for connection listening
    {ok, WorkerCount} = application:get_env(mqtt_broker, init_worker_count),
    start_children(SupervisorPid, WorkerCount),

    {ok, SupervisorPid}.


start_children(_, 0) ->
    ok;
start_children(SupervisorPid, WorkerCount) ->
    supervisor:start_child(SupervisorPid, []),
    start_children(SupervisorPid, WorkerCount - 1).


start_child(SupervisorPid) ->
    supervisor:start_child(SupervisorPid, []).


init([Callback, Port]) ->
	SocketOpts = [binary, {active, true}, {reuseaddr, true}],
    {ok, LSocket} = gen_tcp:listen(Port, SocketOpts),

    Server = {gen_tcp_server_server, {gen_tcp_server_server, start_link, [Callback, LSocket]},
              temporary, brutal_kill, worker, [gen_tcp_server_server]},

    RestartStrategy = {simple_one_for_one, 1000, 3600},
  
    {ok, {RestartStrategy, [Server]}}.


%% ===================================================================
%% Local Functions
%% ===================================================================
