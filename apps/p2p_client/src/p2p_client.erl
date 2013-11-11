-module(p2p_client).
-export([start/0,
        connect/1,
        send/2
        ]).

-define(SERVER, p2p_client_server).


%% ===================================================================
%% Application callbacks
%% ===================================================================

start() ->
	application:start(p2p_client).


%% connect to another peer
connect(PeerId) ->
    gen_server:call(?SERVER, {connect_to_peer, PeerId}),
    ok.


%% send msg to peer
send(PeerId, Msg) ->
    gen_server:call(?SERVER, {send_msg_to_peer, PeerId, Msg}),
    ok.


%% ===================================================================
%% Local Functions
%% ===================================================================
