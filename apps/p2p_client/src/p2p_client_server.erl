-module(p2p_client_server).
-behaviour(gen_server).
%% API
-export([start_link/0]).
%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).
-record(state, {
                server_host,
                server_port,

                socket,

                client_id,
                client_local_ip,
                client_local_port,

                peer_id,
                peer_local_ip,
                peer_local_port,
                peer_public_ip,
                peer_public_port,

                hole_punch_interval
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
    {ok, ServerHost} = application:get_env(server_host),
    {ok, ServerPort} = application:get_env(server_port),
    {ok, HolePunchInterval} = application:get_env(hole_punch_interval),
    {ok, Socket} = gen_udp:open(0, [binary]),
    {ok, Port} = inet:port(Socket),
    LocalIp = tools:get_local_ip(),

    State = #state{
        server_host = ServerHost,
        server_port = ServerPort,
        socket = Socket,
        hole_punch_interval = HolePunchInterval,
        client_local_port = Port,
        client_local_ip = LocalIp
    },

    error_logger:info_msg("[~p] was started with state ~p.~n", [?MODULE, State]),
    {ok, State}.


%% -- call -----------
handle_call({online, ClientId}, _From, State) ->
    State2 = handle_online_req(State, ClientId),
    {reply, ok, State2};

handle_call({connect_to_peer, PeerId}, _From, State) ->
    State2 = handle_connect_to_peer_req(State, PeerId),
    {reply, ok, State2};

handle_call({send_msg_to_peer, _Msg}, _From, State) ->
    %handle_send_msg_to_peer_req(State, Msg);
    {reply, ok, State};

handle_call(_Msg, _From, State) ->
    error_logger:info_msg("[~p] was called: ~p.~n", [?MODULE, _Msg]),
    {reply, ok, State}.


%% -- cast ------------
handle_cast(_Msg, State) ->
    error_logger:info_msg("[~P] was casted: ~p.~n", [?MODULE, _Msg]),
    {noreply, State}.


%% -- info -------------
handle_info({udp, _UdpSocket, _PeerIp, _PeerPort, RawData}, State) ->
    error_logger:info_msg("[~p] received udp data: ~p~n", [?MODULE, RawData]),
    %dispatch(handle_data, RawData, State);
    {noreply, State};

handle_info({tcp_closed, _Socket}, State) ->
    %error_logger:info_msg("[~p] was infoed: ~p.~n", [?MODULE, tcp_closed]),
    {noreply, State};
    
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

%dispatch(handle_data, RawData, State) ->
%    handle_recved_packages(State, RawData);
%
%dispatch(terminate, State, Reason) ->
%    #state{tcp_socket=TcpSocket, client_id=ClientId} = State,
%    p2p_client_handler:terminate(erlang:self(), TcpSocket, ClientId, Reason),
%    ok.
%
%
%handle_recved_packages(State, <<>>) ->
%    {noreply, State};
%
%handle_recved_packages(State, RawData) ->
%    <<TypeCode:1/binary, DataLen:8/integer, _/binary>> = RawData,
%    Payload = binary:part(RawData, 2, DataLen), 
%
%    Result = case TypeCode of
%        %% -- online res ------------
%        <<16#01>> -> 
%            case Payload of
%                <<16#00>> ->
%                    error_logger:info_msg("[~p] online success~n", [?MODULE]),
%                    {ok, State};
%                <<16#01>> ->
%                    error_logger:info_msg("[~p] online fail~n", [?MODULE]),
%                    {ok, State}
%            end;
%
%        %% -- connect2 --------------
%        <<16#03>> -> 
%            <<PeerIp1:8/integer, PeerIp2:8/integer, PeerIp3:8/integer, PeerIp4:8/integer, PeerPortH:8/integer, PeerPortL:8/integer, PeerClientId0/binary>> = Payload,
%
%            %%% create udp socket
%            {ok, UdpSocket} = gen_udp:open(0, [binary]),
%            {ok, UdpPort} = inet:port(UdpSocket),
%
%            %%% open a hole for incoming msg
%            PeerIp = {PeerIp1, PeerIp2, PeerIp3, PeerIp4},
%            PeerPort = PeerPortH * 256 + PeerPortL,
%            PingData = <<16#06, 16#01, 16#00>>,
%            error_logger:info_msg("[~p] udp ping (~p:~p) ~p.~n", [?MODULE, PeerIp, PeerPort, PingData]),
%            gen_udp:send(UdpSocket, PeerIp, PeerPort, PingData),
%
%            %%% response (connect3)
%            UdpPortH = UdpPort div 256,
%            UdpPortL = UdpPort rem 256,
%            PeerClientId = erlang:binary_to_list(PeerClientId0),
%            SendingDataLen = erlang:size(erlang:list_to_binary([PeerClientId])) + 2,
%            SendingData = [16#04, SendingDataLen, UdpPortH, UdpPortL, PeerClientId],
%            gen_tcp:send(State#state.tcp_socket, SendingData),
%
%            %%% print connected msg
%            error_logger:info_msg("[~p] connected to peer(~p:~p) ~p.~n", [?MODULE, PeerIp, PeerPort, PeerClientId]),
%
%            {ok, State#state{udp_socket=UdpSocket, udp_port=UdpPort, peer_ip=PeerIp, peer_port=PeerPort}};
%
%        %% -- connect4 --------------
%        <<16#05>> -> 
%            <<Res:1/binary, RestPayload/binary>> = Payload,
%            case Res of
%                <<16#01>> ->
%                    error_logger:info_msg("[~p] connect to peer failed.~n", [?MODULE]),
%                    {ok, State};
%                <<16#00>> ->
%                    <<PeerIp1:8/integer, PeerIp2:8/integer, PeerIp3:8/integer, PeerIp4:8/integer, PeerPortH:8/integer, PeerPortL:8/integer, PeerClientId0/binary>> = RestPayload,
%
%                    %% peer addr info
%                    PeerIp = {PeerIp1, PeerIp2, PeerIp3, PeerIp4},
%                    PeerPort = PeerPortH * 256 + PeerPortL,
%
%                    %% open a hold for incoming msg
%                    PingData = <<16#06, 16#01, 16#00>>,
%                    error_logger:info_msg("[~p] udp ping (~p:~p) ~p.~n", [?MODULE, PeerIp, PeerPort, PingData]),
%                    gen_udp:send(State#state.udp_socket, PeerIp, PeerPort, PingData),
%                    
%                    %%% print connected msg
%                    PeerClientId = erlang:binary_to_list(PeerClientId0),
%                    error_logger:info_msg("[~p] connected to peer(~p:~p) ~p.~n", [?MODULE, PeerIp, PeerPort, PeerClientId]),
%                    %% save peer addr info
%                    {ok, State#state{peer_ip=PeerIp, peer_port=PeerPort}}
%            end;
%
%        %% -- udp ping -------------
%        <<16#06>> ->
%            %% do nothing
%            {ok, State};
%
%        <<16#07>> -> 
%            error_logger:info_msg("[~p] recv msg(~p:~p): ~p~n", [?MODULE, State#state.peer_ip, State#state.peer_port, erlang:binary_to_list(Payload)]),
%            {ok, State}
%    end,
%
%    case Result of
%        {err, Reason, State2} ->
%            {stop, Reason, State2};
%
%        {ok, State2} ->
%            RestRawData = binary:part(RawData, 2 + DataLen, erlang:byte_size(RawData) - 2 - DataLen),
%            handle_recved_packages(State2, RestRawData)
%    end.


handle_online_req(State, ClientId) ->
    #state {
        server_host = ServerHost,
        server_port = ServerPort,
        client_local_ip = {Ip1, Ip2, Ip3, Ip4},
        client_local_port = Port,
        socket = Socket
    } = State,

    PortH = Port div 256,
	PortL = Port rem 256,

    ClientIdLen = erlang:size(erlang:list_to_binary([ClientId])),
    SendingDataLen = 7 + ClientIdLen,
    SendingData = [16#01, SendingDataLen, Ip1, Ip2, Ip3, Ip4, PortH, PortL, ClientIdLen, ClientId],
    gen_udp:send(Socket, ServerHost, ServerPort, SendingData),

    State#state{client_id=ClientId}.


handle_connect_to_peer_req(State, PeerId) ->
    #state {
        server_host = ServerHost,
        server_port = ServerPort,
        client_id = ClientId,
        socket = Socket
    } = State,

    ClientIdLen = erlang:size(erlang:list_to_binary([ClientId])),
    PeerIdLen = erlang:size(erlang:list_to_binary([PeerId])),
    SendingDataLen = 2 + ClientIdLen + PeerIdLen,
    SendingData = [16#02, SendingDataLen, ClientIdLen, ClientId, PeerIdLen, PeerId],
    gen_udp:send(Socket, ServerHost, ServerPort, SendingData),

    State.

%handle_connect_to_peer_req(State, PeerClientId) ->
%    %% create udp socket
%    {ok, UdpSocket} = gen_udp:open(0, [binary]),
%    {ok, UdpPort} = inet:port(UdpSocket),
%	UdpPortH = UdpPort div 256,
%	UdpPortL = UdpPort rem 256,
%
%    %% send connect1
%    SendingDataLen = erlang:size(erlang:list_to_binary([PeerClientId])) + 2,
%    SendingData = [16#02, SendingDataLen, UdpPortH, UdpPortL, PeerClientId],
%    gen_tcp:send(State#state.tcp_socket, SendingData),
%    
%    %% save udp socket info
%    {reply, ok, State#state{udp_socket=UdpSocket, udp_port=UdpPort}}.
%
%
%handle_send_msg_to_peer_req(State, Msg) ->
%    SendingDataLen = erlang:size(erlang:list_to_binary([Msg])),
%    SendingData = [16#07, SendingDataLen, Msg],
%    error_logger:info_msg("[~p] sending udp data: ~p~n", [?MODULE, SendingData]),
%    gen_udp:send(State#state.udp_socket, State#state.peer_ip, State#state.peer_port, SendingData),
%    {reply, ok, State}.
%
