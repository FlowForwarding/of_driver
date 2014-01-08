-module (of_driver_tests).

-include_lib("eunit/include/eunit.hrl").

%%------------------------------------------------------------------------------

of_driver_tests_() ->
	{setup,
     fun() -> 
             ok
     end,
     fun(_) -> 
             ok
     end,
     {inorder,[
				{"grant_ipaddr", fun grant_ipaddr/0},
				{"revoke_ipaddr", fun revoke_ipaddr/0},
				{"get_allowed_ipaddrs", fun get_allowed_ipaddrs/0},
				{"set_allowed_ipaddrs", fun set_allowed_ipaddrs/0},
				{"send", fun send/0},
				{"sync_send", fun sync_send/0},
				{"send_list", fun send_list/0},
				{"sync_send_list", fun sync_send_list/0},
				{"close_connection", fun close_connection/0},
				{"close_ipaddr", fun close_ipaddr/0},
				{"set_xid", fun set_xid/0},
				{"gen_xid", fun gen_xid/0}
              ]}
	}.

%%------------------------------------------------------------------------------

grant_ipaddr() ->
	ok = of_driver:grant_ipaddr({10,10,10,10}}),
	{error,einval} = of_driver:grant_ipaddr(obviously_wrong),
	{error,einval} = of_driver:grant_ipaddr(11111111),
	{error,einval} = of_driver:grant_ipaddr("12.12.12.12"),



	ok.

revoke_ipaddr() ->
	ok.

get_allowed_ipaddrs() ->
	ok.

set_allowed_ipaddrs() ->
	ok.

send() ->
	ok.

sync_send() ->
	ok.

send_list() ->
	ok.

sync_send_list() ->
	ok.

close_connection() ->
	ok.

close_ipaddr() ->
	ok.

set_xid() ->
	ok.

gen_xid() ->
	ok.

%%------------------------------------------------------------------------------

