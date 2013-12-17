%%%-------------------------------------------------------------------
%%% @copyright (C) 1999-2013, Erlang Solutions Ltd
%%% @author Ruan Pienaar <ruan.pienaar@erlang-solutions.com>
%%% @doc 
%%% Call back module that sends an echo request and waits for an echo response
%%% @end
%%%-------------------------------------------------------------------
-module(echo_handler).
-copyright("2013, Erlang Solutions Ltd.").

-record(echo_handler_state, { pid
                            }).

-export([ init/1,
          init/5
        ]).

setup() ->
    SwitchIP = {10,151,1,72},
    ok = of_driver:start(SwitchIP,6633),
    ok = of_driver:grant_ipaddr(SwitchIP, echo_handler, []).

init([DatapathID]) ->
    {ok,#echo_handler_state{}}.

init(_IpAddr, _DataPathId, Version, Conn, _Opt) ->
    {ok, Pid} = echo_logic:start_link(Version, Conn),
    {ok, #echo_handler_state{pid = Pid}}.

handle_connect(NewAuxConn, #echo_handler_state{pid = Pid} = State) ->
    ok = gen_server:cast(Pid, {connect, NewAuxConn}),
    {ok, State}.

handle_disconnect(AuxConn, #echo_handler_state{pid = Pid} = State) ->
    NewAuxConn=AuxConn, %% ??
    ok = gen_server:cast(Pid, {disconnect, NewAuxConn}),
    {ok, State}.

terminate(#echo_handler_state{pid = Pid} = State) ->
    ok = gen_server:cast(Pid, terminate),
    ok.

handle_message(_Conn, Msg, #echo_handler_state{pid = Pid} = State) ->
    ok = gen_server:cast(Pid, {message, Msg}),
    {ok, State}.
