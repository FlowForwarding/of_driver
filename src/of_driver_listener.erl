%%%-------------------------------------------------------------------
%%% @copyright (C) 1999-2013, Erlang Solutions Ltd
%%% @author Ruan Pienaar <ruan.pienaar@erlang-solutions.com>
%%% @doc 
%%% OF Driver listener for switch connections.
%%% @end
%%%-------------------------------------------------------------------
-module(of_driver_listener).
-copyright("2013, Erlang Solutions Ltd.").

-behaviour(gen_server).

-export([ start_link/0,
          init/1,
          handle_call/3,
          handle_cast/2,
          handle_info/2,
          terminate/2,
          code_change/3
        ]).

-export([accept/1]).

-define(SERVER, ?MODULE). 
-define(STATE, of_driver_listener_state).

-record(?STATE, { lsock :: inets:socket()
                }).

start_link() ->
    {ok, Pid} = gen_server:start_link({local, ?SERVER}, ?MODULE, [], []),
    ok = gen_server:cast(?MODULE, startup),
    {ok, Pid}.

init(_) ->
    Port = of_driver_utils:conf_default(listen_port, fun erlang:is_integer/1, 6633),
    {ok, LSocket} = gen_tcp:listen(Port,
                [binary, {packet, raw}, {active, false}, {reuseaddr, true}]),
    {ok, #?STATE{lsock = LSocket}}.

handle_call(_Msg, _From, State) ->
    {reply, ok, State}.

handle_cast(startup, #?STATE{lsock = LSocket} = State) ->
    spawn_link(?MODULE, accept, [LSocket]),
    {noreply, State};
handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Msg,State) ->
    {noreply,State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%-----------------------------------------------------------------------------

accept(ListenSocket) ->
    case gen_tcp:accept(ListenSocket) of
        {ok, Socket} ->
            case of_driver_connection_sup:start_child(Socket) of
                {ok, ConnCtrlPID} ->
                    case gen_tcp:controlling_process(Socket, ConnCtrlPID) of
                        ok               -> ok;
                        {error, _Reason} -> ok
                    end;
                {error,_Reason} ->
                    ok
            end,
            accept(ListenSocket);
        _Error ->
            accept(ListenSocket)
    end.