-module (of_driver_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("of_protocol/include/of_protocol.hrl").
-include_lib("of_driver/include/of_driver_acl.hrl").

%%------------------------------------------------------------------------------

of_driver_test_() ->
	{setup,
     fun() -> 

			application:unset_env(of_driver,switch_handler),
			application:unset_env(of_driver,init_opt),

             application:stop(mnesia),
             mnesia:delete_schema([node()]),
             application:start(mnesia),
             of_driver_db:install(),

			{ok,_Pid1} = of_driver_app:start([],[]),

			%% start stub, that mimics LINC ...
			{ok,_Pid2} = of_driver_tcp_stub:start(),

			IpAddr={127,0,0,1},
			ok = of_driver:grant_ipaddr(IpAddr,echo_handler,[{enable_ping,false},
            	        		     					  {ping_timeout,5000},
                	    								  {ping_idle,5000},
                    									  {multipart_timeout,30000}]),
			timer:sleep(500),
			[[_Port,ConnectionPid,_ConnRole]] = of_driver_switch_connection:lookup_connection_pid(IpAddr)

     end,
     fun(_) -> 
             try gen_server:call(of_driver_tcp_stub,stop) catch _C1:_E1 -> ok end,
             ok
     end,
     {inorder,[
				{"grant_ipaddr",        fun grant_ipaddr/0},
				{"revoke_ipaddr",       fun revoke_ipaddr/0},
				{"get_allowed_ipaddrs", fun get_allowed_ipaddrs/0},
				{"set_allowed_ipaddrs", fun set_allowed_ipaddrs/0},
				{"send",                fun send/0},
				{"sync_send",           fun sync_send/0},
				{"send_list",           fun send_list/0},
				{"sync_send_list",      fun sync_send_list/0},
				{"close_connection",    fun close_connection/0},
				{"close_ipaddr",        fun close_ipaddr/0},
				{"set_xid",             fun set_xid/0},
				{"gen_xid",             fun gen_xid/0}
              ]}
	}.

%%------------------------------------------------------------------------------

grant_ipaddr() ->
	delete_entries(),
	?assertEqual(ok,
		of_driver:grant_ipaddr({10,10,10,10}) ),
	?assertEqual({error,einval},
		of_driver:grant_ipaddr(obviously_wrong) ),
	?assertEqual({error,einval},
		of_driver:grant_ipaddr(11111111) ),
	?assertEqual(ok,
		of_driver:grant_ipaddr("12.12.12.12") ),

	R1 = #of_driver_acl{ip_address={10,10,10,10}, switch_handler=of_driver_default_handler, opts=[]},
	R2 = #of_driver_acl{ip_address={12,12,12,12}, switch_handler=of_driver_default_handler, opts=[]},

	?assertEqual({true,R1},
		of_driver:allowed_ipaddr({10,10,10,10}) ),
	?assertEqual({true,R2},
		of_driver:allowed_ipaddr({12,12,12,12}) ),

	?assertEqual([R1],
		mnesia:dirty_read(of_driver_acl,{10,10,10,10}) ),
	?assertEqual([R2],
		mnesia:dirty_read(of_driver_acl,{12,12,12,12}) ).


revoke_ipaddr() ->
	delete_entries(),
	?assertEqual(ok,
		of_driver:grant_ipaddr({10,10,10,10}) ),
	?assertEqual(ok,
		of_driver:grant_ipaddr({12,12,12,12}) ),

	R1 = #of_driver_acl{ip_address={10,10,10,10}, switch_handler=of_driver_default_handler, opts=[]},
	R2 = #of_driver_acl{ip_address={12,12,12,12}, switch_handler=of_driver_default_handler, opts=[]},

	?assertEqual({true,R1},
		of_driver:allowed_ipaddr({10,10,10,10}) ),
	?assertEqual({true,R2},
		of_driver:allowed_ipaddr({12,12,12,12}) ),

	?assertMatch([R1],
		mnesia:dirty_read(of_driver_acl,{10,10,10,10}) ),
	?assertMatch([R2],
		mnesia:dirty_read(of_driver_acl,{12,12,12,12}) ),

	?assertEqual(ok,
		of_driver:revoke_ipaddr({10,10,10,10}) ),
	?assertEqual({error,einval},
		of_driver:revoke_ipaddr("obviously_wrong...") ),

	?assertEqual([],
		mnesia:dirty_read(of_driver_acl,{10,10,10,10}) ),
	?assertEqual([R2],
		mnesia:dirty_read(of_driver_acl,{12,12,12,12}) ),

	?assertEqual(false,
		of_driver:allowed_ipaddr({10,10,10,10}) ),
	?assertEqual({true,R2},
		of_driver:allowed_ipaddr({12,12,12,12}) ).


get_allowed_ipaddrs() ->
	delete_entries(),

	R1 = #of_driver_acl{ip_address={10,10,10,10}, switch_handler=of_driver_default_handler, opts=[]},
	R2 = #of_driver_acl{ip_address={12,12,12,12}, switch_handler=of_driver_default_handler, opts=[]},

	?assertEqual(ok,
		of_driver:grant_ipaddr({10,10,10,10}) ),
	?assertEqual(ok,
		of_driver:grant_ipaddr({12,12,12,12}) ),
	?assertEqual([R1,R2], 
	 	lists:sort( of_driver:get_allowed_ipaddrs() ) ).


set_allowed_ipaddrs() ->
	delete_entries(),
	[] = of_driver:set_allowed_ipaddrs([ 
		{{10,10,10,10}, switch_handler, [{ping,5}] },
		{{12,12,12,12}, switch_handler2, [{ping,10}] },
		{{14,14,14,14}, switch_handler3, [{ping,15}] }
	]),

	E1 = #of_driver_acl{ip_address={10,10,10,10}, switch_handler=switch_handler, opts=[{ping,5}]},
	E2 = #of_driver_acl{ip_address={12,12,12,12}, switch_handler=switch_handler2, opts=[{ping,10}]},
	E3 = #of_driver_acl{ip_address={14,14,14,14}, switch_handler=switch_handler3, opts=[{ping,15}]},

	?assertEqual([E1,E2,E3],
		lists:sort( of_driver:get_allowed_ipaddrs() ) ),
	ok.

send() ->
	of_driver_tcp_stub:clear_message_heap(),
	{ok,[]} = of_driver_tcp_stub:get_message_heap(),

	Msg = of_driver_utils:create_hello(4),
	[[_Port,ConnectionPid,_ConnRole]] = of_driver_switch_connection:lookup_connection_pid({127,0,0,1}),
	ok = of_driver:send(ConnectionPid, Msg),
	timer:sleep(200),
	% %% ASK STUB FOR MESSAGE BOX...
	{ok,[{ofp_message,4,hello,0,{ofp_hello,[{versionbitmap,[4]}]}} 
	    ]} = of_driver_tcp_stub:get_message_heap(),
 	true.

send_list() ->
	of_driver_tcp_stub:clear_message_heap(),
	{ok,[]} = of_driver_tcp_stub:get_message_heap(),

	Msg = of_driver_utils:create_hello(4),
	[[_Port,ConnectionPid,_ConnRole]] = of_driver_switch_connection:lookup_connection_pid({127,0,0,1}),
	ok = of_driver:send_list(ConnectionPid, [Msg,Msg,Msg]),
	timer:sleep(1000),
	{ok,[{ofp_message,4,hello,0,{ofp_hello,[{versionbitmap,[4]}]}},
 	     {ofp_message,4,hello,0,{ofp_hello,[{versionbitmap,[4]}]}},
 	     {ofp_message,4,hello,0,{ofp_hello,[{versionbitmap,[4]}]}}
 	    ]} = of_driver_tcp_stub:get_message_heap(),
  	true.

sync_send() ->
	of_driver_tcp_stub:clear_message_heap(),
	[[_Port,ConnectionPid,_ConnRole]] = of_driver_switch_connection:lookup_connection_pid({127,0,0,1}),
	Msg = of_msg_lib:get_features(4),
	{ok,[ReplyMsg1]} = of_driver:sync_send(ConnectionPid, Msg),
	?assertEqual(features_reply,ReplyMsg1#ofp_message.type),
	true.

sync_send_list() ->
	of_driver_tcp_stub:clear_message_heap(),
	[[_Port,ConnectionPid,_ConnRole]] = of_driver_switch_connection:lookup_connection_pid({127,0,0,1}),
	Msg = of_msg_lib:get_features(4),
	{ok,[ReplyMsg1,ReplyMsg2]} = of_driver:sync_send_list(ConnectionPid, [Msg,Msg]),
	?assertEqual(features_reply,ReplyMsg1#ofp_message.type),
	?assertEqual(features_reply,ReplyMsg2#ofp_message.type),
	true.

close_connection() ->
	IpAddr={127,0,0,1},
	ok = of_driver:grant_ipaddr(IpAddr,echo_handler,[{enable_ping,false},
                    							     {ping_timeout,5000},
                    								 {ping_idle,5000},
                    								 {multipart_timeout,30000}]),
	%% start stub, that mimics LINC ...
	[[_Port,ConnectionPid,_ConnRole]] = of_driver_switch_connection:lookup_connection_pid(IpAddr),
	ok = of_driver:close_connection(ConnectionPid),
	true.

close_ipaddr() ->
	true.

set_xid() ->
	true.

gen_xid() ->
	true.

%%------------------------------------------------------------------------------

delete_entries() ->
    [ begin 
          [ mnesia:dirty_delete(Tbl,Key) || Key <- mnesia:dirty_all_keys(Tbl) ]
      end || Tbl <- [?ACL_TBL]
    ].
