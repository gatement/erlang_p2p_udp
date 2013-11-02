-module(p2p_client_server).
-behaviour(gen_server).
%% API
-export([start_link/0]).
%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).
-record(state, {
                client_id,
                keep_alive_timer,
                socket
               }).

-define(SERVER, ?MODULE).
-define(REQ_TIMEOUT, 3000).

%% ===================================================================
%% API functions
%% ===================================================================

start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).


%% ===================================================================
%% gen_server callbacks
%% ===================================================================

init([]) ->
    {ok, KeepAliveTimer} = application:get_env(keep_alive_timer),
    State = #state{
        keep_alive_timer = KeepAliveTimer
    },

    error_logger:info_msg("[~p] was started.~n", [?MODULE]),
    {ok, State, 0}.


handle_call({connect, ClientId}, _From, State) ->
    handle_connect_req(State, ClientId);

handle_call(_Msg, _From, State) ->
    error_logger:info_msg("[~p] was called: ~p.~n", [?MODULE, _Msg]),
    {reply, ok, State}.


handle_cast(_Msg, State) ->
    error_logger:info_msg("[~P] was casted: ~p.~n", [?MODULE, _Msg]),
    {noreply, State}.


handle_info({tcp, _Socket, RawData}, State) ->
    error_logger:info_msg("[~p] received tcp data: ~p~n", [?MODULE, RawData]),
    dispatch(handle_data, RawData, State);

handle_info({tcp_closed, _Socket}, State) ->
    error_logger:info_msg("[~p] was infoed: ~p.~n", [?MODULE, tcp_closed]),
    {stop, tcp_closed, State};

handle_info(timeout, #state{socket = Socket0} = State) ->    
    case Socket0 of
        undefined ->
            %do_nothing;
            {noreply, State};
        _Socket ->
            %do_heardbeat
            {noreply, State}
    end;

handle_info({send_tcp_data, Data}, #state{socket = Socket} = State) ->
    error_logger:info_msg("[~p] send to socket ~p with data: ~p~n", [?MODULE, Socket, Data]),
    gen_tcp:send(Socket, Data),
    {noreply, State, State#state.keep_alive_timer};

handle_info({stop, Reason}, State) ->
    error_logger:info_msg("[~p] process ~p was stopped: ~p~n", [?MODULE, erlang:self(), Reason]),
    {stop, Reason, State};
    
handle_info(_Msg, State) ->
    error_logger:info_msg("[~p] was infoed: ~p.~n", [?MODULE, _Msg]),
    {noreply, State, State#state.keep_alive_timer}.


terminate(Reason, State) ->
    error_logger:info_msg("[~p] ~p was terminated with reason: ~p.~n", [?MODULE, State#state.socket, Reason]),
    dispatch(terminate, State, Reason),
    ok.


code_change(_OldVsn, State, _Extra) ->
    {ok, State}.


%% ===================================================================
%% Local Functions
%% ===================================================================

dispatch(handle_data, RawData, State) ->
    handle_recved_packages(State, RawData);

dispatch(terminate, State, Reason) ->
    #state{socket = Socket, client_id = ClientId} = State,
    p2p_client_handler:terminate(erlang:self(), Socket, ClientId, Reason),
    ok.


handle_recved_packages(State, <<>>) ->
    {noreply, State, State#state.keep_alive_timer};

handle_recved_packages(State, RawData) ->
    #state{
        socket = Socket, 
        client_id = ClientId} = State,

    <<TypeCode:1/binary, DataLen:16/integer, _/binary>> = RawData,
    PackData = binary:part(RawData, 3, DataLen), 

    Result = case TypeCode of
        <<16#01>> -> 
            p2p_client_handler:process_data_online(erlang:self(), Socket, PackData, ClientId),
            ok;

        <<16#02>> -> 
            p2p_client_handler:process_data_offline(erlang:self(), Socket, PackData, ClientId),
            disconnect;

        <<16#03>> -> 
            p2p_client_handler:process_data_publish(erlang:self(), Socket, PackData, ClientId),
            ok;

        <<16#04>> -> 
            error_logger:info_msg("[~p] is pingging (~p)~n", [ClientId, erlang:self()]),
            gen_tcp:send(Socket, <<16#03, 16#02>>),
            ok
    end,

    case Result of
        disconnect ->
            {stop, disconnected, State};

        ok ->
            RestRawData = binary:part(RawData, 3 + DataLen, erlang:byte_size(RawData) - 3 - DataLen),
            handle_recved_packages(State, RestRawData)
    end.


handle_connect_req(State, ClientId) ->
    {ok, ServerHost} = application:get_env(tcp_host),
    {ok, ServerPort} = application:get_env(tcp_port),
    case gen_tcp:connect(ServerHost, ServerPort, [binary, {active, true}]) of
        {ok, Socket} ->
            send_data(Socket, 16#01, ClientId),

            %% waiting for response
            receive
                {tcp, Socket, Msg} -> 
                    error_logger:info_msg("[~p] received tcp data(~p): ~p~n", [?MODULE, Socket, Msg]),
                    case Msg of
                        <<16#01, 16#01, 16#00>> ->            
                            State2 = State#state{socket = Socket, client_id=ClientId},            
                            {reply, ok, State2};
                        _ ->
                            {reply, bad_conn_ack, State}
                    end
            after ?REQ_TIMEOUT ->
                    gen_tcp:close(Socket),
                    {reply, no_conn_ack, State}
            end;
        _ ->
            {reply, conn_failed, State}
    end.


%% data length must <= 255 bytes
send_data(Socket, Cmd, Data) ->
    Data2 = [Cmd, erlang:size(erlang:list_to_binary([Data])), Data],
    gen_tcp:send(Socket, Data2),
    error_logger:info_msg("[~p] sent data(~p): ~p~n", [?MODULE, Socket, Data2]).
