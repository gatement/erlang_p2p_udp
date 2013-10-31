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

process_data_online(SourcePid, _Socket, Data, ClientId) ->
    {_, _, UserName, Password} = mqtt_utils:extract_connect_info(Data),
    %error_logger:info_msg("[~p] process_data_online(~p): ~p, username: ~p, password: ~p~n", [?MODULE, ClientId, SourcePid, UserName, Password]),

    Result = case {UserName, Password} of
        {undefined, _} ->
			{true, "anonymous"};
        {_, undefined} ->
			{true, "anonymous"};
        _ ->
            case model_usr_user:get(UserName, Password) of        
                [] ->
                    send_connack(SourcePid, ?BAD_USERNAME_OR_PASSWORD),
                    SourcePid ! {stop, bad_connect},
					false;

                [User] when User#usr_user.enabled /= true ->
                    send_connack(SourcePid, ?IDENTIFIER_REJECTED),
                    SourcePid ! {stop, bad_connect},
					false;

                [_User] ->
					{true, UserName}
            end
    end,

	case Result of
		false ->
			do_nothing;
		{true, UserName2} ->
			%% kick off the old session with the same ClientId
			case model_mqtt_session:get(ClientId) of
				undefined ->
					do_nothing;
				Model ->
					Model#mqtt_session.pid ! stop
			end,

			model_mqtt_session:delete(ClientId),

			model_mqtt_session:create(#mqtt_session{
				client_id = ClientId, 
				pid = SourcePid, 
				created = tools:datetime_string('yyyyMMdd_hhmmss')
			}),

			%% send CONNACK
			send_connack(SourcePid, ?ACCEPTED),

			%% publish client online(including IP) notice to subscribers
			mqtt_broker:publish(#publish_msg{
				from_client_id = "000000000000",
				from_user_id = "",
				exclusive_client_id = ClientId, 
				data = {online, {ClientId, UserName2}}
			}),

			%% send online push notification
			case model_dev_device:get_info(ClientId) of
				{undefined, _} -> do_nothing;
				{_, DeviceName} ->
					Msg = lists:flatten(io_lib:format("~s is online [~s]", [DeviceName, tools:datetime_string('hh:mm')])),
					mqtt_broker:send_msg(Msg)
			end,

			%% subscribe any PUBLISH starts with "/ClientId/"  
			subscribe_any_publish_to_me(ClientId),

			%% send stored publishments which are sent while I was offline
			send_pub_queues(SourcePid, ClientId)
	end,

    ok.


process_data_publish(_SourcePid, _Socket, Data, ClientId) ->
    {Topic, Payload} = mqtt_utils:extract_publish_info(Data),
    %error_logger:info_msg("[~p] process_data_publish(~p) topic: ~p, payload: <<~s>>~n", [?MODULE, ClientId, Topic, tools:binary_to_string(Payload)]),    
    %% publish it to subscribers
	mqtt_broker:publish(#publish_msg{
		from_client_id = "000000000000",
		from_user_id = "",
		exclusive_client_id = ClientId, 
		data = {publish, {Topic, Payload}}
	}),

    ok.


process_data_publish_ack(_SourcePid, _Socket, Data, ClientId) ->
    {MsgId} = mqtt_utils:extract_publish_ack_info(Data),
    %error_logger:info_msg("[~p] process_data_publish_ack(~p) msg id: ~p~n", [?MODULE, ClientId, MsgId]),    
	
    %% delete the corresponding mqtt_pub_queue record
	model_mqtt_pub_queue:delete_by_client_id_msg_id(ClientId, MsgId),

    ok.


terminate(SourcePid, Socket, ClientId, Reason) ->
    model_mqtt_session:delete_by_pid(SourcePid),
    %error_logger:info_msg("[~p] deleted mqtt session by pid: ~p~n", [?MODULE, SourcePid]), 

    {SendDisconnect, PublishOffline} = case Reason of
        %% no data come in after TCP was created
        connection_timout -> {false, false};
        %% user/pwd is missing or is bad
        bad_connect -> {false, false};
        %% did not receive client heartbeat within keep_alive_timer
        no_heartbeat -> {true, true};
        %% receive DISCONNECT msg
        disconnected -> {false, true};
        %% the TCP connection was closed
        tcp_closed -> {false, true}
    end,

    %% send DISCONNECT
    case SendDisconnect of
        false ->
            do_nothing;
        true ->
            DisconnectMsg = mqtt:build_disconnect(),
            gen_tcp:send(Socket, DisconnectMsg)
    end,

    %% pubish an offline notice to subscriber
    case PublishOffline of
        false ->
            do_nothing;
        true ->
			mqtt_broker:publish(#publish_msg{
				from_client_id = "000000000000",
				from_user_id = "",
				exclusive_client_id = ClientId, 
				data = {offline, {ClientId}}
			}),

			%% send offline push notification
			case model_dev_device:get_info(ClientId) of
				{undefined, _} -> do_nothing;
				{_, DeviceName} ->
					Msg = lists:flatten(io_lib:format("~s is offline [~s]", [DeviceName, tools:datetime_string('hh:mm')])),
					mqtt_broker:send_msg(Msg)
			end
    end,

    ok.


%% ===================================================================
%% Local Functions
%% ===================================================================

subscribe_any_publish_to_me(ClientId) ->
    Topic = lists:flatten(io_lib:format("/~s/+", [ClientId])),

    case model_mqtt_subscription:exist(ClientId, Topic) of
        true ->
            do_nothing;

        false ->
            model_mqtt_subscription:create(#mqtt_subscription{
                    id = uuid:to_string(uuid:uuid1()), 
                    client_id = ClientId, 
                    topic = Topic,
                    qos = 0,
					ttl = 0,
                    desc = "Publish to me",
					enabled = true
            })
    end.


send_pub_queues(SourcePid, ClientId) ->
	PubQueues = model_mqtt_pub_queue:get_by_clientId(ClientId),
    %error_logger:info_msg("[~p] send_pub_queues(~p): ~p~n", [?MODULE, ClientId, PubQueues]), 
	[SourcePid ! {send_tcp_data, X#mqtt_pub_queue.data} || X <- PubQueues],

	ok.


send_connack(SourcePid, Result) ->
    ConnackData = mqtt:build_connack(Result),
    SourcePid ! {send_tcp_data, ConnackData}.

