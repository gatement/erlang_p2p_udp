-module(p2p_server_handler).
-include("p2p_server.hrl").
-export([
    process_data_online/3, 
    process_data_connect_to_peer_req/4, 
    process_data_connect_to_peer_res/4, 
    terminate/4]).


%% ===================================================================
%% gen_tcp_server callbacks
%% ===================================================================

process_data_online(SourcePid, Socket, ClientId) ->
    error_logger:info_msg("[~p] process_data_online(~p): ~p~n", [?MODULE, ClientId, SourcePid]),
    case model_run_user:get(ClientId) of
        undefined ->
            model_run_user:create(#run_user{
                    id = ClientId, 
                    pid = SourcePid, 
					createdTime = tools:datetime_string('yyyyMMdd_hhmmss')
            }),
            %% success
            SendingData = <<16#01, 16#01, 16#00>>,
            gen_tcp:send(Socket, SendingData);
        _ ->
            %% Fail
            SendingData = <<16#01, 16#01, 16#01>>,
            gen_tcp:send(Socket, SendingData),
            gen_tcp:close(Socket)
    end.


process_data_connect_to_peer_req(Socket, Data, ClientId, Ip) ->
    error_logger:info_msg("[~p] process_data_connect_to_peer_req(~p): ~p~n", [?MODULE, ClientId, Data]),
    <<PeerPortH:8/integer, PeerPortL:8/integer, PeerClientId0/binary>> = Data,
    PeerClientId = erlang:binary_to_list(PeerClientId0),

    case model_run_user:get(PeerClientId) of
        error ->
            %% db error
            SendingData = <<16#05, 16#01, 16#01>>,
            gen_tcp:send(Socket, SendingData);
        undefined ->
            %% peer offline
            SendingData = <<16#05, 16#01, 16#01>>,
            gen_tcp:send(Socket, SendingData);
        Peer ->
            {Ip1, Ip2, Ip3, Ip4} = Ip,
            SendingDataLen = erlang:size(erlang:list_to_binary([ClientId])) + 6,
            SendingData = [16#03, SendingDataLen, Ip1, Ip2, Ip3, Ip4, PeerPortH, PeerPortL, ClientId],
            gen_server:cast(Peer#run_user.pid, {send_tcp_data, SendingData})
    end.


process_data_connect_to_peer_res(Socket, Data, ClientId, Ip) ->
    error_logger:info_msg("[~p] process_data_connect_to_peer_res(~p): ~p~n", [?MODULE, ClientId, Data]),
    <<PeerPortH:8/integer, PeerPortL:8/integer, PeerClientId0/binary>> = Data,
    PeerClientId = erlang:binary_to_list(PeerClientId0),

    case model_run_user:get(PeerClientId) of
        error ->
            %% db error
            SendingData = <<16#05, 16#01, 16#01>>,
            gen_tcp:send(Socket, SendingData);
        undefined ->
            %% peer offline
            SendingData = <<16#05, 16#01, 16#01>>,
            gen_tcp:send(Socket, SendingData);
        Peer ->
            {Ip1, Ip2, Ip3, Ip4} = Ip,
            SendingDataLen = erlang:size(erlang:list_to_binary([ClientId])) + 7,
            SendingData = [16#05, SendingDataLen, 16#00, Ip1, Ip2, Ip3, Ip4, PeerPortH, PeerPortL, ClientId],
            gen_server:cast(Peer#run_user.pid, {send_tcp_data, SendingData})
    end.


terminate(SourcePid, _Socket, ClientId, Reason) ->
    error_logger:info_msg("[~p] process_data_terminate(~p): ~p~n", [?MODULE, ClientId, Reason]),
    model_run_user:delete_by_pid(SourcePid).


%% ===================================================================
%% Local Functions
%% ===================================================================

