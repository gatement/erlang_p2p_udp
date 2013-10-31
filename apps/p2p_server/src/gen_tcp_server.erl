-module(gen_tcp_server).
-export([start_link/3]).


%% ===================================================================
%% API functions
%% ===================================================================

start_link(SupName, Callback, Port) ->
    gen_tcp_server_connection_sup:start_link(SupName, Callback, Port).


%% ===================================================================
%% Local Functions
%% ===================================================================
