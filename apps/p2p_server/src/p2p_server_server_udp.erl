-module(p2p_server_server_udp).
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
    {ok, Port} = application:get_env(udp_port),
	UdpSocketOpts = [binary, {active, true}, {reuseaddr, true}],
    {ok, Socket} = gen_udp:open(Port, UdpSocketOpts),

    State = #state{
        socket = Socket
    },

    error_logger:info_msg("[~p] was started.~n", [?MODULE]),
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
    %error_logger:info_msg("[~p] received udp data(~p:~p): ~p~n", [?MODULE, Ip, Port, RawData]),
    {ok, State2} = handle_udp_data(Ip, Port, RawData, State),
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

handle_udp_data(Ip, Port, RawData, State) ->
    <<Cmd:2/binary, Payload/binary>> = RawData,

    case Cmd of
        %% -- send udp info ---------------
        <<16#00, 16#11>> -> 
            handle_data_send_udp_info(Ip, Port, Payload, State)
    end.


handle_data_send_udp_info(Ip, Port, Payload, State) ->
    #state{
       socket = Socket
    } = State,

    <<InviteType:8/integer, LocalIp:4/binary, LocalUdpPort:2/binary, SessionIdLen:8/integer, RestPayload/binary>> = Payload,

    SessionId = erlang:binary_to_list(binary:part(RestPayload, 0, SessionIdLen)),
    PeerId = erlang:binary_to_list(binary:part(RestPayload, SessionIdLen + 1, erlang:size(RestPayload) - SessionIdLen - 1)),

    %error_logger:info_msg("[~p] handle_data_send_udp_info(localIp: ~p, localUdpPort: ~p, sessionId: ~p, peerId: ~p~n", [?MODULE, LocalIp, LocalUdpPort, SessionId, PeerId]),

    case model_run_user:get(SessionId) of
        undefined ->
            %% fail, no such session id (authentication fail)
            SendingData = <<16#00, 16#12>>,
            error_logger:info_msg("[~p] handle_data_send_udp_info: no such session id ~p.~n", [?MODULE, SessionId]),
            gen_udp:send(Socket, Ip, Port, SendingData);

        Client ->
            if
                Client#run_user.client_id =:= PeerId ->
                    %% fail, because want to connect self
                    SendingData = <<16#00, 16#12>>,
                    error_logger:info_msg("[~p] handle_data_send_udp_info: want to connect to self ~p.~n", [?MODULE, PeerId]),
                    gen_udp:send(Socket, Ip, Port, SendingData);
                true ->
                    case model_run_user:get_by_client_id(PeerId) of
                        undefined ->
                            %% fail, no such online peer
                            SendingData = <<16#00, 16#12>>,
                            error_logger:info_msg("[~p] handle_data_send_udp_info: no such online peer ~p.~n", [?MODULE, PeerId]),
                            gen_udp:send(Socket, Ip, Port, SendingData);
                        Peer ->
                            %% success
                            ClientId = Client#run_user.client_id,
                            ClientIdLen = erlang:size(erlang:list_to_binary([ClientId])),
                            {PublicIp1, PublicIp2, PublicIp3, PublicIp4} = Ip,
                            EncodedPublicUdpPort = binary:encode_unsigned(Port),
                            SendingData = [16#00, 16#13, InviteType, LocalIp, LocalUdpPort, PublicIp1, PublicIp2, PublicIp3, PublicIp4, EncodedPublicUdpPort, ClientIdLen, ClientId],
                            %error_logger:info_msg("[~p] handle_data_send_udp_info sending data: ~p~n", [?MODULE, SendingData]),
                            Peer#run_user.pid ! {send_tcp_data, SendingData}
                    end
            end
    end,

    {ok, State}.
