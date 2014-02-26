-module (of_driver_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("of_protocol/include/of_protocol.hrl").
-include_lib("of_protocol/include/ofp_v4.hrl").

-define(LISTEN_PORT, 15578).
-define(DATAPATH_ID, 0).
-define(DATAPATH_MAC, <<8,0,39,150,212,121>>).

%%------------------------------------------------------------------------------

of_driver_test_() ->
    {setup,
     fun setup/0,
     fun cleanup/1,
     fun(S) ->
        {foreach, fun test_setup/0,
         [{"set_xid",             fun set_xid/0},
          {"gen_xid",             fun gen_xid/0},
          {"main_connect", fun main_connect/0},
          {"main_terminate", fun main_terminate/0},
          {"early_message", fun early_message/0},
          {"close_connection", fun close_connection/0}|
          [{N, fun() -> F(S) end}
                     || {N, F} <- [
                                   {"aux_connect", fun aux_connect/1}
                                  ,{"in_message", fun in_message/1}
                                  ,{"send", fun send/1}
                                  ,{"sync_send", fun sync_send/1}
                                  ,{"sync_send_no_reply", fun sync_send_no_reply/1}
                                  ,{"sync_send_non_reply", fun sync_send_non_reply/1}
                                  ,{"send_list", fun send_list/1}
                                  ,{"sync_send_list", fun sync_send_list/1}
                                  ,{"sync_send_list_no_reply", fun sync_send_list_no_reply/1}
                                  ,{"multiple_sync_send", fun multiple_sync_send/1}
                                  ]]]} end
    }.

% XXX messages that can't be encoded

setup() ->
%   trace(),
    ok = meck:new(of_driver_handler_mock, [passthrough]),
    ConnTable = ets:new(conn_table, [set, public]),
    [application:set_env(of_driver, K, V) || {K, V} <-
                                [{callback_module, of_driver_handler_mock},
                                 {listen_port, ?LISTEN_PORT},
                                 {init_opt, ConnTable}]],
    ok = application:start(eenum),
    ok = application:start(of_protocol),
    ok = application:start(lager),
    ok = application:start(of_driver),
    Socket = connect(),
    {Socket, ConnTable}.

cleanup({Socket, _ConnTable}) ->
    ok = gen_tcp:close(Socket),
    % wait for of_driver to exit before unloading mocks
    meck:wait(of_driver_handler_mock, terminate, '_', 1000),
    meck:unload().

test_setup() ->
    meck:reset(of_driver_handler_mock).

trace() ->
    dbg:start(),
    dbg:tracer(),
    dbg:p(all, c)
    % ,dbg:tpl(ofp_v4_encode, [])
    % ,dbg:tpl(ofp_v4_encode, [{'_', [], [{return_trace}]}])
    % ,dbg:tpl(of_driver_utils, [])
    % ,dbg:tpl(of_driver_connection, [])
    ,dbg:tpl(of_driver_datapath, [])
    % ,dbg:tpl(gen_tcp, [])
    % ,dbg:tpl(gen_tcp, [{'_', [], [{return_trace}]}])
    % ,dbg:tpl(?MODULE, [])
    .

%%------------------------------------------------------------------------------

set_xid() ->
    true.

gen_xid() ->
    true.

main_connect() ->
    ExpectedDatapathId = 1,
    meck:expect(of_driver_handler_mock, init,
        fun(_IpAddr, DatapathId, Features, Version, _Connection, _Opt) ->
            ?assertMatch(#ofp_features_reply{ 
                            datapath_mac = ?DATAPATH_MAC,
                            datapath_id = ExpectedDatapathId}, Features),
            ?assertEqual(DatapathId, {ExpectedDatapathId, ?DATAPATH_MAC}),
            ?assertEqual(Version, ?VERSION),
            {ok, callback_state} end),
    meck:expect(of_driver_handler_mock, terminate, fun(_Reason, callback_state) -> ok end),
    Socket = connect(ExpectedDatapathId),
    gen_tcp:close(Socket),
    ?assert(meck:validate(of_driver_handler_mock)).

main_terminate() ->
    ExpectedDatapathId = 1,
    ExpectedAuxId = 1,
    meck:expect(of_driver_handler_mock, init,
        fun(_IpAddr, DatapathId, Features, Version, _Connection, _Opt) ->
            ?assertMatch(#ofp_features_reply{ 
                            datapath_mac = ?DATAPATH_MAC,
                            datapath_id = ExpectedDatapathId}, Features),
            ?assertEqual(DatapathId, {ExpectedDatapathId, ?DATAPATH_MAC}),
            ?assertEqual(Version, ?VERSION),
            {ok, callback_state} end),
    meck:expect(of_driver_handler_mock, terminate, fun(_Reason, callback_state) -> ok end),
    meck:expect(of_driver_handler_mock, handle_connect,
        fun(_IpAddr, DatapathId, Features, Version, _Connection, AuxId, _Opt) ->
            ?assertMatch(#ofp_features_reply{ 
                            datapath_mac = ?DATAPATH_MAC,
                            datapath_id = ExpectedDatapathId}, Features),
            ?assertEqual(DatapathId, {ExpectedDatapathId, ?DATAPATH_MAC}),
            ?assertEqual(Version, ?VERSION),
            ?assertEqual(AuxId, ExpectedAuxId),
            {ok, aux_callback_state} end),
    meck:expect(of_driver_handler_mock, handle_disconnect, fun(_Reason, aux_callback_state) -> ok end),
    Socket = connect(ExpectedDatapathId),
    _AuxSocket = connect(ExpectedDatapathId, ExpectedAuxId),
    gen_tcp:close(Socket),
    ?assert(meck:validate(of_driver_handler_mock)).

early_message() ->
    ExpectedDatapathId = 1,
    meck:expect(of_driver_handler_mock, init,
        fun(_IpAddr, DatapathId, Features, Version, _Connection, _Opt) ->
            ?assertMatch(#ofp_features_reply{ 
                            datapath_mac = ?DATAPATH_MAC,
                            datapath_id = ExpectedDatapathId}, Features),
            ?assertEqual(DatapathId, {ExpectedDatapathId, ?DATAPATH_MAC}),
            ?assertEqual(Version, ?VERSION),
            {ok, callback_state} end),
    meck:expect(of_driver_handler_mock, terminate, fun(_Reason, callback_state) -> ok end),
    {ok, Socket} = gen_tcp:connect({127,0,0,1}, ?LISTEN_PORT,
                                            [binary, {active, false}], 5000),
    send_msg(Socket, packet_in()),
    send_msg(Socket, of_driver_utils:create_hello([?VERSION])),
    {#ofp_message{type = hello}, Rest} = receive_msg(Socket, <<>>),
    {#ofp_message{type = features_request, xid = FXID}, <<>>} = receive_msg(Socket, Rest),
    send_msg(Socket, packet_in()),
    send_msg(Socket, features_reply(FXID, ExpectedDatapathId, 0)),
    gen_tcp:close(Socket),
    ?assert(meck:validate(of_driver_handler_mock)).

close_connection() ->
    ExpectedDatapathId = 1,
    Me = self(),
    meck:expect(of_driver_handler_mock, init,
        fun(_IpAddr, _DatapathId, _Features, _Version, Connection, _Opt) ->
            Me ! {connection, Connection},
            {ok, callback_state} end),
    meck:expect(of_driver_handler_mock, terminate, fun(_Reason, callback_state) -> ok end),
    _Socket = connect(ExpectedDatapathId),
    Conn = receive
        {connection, C} ->
            C
    end,
    of_driver:close_connection(Conn),
    ?assert(meck:validate(of_driver_handler_mock)).

aux_connect({_Socket, _ConnTable}) ->
    ExpectedAuxId = 1,
    meck:expect(of_driver_handler_mock, handle_connect,
        fun(_IpAddr, DatapathId, Features, Version, _Connection, AuxId, _Opt) ->
            ?assertMatch(#ofp_features_reply{ 
                            datapath_mac = ?DATAPATH_MAC,
                            datapath_id = ?DATAPATH_ID}, Features),
            ?assertEqual(DatapathId, {?DATAPATH_ID, ?DATAPATH_MAC}),
            ?assertEqual(Version, ?VERSION),
            ?assertEqual(AuxId, ExpectedAuxId),
            {ok, aux_callback_state} end),
    meck:expect(of_driver_handler_mock, handle_disconnect, fun(_Reason, aux_callback_state) -> ok end),
    AuxSocket = connect_aux(ExpectedAuxId),
    gen_tcp:close(AuxSocket),
    ?assertNot(meck:called(of_driver_handler_mock, terminate, '_')),
    ?assert(meck:validate(of_driver_handler_mock)).

in_message({Socket, _ConnTable}) ->
    meck:expect(of_driver_handler_mock, handle_message,
                    fun(#ofp_message{type = packet_in}, State) -> {ok, State} end),
    send_msg(Socket, packet_in()),
    ?assert(meck:validate(of_driver_handler_mock)).

send({Socket, ConnTable}) ->
    Hello = of_driver_utils:create_hello(4),
    Connection = get_connection(ConnTable),
    ok = of_driver:send(Connection, Hello),
    {Recv, <<>>} = receive_msg(Socket, <<>>),
    ?assertEqual(Hello, Recv),
    ?assertNot(meck:called(of_driver_handler_mock, handle_message, '_')).

sync_send({Socket, ConnTable}) ->
    Connection = get_connection(ConnTable),
    Msg = of_msg_lib:get_features(4),
    Future = future(of_driver, sync_send, [Connection, Msg]),
    {#ofp_message{type = features_request, xid = RXID}, Rest} = receive_msg(Socket, <<>>),
    {#ofp_message{type = barrier_request, xid = BXID}, <<>>} = receive_msg(Socket, Rest),
    send_msg(Socket, features_reply(RXID)),
    send_msg(Socket, barrier_reply(BXID)),
    {ok, Reply} = wait_future(Future),
    ?assertMatch(#ofp_message{type = features_reply}, Reply),
    ?assertNot(meck:called(of_driver_handler_mock, handle_message, '_')).

sync_send_no_reply({Socket, ConnTable}) ->
    Connection = get_connection(ConnTable),
    Msg = of_msg_lib:get_features(4),
    Future = future(of_driver, sync_send, [Connection, Msg]),
    {#ofp_message{type = features_request}, Rest} = receive_msg(Socket, <<>>),
    {#ofp_message{type = barrier_request, xid = BXID}, <<>>} = receive_msg(Socket, Rest),
    send_msg(Socket, barrier_reply(BXID)),
    {ok, Reply} = wait_future(Future),
    ?assertEqual(noreply, Reply),
    ?assertNot(meck:called(of_driver_handler_mock, handle_message, '_')).

sync_send_non_reply({Socket, ConnTable}) ->
    % sync_send and message is received that is not a reply to the request
    % (XID doesn't match).
    meck:expect(of_driver_handler_mock, handle_message,
                fun(#ofp_message{type = features_reply, xid = 9999}, State) ->
                    {ok, State} end),
    Connection = get_connection(ConnTable),
    Msg = of_msg_lib:get_features(4),
    Future = future(of_driver, sync_send, [Connection, Msg]),
    {#ofp_message{type = features_request}, Rest} = receive_msg(Socket, <<>>),
    {#ofp_message{type = barrier_request, xid = BXID}, <<>>} = receive_msg(Socket, Rest),
    send_msg(Socket, features_reply(9999)),
    send_msg(Socket, barrier_reply(BXID)),
    {ok, Reply} = wait_future(Future),
    ?assertEqual(noreply, Reply),
    ?assertEqual(1, meck:num_calls(of_driver_handler_mock, handle_message, '_')),
    ?assert(meck:validate(of_driver_handler_mock)).

send_list({Socket, ConnTable}) ->
    Connection = get_connection(ConnTable),
    Hello = of_driver_utils:create_hello(4),
    Features = of_msg_lib:get_features(4),
    ok = of_driver:send_list(Connection, [Hello, Features, Hello]),
    {Recv0, Rest0} = receive_msg(Socket, <<>>),
    {Recv1, Rest1} = receive_msg(Socket, Rest0),
    {Recv2, <<>>} = receive_msg(Socket, Rest1),
    ?assertMatch(#ofp_message{type = hello}, Recv0),
    ?assertMatch(#ofp_message{type = features_request}, Recv1),
    ?assertMatch(#ofp_message{type = hello}, Recv2).

sync_send_list({Socket, ConnTable}) ->
    Connection = get_connection(ConnTable),
    Msg = of_msg_lib:get_features(4),
    Future = future(of_driver, sync_send_list, [Connection, [Msg, Msg, Msg]]),
    {#ofp_message{type = features_request, xid = RXID0}, Rest0} = receive_msg(Socket, <<>>),
    {#ofp_message{type = features_request, xid = RXID1}, Rest1} = receive_msg(Socket, Rest0),
    {#ofp_message{type = features_request, xid = RXID2}, Rest2} = receive_msg(Socket, Rest1),
    {#ofp_message{type = barrier_request, xid = BXID}, <<>>} = receive_msg(Socket, Rest2),
    send_msg(Socket, features_reply(RXID0)),
    send_msg(Socket, features_reply(RXID1)),
    send_msg(Socket, features_reply(RXID2)),
    send_msg(Socket, barrier_reply(BXID)),
    {ok, [Reply0, Reply1, Reply2]} = wait_future(Future),
    ?assertMatch({ok, #ofp_message{type = features_reply, xid = RXID0}}, Reply0),
    ?assertMatch({ok, #ofp_message{type = features_reply, xid = RXID1}}, Reply1),
    ?assertMatch({ok, #ofp_message{type = features_reply, xid = RXID2}}, Reply2),
    ?assertNot(meck:called(of_driver_handler_mock, handle_message, '_')).

sync_send_list_no_reply({Socket, ConnTable}) ->
    meck:expect(of_driver_handler_mock, handle_message,
                fun(#ofp_message{type = features_reply, xid = 9999}, State) ->
                    {ok, State} end),
    Connection = get_connection(ConnTable),
    Msg = of_msg_lib:get_features(4),
    Future = future(of_driver, sync_send_list, [Connection, [Msg, Msg, Msg]]),
    {#ofp_message{type = features_request, xid = _RXID0}, Rest0} = receive_msg(Socket, <<>>),
    {#ofp_message{type = features_request, xid = _RXID1}, Rest1} = receive_msg(Socket, Rest0),
    {#ofp_message{type = features_request, xid = RXID2}, Rest2} = receive_msg(Socket, Rest1),
    {#ofp_message{type = barrier_request, xid = BXID}, <<>>} = receive_msg(Socket, Rest2),
    % no reply to first features request
    send_msg(Socket, features_reply(9999)),
    send_msg(Socket, features_reply(RXID2)),
    send_msg(Socket, barrier_reply(BXID)),
    {ok, [Reply0, Reply1, Reply2]} = wait_future(Future),
    ?assertMatch({ok, noreply}, Reply0),
    ?assertMatch({ok, noreply}, Reply1),
    ?assertMatch({ok, #ofp_message{type = features_reply, xid = RXID2}}, Reply2),
    ?assert(meck:validate(of_driver_handler_mock)).

multiple_sync_send({Socket, ConnTable}) ->
    Connection = get_connection(ConnTable),
    Msg = of_msg_lib:get_features(4),
    Future1 = future(of_driver, sync_send, [Connection, Msg]),
    {#ofp_message{type = features_request, xid = RXID1}, Rest1} = receive_msg(Socket, <<>>),
    {#ofp_message{type = barrier_request, xid = BXID1}, <<>>} = receive_msg(Socket, Rest1),
    Future2 = future(of_driver, sync_send, [Connection, Msg]),
    {#ofp_message{type = features_request, xid = RXID2}, Rest2} = receive_msg(Socket, <<>>),
    {#ofp_message{type = barrier_request, xid = BXID2}, <<>>} = receive_msg(Socket, Rest2),
    send_msg(Socket, features_reply(RXID2)),
    send_msg(Socket, features_reply(RXID1)),
    send_msg(Socket, barrier_reply(BXID1)),
    send_msg(Socket, barrier_reply(BXID2)),
    {ok, Reply1} = wait_future(Future1),
    {ok, Reply2} = wait_future(Future2),
    ?assertMatch(#ofp_message{type = features_reply, xid = RXID1}, Reply1),
    ?assertMatch(#ofp_message{type = features_reply, xid = RXID2}, Reply2),
    ?assertNot(meck:called(of_driver_handler_mock, handle_message, '_')).

%%------------------------------------------------------------------------------

get_connection(ConnTable) ->
    get_connection(ConnTable, 0).
    
get_connection(ConnTable, AuxId) ->
    [{AuxId, Connection}] = ets:lookup(ConnTable, AuxId),
    Connection.

receive_msg(Socket, <<>>) ->
    {ok, MsgBin} = gen_tcp:recv(Socket, 0),
    {ok, OfpMsg, LeftOvers} = of_protocol:decode(<<MsgBin/binary>>),
%   ?debugFmt("~n~nreceive message: ~p~n", [OfpMsg]),
    {OfpMsg, LeftOvers};
receive_msg(_Socket, MsgBin) ->
    {ok, OfpMsg, LeftOvers} = of_protocol:decode(<<MsgBin/binary>>),
%   ?debugFmt("~n~nreceive message: ~p~n", [OfpMsg]),
    {OfpMsg, LeftOvers}.

send_msg(Socket, Msg) ->
%   ?debugFmt("~n~nsend message: ~p~n", [Msg]),
    {ok, Bin} = of_protocol:encode(Msg),
    ok = gen_tcp:send(Socket, Bin).

barrier_reply(XID) ->
    #ofp_message{
        version = ?VERSION,
        type = barrier_reply,
        xid = XID,
        body = #ofp_barrier_reply{}
    }.

features_reply(XID) ->
    features_reply(XID, ?DATAPATH_ID, 0).

features_reply(XID, DatapathId, AuxId) ->
    #ofp_message{
        version = ?VERSION,
        type = features_reply,
        xid = XID,
        body = #ofp_features_reply{
            datapath_mac = ?DATAPATH_MAC,
            datapath_id = DatapathId,
            n_buffers = 0,
            n_tables = 255,
            auxiliary_id = AuxId,
            capabilities = [flow_stats,table_stats,port_stats,group_stats,queue_stats]
        }
    }.

packet_in() ->
    #ofp_message{
        version = ?VERSION,
        type = packet_in,
        body = #ofp_packet_in{
            buffer_id = no_buffer,
            reason = action,
            table_id = 1,
            cookie = <<0:64>>,
            match = #ofp_match{fields = []},
            data = <<"abcd">>
        }
    }.

connect_aux(AuxId) ->
    connect(0, AuxId).

connect() ->
    connect(0, 0).

connect(DatapathId) ->
    connect(DatapathId, 0).

connect(DatapathId, AuxId) ->
    {ok, Socket} = gen_tcp:connect({127,0,0,1}, ?LISTEN_PORT,
                                            [binary, {active, false}], 5000),
    send_msg(Socket, of_driver_utils:create_hello([?VERSION])),
    {#ofp_message{type = hello}, Rest} = receive_msg(Socket, <<>>),
    {#ofp_message{type = features_request, xid = XID}, <<>>} = receive_msg(Socket, Rest),
    send_msg(Socket, features_reply(XID, DatapathId, AuxId)),
    Socket.

future(M, F, A) ->
    Token = make_ref(),
    Parent = self(),
    spawn(fun() -> future_call(Parent, Token, M, F, A) end),
    Token.

wait_future(Token) ->
    receive
        {future, Token, R} -> R
    end.

future_call(Parent, Token, M, F, A) ->
    R = apply(M, F, A),
    Parent ! {future, Token, R}.
