-module(p2p_server_server).
-include("p2p_server.hrl").
-behaviour(gen_server).
%% API
-export([start_link/0]).
%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).
-record(state, {
                socket
               }).


%% ===================================================================
%% API functions
%% ===================================================================

start_link() ->
    gen_server:start_link(?MODULE, [], []).


%% ===================================================================
%% gen_server callbacks
%% ===================================================================

%% -- init -----------
init([]) ->
    {ok, UdpPort} = application:get_env(udp_port),
    {ok, Socket} = gen_udp:open(UdpPort, [binary]),

    State = #state{
        socket = Socket
    },

    error_logger:info_msg("[~p] was started with state ~p.~n", [?MODULE, State]),
    {ok, State}.


%% -- call -----------
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
    handle_data(Ip, Port, RawData, State#state.socket),
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

handle_data(Ip, Port, RawData, Socket) ->
    <<TypeCode:1/binary, DataLen:8/integer, _/binary>> = RawData,
    Payload = binary:part(RawData, 2, DataLen), 

    case TypeCode of
        %% -- online ---------------
        <<16#01>> -> 
            handle_data_online_req(Ip, Port, Payload, Socket);

        %% -- connect req ----------
        <<16#02>> -> 
            handle_data_connect_req(Ip, Port, Payload, Socket)
    end.


handle_data_online_req(Ip, Port, Payload, Socket) ->
    error_logger:info_msg("[~p] client online(~p:~p): ~p~n", [?MODULE, Ip, Port, Payload]),
    <<LocalIp1:8/integer, LocalIp2:8/integer, LocalIp3:8/integer, LocalIp4:8/integer, LocalPortH:8/integer, LocalPortL:8/integer, ClientIdData/binary>> = Payload,

    LocalIp = {LocalIp1, LocalIp2, LocalIp3, LocalIp4}, 
    LocalPort = LocalPortH * 256 + LocalPortL,

    <<_ClientIdLen:8/integer, ClientId0/binary>> = ClientIdData,
    ClientId = erlang:binary_to_list(ClientId0),

    SendingData = case model_run_user:get(ClientId) of
        undefined ->
            model_run_user:create(#run_user{
                    id = ClientId, 
                    local_ip = LocalIp,
                    local_port = LocalPort,
                    public_ip = Ip,
                    public_port = Port,
					createdTime = tools:datetime_string('yyyyMMdd_hhmmss')
            }),
            %% success
            <<16#01, 16#01, 16#00>>;
        _ ->
            %% Fail
            <<16#01, 16#01, 16#01>>
    end,

    gen_udp:send(Socket, Ip, Port, SendingData).


handle_data_connect_req(Ip, Port, Payload, Socket) ->
    error_logger:info_msg("[~p] connect to peer req(~p:~p): ~p~n", [?MODULE, Ip, Port, Payload]),
    <<ClientIdLen:8/integer, RestPayload/binary>> = Payload,
    ClientId = erlang:binary_to_list(binary:part(RestPayload, 0, ClientIdLen)),
    RestPayload2 = binary:part(RestPayload, ClientIdLen, erlang:byte_size(RestPayload) - ClientIdLen),
    <<_PeerIdLen:8/integer, PeerId0/binary>> = RestPayload2,
    PeerId = erlang:binary_to_list(PeerId0),

    case model_run_user:get(ClientId) of
        undefined ->
            %% ClientId is not online
            SendingData = <<16#02, 16#01, 16#01>>,
            gen_udp:send(Socket, Ip, Port, SendingData);
        error ->
            %% db error
            SendingData = <<16#02, 16#01, 16#01>>,
            gen_udp:send(Socket, Ip, Port, SendingData);
        Client ->
            case model_run_user:get(PeerId) of
                undefined ->
                    %% PeerId is not online
                    SendingData = <<16#02, 16#01, 16#01>>,
                    gen_udp:send(Socket, Ip, Port, SendingData);
                error ->
                    %% db error
                    SendingData = <<16#02, 16#01, 16#01>>,
                    gen_udp:send(Socket, Ip, Port, SendingData);
                Peer ->
                    ClientIdLen = erlang:size(erlang:list_to_binary([ClientId])),
                    PeerIdLen = erlang:size(erlang:list_to_binary([PeerId])),

                    {ClientLocalIp1, ClientLocalIp2, ClientLocalIp3, ClientLocalIp4} = Client#run_user.local_ip, 
                    {ClientPublicIp1, ClientPublicIp2, ClientPublicIp3, ClientPublicIp4} = Peer#run_user.public_ip, 

                    {PeerLocalIp1, PeerLocalIp2, PeerLocalIp3, PeerLocalIp4} = Peer#run_user.local_ip, 
                    {PeerPublicIp1, PeerPublicIp2, PeerPublicIp3, PeerPublicIp4} = Client#run_user.public_ip, 

                    ClientLocalPortH = Client#run_user.local_port div 256,
                    ClientLocalPortL = Client#run_user.local_port rem 256,

                    ClientPublicPortH = Client#run_user.public_port div 256,
                    ClientPublicPortL = Client#run_user.public_port rem 256,

                    PeerLocalPortH = Peer#run_user.local_port div 256,
                    PeerLocalPortL = Peer#run_user.local_port rem 256,

                    PeerPublicPortH = Peer#run_user.public_port div 256,
                    PeerPublicPortL = Peer#run_user.public_port rem 256,

                    SendingDataLenPeer = 14 + ClientIdLen,
                    SendingDataLenClient = 14 + PeerIdLen,

                    SendingDataPeer = [16#02, SendingDataLenPeer, 16#00, ClientLocalIp1, ClientLocalIp2, ClientLocalIp3, ClientLocalIp4, ClientLocalPortH, ClientLocalPortL, ClientPublicIp1, ClientPublicIp2, ClientPublicIp3, ClientPublicIp4, ClientPublicPortH, ClientPublicPortL, ClientIdLen, ClientId],

                    SendingDataClient = [16#02, SendingDataLenClient, 16#00, PeerLocalIp1, PeerLocalIp2, PeerLocalIp3, PeerLocalIp4, PeerLocalPortH, PeerLocalPortL, PeerPublicIp1, PeerPublicIp2, PeerPublicIp3, PeerPublicIp4, PeerPublicPortH, PeerPublicPortL, PeerIdLen, PeerId],

                    gen_udp:send(Socket, Ip, Port, SendingDataClient),
                    gen_udp:send(Socket, Peer#run_user.public_ip, Peer#run_user.public_port, SendingDataPeer)
            end
    end.
