-module(p2p_server_handler).
-include("p2p_server.hrl").
-export([
    process_data_online/3, 
    process_data_publish/4, 
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
            Data = [16#01, 16#01, 16#00],
            gen_tcp:send(Socket, Data);
        _ ->
            Data = [16#01, 16#01, 16#01],
            gen_tcp:send(Socket, Data),
            gen_tcp:close(Socket)
    end.


process_data_publish(SourcePid, _Socket, _Data, ClientId) ->
    error_logger:info_msg("[~p] process_data_publish(~p): ~p~n", [?MODULE, ClientId, SourcePid]).


terminate(SourcePid, _Socket, ClientId, Reason) ->
    error_logger:info_msg("[~p] process_data_terminate(~p): ~p~n", [?MODULE, ClientId, Reason]),
    model_run_user:delete_by_pid(SourcePid).


%% ===================================================================
%% Local Functions
%% ===================================================================

