-module(p2p_client_server).
-behaviour(gen_server).
%% API
-export([start_link/0]).
%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-record(peer, {
                peer_id,
                peer_ip,
                peer_udp_port,
                peer_local_ip,
                peer_local_port,
                peer_public_ip,
                peer_public_port,
                is_hole_punching,
                hole_punch_times
         }).

-record(state, {
                server_host,
                server_tcp_port,
                server_udp_port,

                tcp_socket,
                udp_socket,

                client_id,
                session_id,
                client_local_ip,
                client_local_udp_port,

                peers,

                hole_punch_interval,
                max_hole_punch_times
               }).

-define(SERVER, ?MODULE).

%% ===================================================================
%% API functions
%% ===================================================================

start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).


%% ===================================================================
%% gen_server callbacks
%% ===================================================================

%% -- init -----------
init([]) ->
    {ok, ClientId} = application:get_env(client_id),
    {ok, ServerHost} = application:get_env(server_host),
    {ok, ServerTcpPort} = application:get_env(server_tcp_port),
    {ok, ServerUdpPort} = application:get_env(server_udp_port),
    {ok, HolePunchInterval} = application:get_env(hole_punch_interval),
    {ok, MaxHolePunchTimes} = application:get_env(max_hole_punch_times),

	UdpSocketOpts = [binary, {active, true}, {reuseaddr, true}],
    {ok, UdpSocket} = gen_udp:open(0, UdpSocketOpts),
    {ok, UdpPort} = inet:port(UdpSocket),

    LocalIp = tools:get_local_ip(),

    State = #state{
        client_id = ClientId,
        server_host = ServerHost,
        server_tcp_port = ServerTcpPort,
        server_udp_port = ServerUdpPort,
        udp_socket = UdpSocket,
        hole_punch_interval = HolePunchInterval,
        max_hole_punch_times = MaxHolePunchTimes,
        client_local_udp_port = UdpPort,
        client_local_ip = LocalIp,
        peers = []
    },

    error_logger:info_msg("[~p] was started with state ~p.~n", [?MODULE, tools:record_to_list(State, record_info(fields, state))]),
    {ok, State, 0}.


%% -- call -----------
handle_call({connect_to_peer, PeerId}, _From, State) ->
    {ok, State2} = handle_connect_to_peer_req(State, PeerId),
    {reply, ok, State2};

handle_call({send_msg_to_peer, _Msg}, _From, State) ->
    %State2 = handle_send_msg_to_peer_req(State, Msg),
    {reply, ok, State};

handle_call(_Msg, _From, State) ->
    error_logger:info_msg("[~p] was called: ~p.~n", [?MODULE, _Msg]),
    {reply, ok, State}.


%% -- cast ------------
handle_cast(_Msg, State) ->
    error_logger:info_msg("[~P] was casted: ~p.~n", [?MODULE, _Msg]),
    {noreply, State}.


%% -- info -------------
handle_info({udp, _UdpSocket, Ip, Port, RawData}, State) ->
    error_logger:info_msg("[~p] received udp data(~p:~p): ~p~n", [?MODULE, Ip, Port, RawData]),
    %State2 = handle_data(Ip, Port, RawData, State);
    {noreply, State};

handle_info({tcp, _Socket, RawData}, State) ->
    error_logger:info_msg("[~p] received tcp data: ~p~n", [?MODULE, RawData]),
    {ok, State2} = handle_tcp_data(RawData, State),
    {noreply, State2};

handle_info({tcp_closed, _Socket}, State) ->
    error_logger:info_msg("[~p] was infoed: ~p.~n", [?MODULE, tcp_closed]),
    {stop, tcp_closed, State};

handle_info(timeout, State) ->
    TcpSocket = online(State),
    State2 = State#state{tcp_socket = TcpSocket},

%    #state{
%       max_hole_punch_times = MaxHolePunchTimes,
%       hole_punch_times = HolePunchTimes,
%       hole_punch_interval = HolePunchInterval
%    } = State,
%
%    if 
%        HolePunchTimes < MaxHolePunchTimes ->
%            %State2 = hole_punch(State),
%            %{noreply, State2, HolePunchInterval};
%            {noreply, State};
%        true ->
%            {noreply, State}
%    end;
    {noreply, State2};

handle_info(_Msg, State) ->
    error_logger:info_msg("[~p] was infoed: ~p.~n", [?MODULE, _Msg]),
    {noreply, State}.

%% -- terminate ---------
terminate(Reason, _State) ->
    error_logger:info_msg("[~p] was terminated with reason: ~p.~n", [?MODULE, Reason]),
    ok.

%% -- code_change -------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.


%% ===================================================================
%% Local Functions
%% ===================================================================

handle_connect_to_peer_req(State, PeerId) ->
    send_udp_info(State, true, PeerId),
    {ok, State}.


send_udp_info(State, IsInviting, PeerId) ->
    #state {
        server_host = ServerHost,
        server_udp_port = ServerUdpPort,
        client_local_ip = ClientLocalIp,
        client_local_udp_port = ClientLocalUdpPort,
        session_id = SessionId,
        udp_socket = UdpSocket
    } = State,

    {LocalIp1, LocalIp2, LocalIp3, LocalIp4} = ClientLocalIp,
    EncodedClientLocalUdpPort = binary:encode_unsigned(ClientLocalUdpPort),

    SessionIdLen = erlang:size(erlang:list_to_binary([SessionId])),
    PeerIdLen = erlang:size(erlang:list_to_binary([PeerId])),

    InviteType = case IsInviting of
         true -> 16#01;
         false -> 16#02
    end,

    SendingData = [16#00, 16#11, InviteType, LocalIp1, LocalIp2, LocalIp3, LocalIp4, EncodedClientLocalUdpPort, SessionIdLen, SessionId, PeerIdLen, PeerId],
    gen_udp:send(UdpSocket, ServerHost, ServerUdpPort, SendingData).


online(State) ->
    #state{
        client_id = ClientId,
        server_host = ServerHost,
        server_tcp_port = ServerTcpPort
    } = State,

	TcpSocketOpts = [binary, {packet, 4}, {active, true}, {reuseaddr, true}],

    {ok, TcpSocket} = gen_tcp:connect(ServerHost, ServerTcpPort, TcpSocketOpts),

    ClientIdLen = erlang:size(erlang:list_to_binary([ClientId])),
    SendingData = [16#00, 16#01, ClientIdLen, ClientId],
    gen_tcp:send(TcpSocket, SendingData),

    TcpSocket.


handle_tcp_data(RawData, State) ->
    <<Cmd:2/binary, Payload/binary>> = RawData,

    case Cmd of
        %% -- online success ----------
        <<16#00, 16#02>> -> 
            <<_SessionIdLen:8/integer, SessionId0/binary>> = Payload,
            SessionId = erlang:binary_to_list(SessionId0),

            error_logger:info_msg("[~p] online success: ~p.~n", [?MODULE, State#state.client_id]),

            State2 = State#state{session_id = SessionId},
            {ok, State2};

        %% -- online error ------------
        <<16#00, 16#03>> -> 
            error_logger:info_msg("[~p] online error.~n", [?MODULE]),
            {ok, State};

        %% -- recv udp info -----------
        <<16#00, 16#13>> -> 
            handle_data_recv_upd_info(Payload, State)
    end.


handle_data_recv_upd_info(Payload, State) ->
    #state {
        peers = Peers,
        hole_punch_interval = HolePunchInterval
    } = State,

    <<InviteType:1/binary, PeerLocalIp:4/binary, PeerLocalUdpPort0:2/binary, PeerPublicIp:4/binary, PeerPublicUdpPort0:2/binary, _PeerIdLen:8/integer, PeerId0/binary>> = Payload,

    <<PeerLocalIp1:8/integer, PeerLocalIp2:8/integer, PeerLocalIp3:8/integer, PeerLocalIp4:8/integer>> = PeerLocalIp,
    <<PeerPublicIp1:8/integer, PeerPublicIp2:8/integer, PeerPublicIp3:8/integer, PeerPublicIp4:8/integer>> = PeerPublicIp,

    PeerLocalUdpPort = binary:decode_unsigned(PeerLocalUdpPort0),
    PeerPublicUdpPort = binary:decode_unsigned(PeerPublicUdpPort0),

    PeerId = erlang:binary_to_list(PeerId0),

    case InviteType of
       <<16#01>> ->
            %% invide 
            send_udp_info(State, false, PeerId);
       <<16#02>> ->
            %% accept 
            do_nothing
    end,

    Peers2 = lists:keydelete(PeerId, 2, Peers),
    Peer = #peer{
        peer_id = PeerId,
        peer_local_ip = {PeerLocalIp1, PeerLocalIp2, PeerLocalIp3, PeerLocalIp4},
        peer_local_port = PeerLocalUdpPort,
        peer_public_ip = {PeerPublicIp1, PeerPublicIp2, PeerPublicIp3, PeerPublicIp4},
        peer_public_port = PeerPublicUdpPort,
        is_hole_punching = true,
        hole_punch_times = 0
    },
    Peers3 = [Peer | Peers2],
    State2 = State#state{peers = Peers3},

    State3 = hole_punch(State2),
            
    {ok, State3, HolePunchInterval}.


hole_punch(State) ->
    #state {
        socket = Socket,
        peers = Peers
    } = State,

    PingReqData = <<16#03, 16#01, 16#00>>,  

    Fun = fun(Peer) ->
        #peer {
            peer_local_ip = PeerLocalIp, 
            peer_local_port = PeerLocalPort,
            peer_public_ip = PeerPublicIp,
            peer_public_port = PeerPublicPort,
            hole_punch_times = HolePunchTimes
        } = Peer

        gen_udp:send(Socket, PeerLocalIp, PeerLocalPort, PingReqData),
        error_logger:info_msg("[~p] ping ~p (local:~p:~p): ~p.~n", [?MODULE, PeerLocalIp, PeerLocalPort, HolePunchTimes]),

        gen_udp:send(Socket, PeerPublicIp, PeerPublicPort, PingReqData),
        error_logger:info_msg("[~p] ping ~p (public:~p:~p): ~p.~n", [?MODULE, PeerPublicIp, PeerPublicPort, HolePunchTimes])
    end,

    lists:foreach(Fun, Peers),

    State#state{hole_punch_times = HolePunchTimes + 1}.
