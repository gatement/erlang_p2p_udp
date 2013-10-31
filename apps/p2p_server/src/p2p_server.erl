-module(mqtt_broker).
-include("mqtt.hrl").
-include("../../platform_core/include/tools_platform.hrl").
%% API
-export([publish/1,
		send_msg/1,
		send_msg/2,
		send_persistence_msg/1,
		send_persistence_msg/2]).


%% ===================================================================
%% API functions
%% ===================================================================

publish(#publish_msg{
	from_client_id = FromClientId,
	from_user_id = FromUserId,
	exclusive_client_id = ExclusiveClientId, 
	data = Data}) ->

	%% generate Topic
    Topic = case Data of
		{send_command, {ClientId, _}} -> 
			lists:flatten(io_lib:format("/~s/cmd", [ClientId]));
		{switch_control, {ClientId, _, _}} -> 
			lists:flatten(io_lib:format("/~s/cmd", [ClientId]));
		{online, {ClientId, _}} -> 
			lists:flatten(io_lib:format("/~s/online", [ClientId]));
		{offline, {ClientId}} -> 
			lists:flatten(io_lib:format("/~s/offline", [ClientId]));
		{send_msg, {_}} -> 
			lists:flatten(io_lib:format("/~s/msg", ["000000000001"]));
		{send_persistence_msg, {_}} -> 
			lists:flatten(io_lib:format("/~s/persistence_msg", ["000000000001"]));
		{publish, {Topic0, _}} -> 
			Topic0
	end,
	%error_logger:info_msg("[~p] topic: ~p.~n", [?MODULE, Topic]),

	%% does sender have permission or not
	case model_mqtt_pub_permission:exist(FromClientId, FromUserId, Topic, true) of
		false ->
			error_logger:info_msg("[~p] no permission: FromClientId:~p, FromUserId:~p, Topic:~p~n", [?MODULE, FromClientId, FromUserId, Topic]),
			no_permission;

		true ->
			%% get subscriptions
			Subs = model_mqtt_subscription:get_subscription_client_ids(ExclusiveClientId, Topic),
			%error_logger:info_msg("[~p] subs: ~p.~n", [?MODULE, Subs]),

			Fun = fun(Sub) ->
				Qos = Sub#mqtt_subscription.qos,
				ToClientId = Sub#mqtt_subscription.client_id,

				%% get publish data
				{MsgId, PublishData} = case Data of
					{send_command, {_ClientId, Cmd}} -> 
						mqtt_cmd:send_command(ToClientId, Topic, Qos, Cmd); 
					{switch_control, {_ClientId, SwitchId, Value}} -> 
						mqtt_cmd:switch_control(ToClientId, Topic, Qos, SwitchId, Value); 
					{online, {_ClientId, UserName}} -> 
						mqtt_cmd:online(ToClientId, Topic, Qos, UserName);
					{offline, {_ClientId}} -> 
						mqtt_cmd:offline(ToClientId, Topic, Qos);
					{send_msg, {Msg}} -> 
						mqtt_cmd:send_msg(ToClientId, Topic, Qos, Msg);
					{send_persistence_msg, {Msg}} -> 
						mqtt_cmd:send_msg(ToClientId, Topic, Qos, Msg);
					{publish, {_Topic, Payload}} -> 
						mqtt_cmd:build_publish(ToClientId, Topic, Payload, Qos)
				end,
				
				%% send publish
				case model_mqtt_session:get(Sub#mqtt_subscription.client_id) of
					undefined -> ignore;
					error -> ignore;
					Session -> 
						Pid = Session#mqtt_session.pid,
						case tools:is_pid_alive(Pid) of
							false -> ignore;
							true -> Pid ! {send_tcp_data, PublishData}
						end
				end,

				%% store publis if need
				case Qos of
					0 -> do_nothing;
					_ ->
						Expired = tools:epoch_seconds() + Sub#mqtt_subscription.ttl, 
						SubQueueId = tools:generate_id(ToClientId),

						%error_logger:info_msg("[~p] create sub_queue, topic: ~p, queueId: ~p, clientId: ~p, msgId: ~p, expired: ~p.~n", [?MODULE, Topic, SubQueueId, ToClientId, MsgId, Expired]),

						model_mqtt_pub_queue:create(#mqtt_pub_queue{
							id = SubQueueId,
							client_id = ToClientId,
							msg_id = MsgId,
							expired = Expired,
							data = PublishData
						})
				end
			end,

			lists:foreach(Fun, Subs)
	end.


send_msg(Msg) ->
	%error_logger:info_msg("[~p] send_msg: ~p.~n", [?MODULE, Msg]),
	{ok, UserId} = application:get_env(mqtt_broker, default_push_notification_user),
	send_msg(UserId, Msg).


send_msg(UserId, Msg) ->
	%error_logger:info_msg("[~p] send_msg: ~p.~n", [?MODULE, Msg]),
    ?MODULE:publish(#publish_msg{
		from_client_id = "000000000001",
		from_user_id = UserId,
		exclusive_client_id = "000000000001", 
		data = {send_msg, {Msg}}
	}).


send_persistence_msg(Msg) ->
	%error_logger:info_msg("[~p] send_persistence_msg: ~p.~n", [?MODULE, Msg]),
	{ok, UserId} = application:get_env(mqtt_broker, default_push_notification_user),
	send_persistence_msg(UserId, Msg).


send_persistence_msg(UserId, Msg) ->
	%error_logger:info_msg("[~p] send_persistence_msg: ~p.~n", [?MODULE, Msg]),
    ?MODULE:publish(#publish_msg{
		from_client_id = "000000000001",
		from_user_id = UserId,
		exclusive_client_id = "000000000001", 
		data = {send_persistence_msg, {Msg}}
	}).


%% ===================================================================
%% Local Functions
%% ===================================================================
