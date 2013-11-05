-module(p2p_client).
-export([start/0,
        online/1,
        connect_to_peer/1,
        send_msg/1
        ]).

-define(SERVER, p2p_client_server).


%% ===================================================================
%% Application callbacks
%% ===================================================================

start() ->
	application:start(p2p_client).

%% online myself
online(ClientId) ->
    gen_server:call(?SERVER, {online, ClientId}),
    ok.

%% connect to another peer
connect_to_peer(PeerId) ->
    gen_server:call(?SERVER, {connect_to_peer, PeerId}),
    ok.

%% send msg to peer
send_msg(Msg) ->
    gen_server:call(?SERVER, {send_msg_to_peer, Msg}),
    ok.


%% ===================================================================
%% Local Functions
%% ===================================================================
