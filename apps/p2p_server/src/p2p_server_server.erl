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
    error_logger:info_msg("[~p] received udp data: ~p~n", [?MODULE, RawData]),
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

handle_data(_, _, <<>>, _) ->
    ok;
handle_data(Ip, Port, RawData, Socket) ->
    <<TypeCode:1/binary, DataLen:8/integer, _/binary>> = RawData,
    Payload = binary:part(RawData, 2, DataLen), 

    case TypeCode of
        %% -- online ---------------
        <<16#01>> -> 
            handle_data_online(Ip, Port, Payload, Socket);

        %% -- connect req ----------
        <<16#02>> -> 
            handle_data_connect_req(Ip, Port, Payload, Socket)
    end,

    RestRawData = binary:part(RawData, 2 + DataLen, erlang:byte_size(RawData) - 2 - DataLen),
    handle_data(Ip, Port, RestRawData, Socket).


handle_data_online(Ip, Port, Payload, Socket) ->
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


handle_data_connect_req(Ip, Port, Payload, _Socket) ->
    error_logger:info_msg("[~p] connect to peer req(~p:~p): ~p~n", [?MODULE, Ip, Port, Payload]),
    <<ClientIdLen:8/integer, RestPayload/binary>> = Payload,
    ClientId = erlang:binary_to_list(binary:part(RestPayload, 0, ClientIdLen)),
    RestPayload2 = binary:part(RestPayload, ClientIdLen, erlang:byte_size(RestPayload) - ClientIdLen),
    
    <<_PeerIdLen:8/integer, PeerId0/binary>> = RestPayload2,
    PeerId = erlang:binary_to_list(PeerId0),

    ok.
