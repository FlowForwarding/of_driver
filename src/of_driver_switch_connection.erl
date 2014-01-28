-module(of_driver_switch_connection).

-include_lib("of_driver/include/of_driver.hrl").

-export([ 
	insert_switch_connection/4,
	remove_switch_connection/2,
	lookup_connection_pid/1,
	main_pid/1
]).

insert_switch_connection(IpAddr,Port,ConnectionPID,ConnRole) ->
	true = ets:insert_new(?SWITCH_CONN_TBL,{{IpAddr,Port},ConnectionPID,ConnRole}),
	ok.

remove_switch_connection(IpAddr,Port) ->
	true = ets:delete(?SWITCH_CONN_TBL,{IpAddr,Port}),
	ok.

lookup_connection_pid(IpAddr) ->
	ets:match(?SWITCH_CONN_TBL,{{IpAddr,'$1'},'$2','$3'}).

main_pid(IpAddr) ->
	case ets:match(?SWITCH_CONN_TBL,{{IpAddr,'$1'},'$2','$3'}) of 
		[] ->
			false;
		Entries ->
			find_main(Entries)
	end.

find_main([]) ->
	false;
find_main([H=[_Port,Pid,main]|T]) ->
	H;
find_main([H=[_Port,Pid,aux]|T]) ->
	find_main(T).