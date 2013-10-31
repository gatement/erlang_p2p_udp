-module(p2p_server_sup).
-behaviour(supervisor).
%% API
-export([start_link/0]).
%% Supervisor callbacks
-export([init/1]).
-define(SERVER, ?MODULE).


%% ===================================================================
%% API functions
%% ===================================================================

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).


%% ===================================================================
%% Supervisor callbacks
%% ===================================================================

init([]) ->
    Server = {p2p_server_server, {p2p_server_server, start_link, []},
              permanent, 1000, supervisor, [p2p_server_server]},
              
    Children = [Server],
    RestartStrategy = {one_for_one, 300, 1},
    {ok, {RestartStrategy, Children}}.


%% ===================================================================
%% Local Functions
%% ===================================================================
