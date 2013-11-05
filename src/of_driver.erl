%%%-------------------------------------------------------------------
%%% @copyright (C) 1999-2013, Erlang Solutions Ltd
%%% @author Ruan Pienaar <ruan.pienaar@erlang-solutions.com>
%%% @doc 
%%% 
%%% @end
%%%-------------------------------------------------------------------
-module(of_driver).
-copyright("2013, Erlang Solutions Ltd.").

-behaviour(gen_server).

-include_lib("of_protocol/include/of_protocol.hrl").

-export([start_link/0, init/1, handle_call/3, handle_cast/2, handle_info/2,terminate/2, code_change/3]).

-export([send/2,
	 send_list/2,
	 sync_send_list/2
	]).

-define(SERVER, ?MODULE). 

-record(state, {}).

%%------------------------------------------------------------------

-spec send(Switch :: term(), Msg :: #ofp_message{}) -> ok | {error, Reason :: term()}.
send(_Switch,#ofp_message{} = _Msg) ->
    ok.

-spec send_list(Switch :: term(), [Msg :: #ofp_message{}]) -> ok | {error, Reason :: term()}.
send_list(_Switch, Msgs) when is_list(Msgs) ->
    ok.

-spec sync_send_list(Switch :: term(), [Msg :: #ofp_message{}]) -> ok | {error, Msgs :: list()}.
sync_send_list(_Switch, Msgs) when is_list(Msgs) ->
    ok.
							     
%%------------------------------------------------------------------

start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

init([]) ->
    {ok, #state{}}.

handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

