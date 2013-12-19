%%%-------------------------------------------------------------------
%%% @copyright (C) 1999-2013, Erlang Solutions Ltd
%%% @author Ruan Pienaar <ruan.pienaar@erlang-solutions.com>
%%% @doc 
%%% Call back module that sends an echo request and waits for an echo response
%%% @end
%%%-------------------------------------------------------------------
-module(echo_handler).
-copyright("2013, Erlang Solutions Ltd.").

-record(echo_handler_state, { ip_address,
                              datapath_id,
                              features_reply,
                              version,
                              logic_pid,
                              opts
                            }).

-export([   setup/0,
            setup/1,
            init/6
        ]).

setup() ->
    SwitchIP = {10,151,1,65},
    setup(SwitchIP).

setup(SwitchIP) ->
    ok = of_driver:grant_ipaddr(SwitchIP, echo_handler, []).
 
init(IpAddr,DatapathInfo,FeaturesReply,Version,Conn,Opts) ->
    {ok, Pid} = echo_logic:start_link(Version, Conn),
    {ok,#echo_handler_state{  ip_address    = IpAddr,
                              datapath_id   = DatapathInfo,
                              features_reply= FeaturesReply,
                              version       = Version,
                              logic_pid     = Pid,
                              opts          = Opts
    }}.

handle_connect(NewAuxConn, #echo_handler_state{logic_pid = Pid} = State) ->
    ok = gen_server:cast(Pid, {connect, NewAuxConn}),
    {ok, State}.

handle_disconnect(AuxConn, #echo_handler_state{logic_pid = Pid} = State) ->
    ok = gen_server:cast(Pid, {disconnect, AuxConn}),
    {ok, State}.

terminate(#echo_handler_state{logic_pid = Pid} = State) ->
    ok = gen_server:cast(Pid, terminate),
    ok.

handle_message(_Conn, Msg, #echo_handler_state{logic_pid = Pid} = State) ->
    ok = gen_server:cast(Pid, {message, Msg}),
    {ok, State}.
