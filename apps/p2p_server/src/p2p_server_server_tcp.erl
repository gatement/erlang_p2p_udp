-module(p2p_server_server_tcp).
-include("p2p_server.hrl").
-behaviour(gen_server).
%% API
-export([start_link/1]).
%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).
-record(state, {
                lsocket,
                socket,
                parent
               }).


%% ===================================================================
%% API functions
%% ===================================================================

start_link(LSocket) ->
    gen_server:start_link(?MODULE, [LSocket, erlang:self()], []).


%% ===================================================================
%% gen_server callbacks
%% ===================================================================

%% -- init -----------
init([LSocket, Parent]) ->
    State = #state{
        lsocket = LSocket,
        parent = Parent
    },

    error_logger:info_msg("[~p] was started.~n", [?MODULE]),
    {ok, State, 0}.


%% -- call -----------
handle_call(_Msg, _From, State) ->
    error_logger:info_msg("[~p] was called: ~p.~n", [?MODULE, _Msg]),
    {reply, ok, State}.


%% -- cast ------------
handle_cast(_Msg, State) ->
    error_logger:info_msg("[~P] was casted: ~p.~n", [?MODULE, _Msg]),
    {noreply, State}.


%% -- info -------------
handle_info({tcp, _Socket, RawData}, State) ->
    error_logger:info_msg("[~p] received tcp data: ~p~n", [?MODULE, RawData]),
    {ok, State2} = handle_tcp_data(RawData, State),
    {noreply, State2};

handle_info({tcp_closed, _Socket}, State) ->
    error_logger:info_msg("[~p] was infoed: ~p.~n", [?MODULE, tcp_closed]),
    {stop, tcp_closed, State};

handle_info(timeout, State) ->    
    #state{
        lsocket = LSocket,
        socket = Socket0,
        parent = Parent
    } = State,

    State2 = case Socket0 of
        undefined ->
            {ok, Socket} = gen_tcp:accept(LSocket),
            supervisor:start_child(Parent, []),
            State#state{socket = Socket};
        _ ->
            State
    end,

    {noreply, State2};

handle_info({send_tcp_data, Data}, State) ->
    #state{
        socket = Socket
    } = State,

    gen_tcp:send(Socket, Data),

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
handle_tcp_data(RawData, State) ->
    <<Cmd:2/binary, Payload/binary>> = RawData,

    case Cmd of
        %% -- online ---------------
        <<16#00, 16#01>> -> 
            handle_data_online_req(Payload, State)
    end.


handle_data_online_req(Payload, State) ->
    #state{
        socket = Socket
    } = State,

    <<_ClientIdLen:8/integer, ClientId0/binary>> = Payload,
    ClientId = erlang:binary_to_list(ClientId0),

    case model_run_user:get_by_client_id(ClientId) of
        undefined ->
            SessionId = uuid:to_string(uuid:uuid1()), 
            model_run_user:create(#run_user{
                    id = SessionId, 
                    client_id = ClientId,
                    pid = erlang:self(),
					createdTime = tools:datetime_string('yyyyMMdd_hhmmss')
            }),

            %% success
            SessionIdLen = erlang:size(erlang:list_to_binary([SessionId])),
            SendingData = [16#00, 16#02, SessionIdLen, SessionId],
            gen_tcp:send(Socket, SendingData);
        _ ->
            %% fail
            SendingData = <<16#00, 16#03>>,
            gen_tcp:send(Socket, SendingData)
    end,

    {ok, State}.
