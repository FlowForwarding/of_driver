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

% For controller -> switch connections, reconnect to the switch
% if the connection is lost.

-module(of_driver_conman).
-copyright("2014, Erlang Solutions Ltd.").

-behaviour(gen_server).

-export([start_link/2,
         signal_connect/1,
         init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3
        ]).

-define(CONNECT_TIMEOUT, 5000).
-define(RETRY_CONNECT_TIME, 5000).
-define(STATE, of_driver_conman_state).

-include_lib("of_driver/include/of_driver_logger.hrl").

-record(?STATE,{monitor_ref :: term(),
                ipaddr :: term(),
                port :: integer()
               }).

%%------------------------------------------------------------------

start_link(IpAddr, Port) ->
    gen_server:start_link(?MODULE, [IpAddr, Port], []).

signal_connect(Pid) ->
    gen_server:cast(Pid, connect).

%%------------------------------------------------------------------

init([IpAddr, Port]) ->
    signal_connect(self()),
    {ok, #?STATE{ipaddr = IpAddr,
                 port = Port}}.

%%------------------------------------------------------------------

handle_call(_Msg, _From, State) ->
    % unknown message
    {reply, ok, State}.
    
%%------------------------------------------------------------------

handle_cast(connect, State = #?STATE{ipaddr = IpAddr, port = Port}) ->
    NewState = case gen_tcp:connect(IpAddr, Port,
                            [binary, {packet, raw}, {active, false}],
                            ?CONNECT_TIMEOUT) of
        {ok, Socket} ->
            case of_driver_connection_sup:start_child(Socket) of
                {ok, Connection} ->
                    gen_tcp:controlling_process(Socket, Connection),
                    MonitorRef = erlang:monitor(process, Connection),
                    State#?STATE{monitor_ref = MonitorRef};
                {error, ChildReason} ->
                    ?WARNING("cannot start of_driver_connection for ~p ~p: ~p",
                                                [IpAddr, Port, ChildReason]),
                    retry_connect(self(), ?RETRY_CONNECT_TIME),
                    State
            end;
        {error, TcpReason} ->
            ?WARNING("tcp error connecting to ~p ~p: ~p",
                                                [IpAddr, Port, TcpReason]),
            retry_connect(self(), ?RETRY_CONNECT_TIME),
            State
    end,
    {noreply, NewState};
handle_cast(_Msg, State) ->
    % unknown message
    {noreply, State}.

%%------------------------------------------------------------------

handle_info({'DOWN', MonitorRef, process, _ConnPid, _Reason},
                            State = #?STATE{monitor_ref = MonitorRef}) ->
    signal_connect(self()),
    {noreply, State};
handle_info(_Msg, State) ->
    % unknown message
    {noreply, State}.

%%------------------------------------------------------------------

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%-----------------------------------------------------------------------------

retry_connect(Pid, WaitTime) ->
    timer:apply_after(WaitTime, ?MODULE, signal_connect, [Pid]).
