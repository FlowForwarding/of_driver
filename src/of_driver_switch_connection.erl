-module(of_driver_switch_connection).

-include_lib("of_driver/include/of_driver.hrl").

-export([ 
	insert_switch_connection/3,
	remove_swtich_connection/2,
	lookup_connection_pid/1
]).

insert_switch_connection(IpAddr,Port,ConnectionPID) ->
	true = ets:insert_new(?SWITCH_CONN_TBL,{{IpAddr,Port},ConnectionPID}),
	ok.

remove_swtich_connection(IpAddr,Port) ->
	true = ets:delete(?SWITCH_CONN_TBL,{IpAddr,Port}),
	ok.

lookup_connection_pid(IpAddr) ->
	%% ets:lookup(?SWITCH_CONN_TBL,IpAddr).
	case ets:match(?SWITCH_CONN_TBL,{{IpAddr,'$1'},'$2'}) of
		[] ->
			[];
		[[Port,ConnectionPid]] ->
			[Port,ConnectionPid]
	end.