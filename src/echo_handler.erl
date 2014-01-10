%%%-------------------------------------------------------------------
%%% @copyright (C) 1999-2013, Erlang Solutions Ltd
%%% @author Ruan Pienaar <ruan.pienaar@erlang-solutions.com>
%%% @doc 
%%% Call back module that sends an echo request and waits for an echo response
%%% @end
%%%-------------------------------------------------------------------
-module(echo_handler).
-copyright("2013, Erlang Solutions Ltd.").

-define(STATE,echo_handler_state).

-export([setup/1,
         init/6,
         init_handler/6,
         handle_connect/2,
         handle_message/2
        ]).

-include_lib("of_protocol/include/of_protocol.hrl").

setup(SwitchIP) ->
    ok = of_driver:grant_ipaddr(SwitchIP, echo_handler, []).

state(Pid) ->
  gen_server:call(Pid,state).
 
%% TODO: these calls probably have to be call, and then return the updated state to the of_driver_connection.
handle_connect(NewAuxConn,LogicPid) ->
    ok = gen_server:cast(LogicPid, {connect, NewAuxConn}),
    ok.

handle_disconnect(AuxConn, LogicPid) ->
    ok = gen_server:cast(LogicPid, {disconnect, AuxConn}),
    ok.

terminate(LogicPid) ->
    ok = gen_server:cast(LogicPid, terminate),
    ok.

handle_message(#ofp_message{ type = echo_reply } = Msg,LogicPid) ->
    {ok,NewState} = gen_server:call(LogicPid, {message, Msg}),
    ok = gen_server:cast(LogicPid, ping),
    {ok,NewState};
handle_message(Msg,LogicPid) -> %% {ok,_NewState}
    {ok,_NewState} = gen_server:call(LogicPid, {message, Msg}),
    {ok,_NewState}.

%%------------------------------------------------------------------------------

%% TODO: adding init(), because init and init_handler is not consistent between ofs_handler_driver
init(IpAddr,DatapathInfo,FeaturesReply,Version,Conn,Opts) ->
  init_handler(IpAddr,DatapathInfo,FeaturesReply,Version,Conn,Opts).

init_handler(IpAddr,DatapathInfo,FeaturesReply,Version,Conn,Opts) ->
    {ok, Pid} = echo_logic:start_link(IpAddr,DatapathInfo,FeaturesReply,Version,Conn,Opts),
    {ok,HandlerState} = gen_server:call(Pid,state),
    {ok,Pid,HandlerState}.
