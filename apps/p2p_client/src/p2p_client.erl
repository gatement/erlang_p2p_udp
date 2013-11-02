-module(p2p_client).
-export([start/0,
        connect/1
        ]).

-define(SERVER, p2p_client_server).


%% ===================================================================
%% Application callbacks
%% ===================================================================

start() ->
	application:start(p2p_client).

connect(ClientId) ->
    gen_server:call(?SERVER, {connect, ClientId}, infinity),
    ok.


%% ===================================================================
%% Local Functions
%% ===================================================================
