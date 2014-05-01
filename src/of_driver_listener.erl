%%------------------------------------------------------------------------------
%% Copyright 2014 FlowForwarding.org
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%-----------------------------------------------------------------------------

%% @author Erlang Solutions Ltd. <openflow@erlang-solutions.com>
%% @copyright 2014 FlowForwarding.org

-module(of_driver_listener).
-copyright("2013, Erlang Solutions Ltd.").

-behaviour(gen_server).

-export([start_link/0,
         listen/0]).

-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3
        ]).

-export([accept/1]).

-define(SERVER, ?MODULE). 
-define(STATE, of_driver_listener_state).

-record(?STATE, {
    lsock :: inets:socket()
}).

-include_lib("of_driver/include/of_driver_logger.hrl").

start_link() ->
    {ok, Pid} = gen_server:start_link({local, ?SERVER}, ?MODULE, [], []),
    {ok, Pid}.

listen() ->
    ok = gen_server:cast(?MODULE, startup).

init(_) ->
    case of_driver_utils:conf_default(listen, fun erlang:is_boolean/1, true) of
        false -> ok;
        _ -> listen()
    end,
    {ok, #?STATE{}}.

handle_call(_Msg, _From, State) ->
    {reply, ok, State}.

handle_cast(startup, State) ->
    Port = of_driver_utils:conf_default(listen_port,
                                            fun erlang:is_integer/1, 6633),
    ListenOpts = of_driver_utils:conf_default(listen_opts,
                                            fun erlang:is_list/1,
                                                [binary,
                                                 {packet, raw},
                                                 {active, false},
                                                 {reuseaddr, true}]),
    ListenOpts2 = lists:append(ListenOpts,[{ip,{0,0,0,0}}]),
    ?DEBUG("of_driver listening for switches on ~p~n", [Port]),
    {ok, LSocket} = gen_tcp:listen(Port,ListenOpts2),
    spawn_link(?MODULE, accept, [LSocket]),
    {noreply, State#?STATE{lsock = LSocket}};
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
                    gen_tcp:controlling_process(Socket, ConnCtrlPID);
                {error,_Reason} ->
                    ok
            end,
            accept(ListenSocket);
        _Error ->
            accept(ListenSocket)
    end.
