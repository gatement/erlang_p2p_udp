-module(mqtt_broker_handler).
-behaviour(gen_tcp_server).
%% gen_tcp_server callbacks
-export([
    process_data_online/4, 
    process_data_offline/4, 
    process_data_publish/4, 
    terminate/4]).


%% ===================================================================
%% gen_tcp_server callbacks
%% ===================================================================

process_data_online(SourcePid, _Socket, _Data, ClientId) ->
    error_logger:info_msg("[~p] process_data_online(~p): ~p~n", [?MODULE, ClientId, SourcePid]).

process_data_offline(SourcePid, _Socket, _Data, ClientId) ->
    error_logger:info_msg("[~p] process_data_offline(~p): ~p~n", [?MODULE, ClientId, SourcePid]).

process_data_publish(SourcePid, _Socket, _Data, ClientId) ->
    error_logger:info_msg("[~p] process_data_publish(~p): ~p~n", [?MODULE, ClientId, SourcePid]).

terminate(SourcePid, _Socket, ClientId, _Reason) ->
    error_logger:info_msg("[~p] process_data_terminate(~p): ~p~n", [?MODULE, ClientId, SourcePid]).


%% ===================================================================
%% Local Functions
%% ===================================================================

