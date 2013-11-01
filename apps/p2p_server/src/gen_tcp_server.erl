-module(gen_tcp_server).
-export([start_link/3]).
-export([behaviour_info/1]).

%% ===================================================================
%% behavior callbacks
%% ===================================================================

behaviour_info(callbacks) ->
    [
     {process_data_online, 4},
     {process_data_offline, 4},
     {process_data_publish, 4},
     {terminate, 4}
    ];
behaviour_info(_Other) ->
    undefined.

%% ===================================================================
%% API functions
%% ===================================================================

start_link(SupName, Callback, Port) ->
    gen_tcp_server_connection_sup:start_link(SupName, Callback, Port).


%% ===================================================================
%% Local Functions
%% ===================================================================
