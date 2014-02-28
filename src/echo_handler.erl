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

-module(echo_handler).
-copyright("2013, Erlang Solutions Ltd.").

-include_lib("of_driver/include/of_driver_logger.hrl").
-include_lib("of_driver/include/echo_handler_logic.hrl").

-export([
    init/6,
    handle_connect/7,
    handle_message/2,
    handle_error/2,
    handle_disconnect/2,
    terminate/2
]).

-define(STATE, echo_handler_state).
-record(?STATE, {
    handler_pid :: pid(),
    connection_pid
    }).

% of_driver callbacks 
init(IpAddr, DataPathId, Features, Version, ConnectionPid, Opt) ->
    {ok, Pid} = echo_logic:ofd_find_handler(DataPathId),
    {ok, ConnPid} = echo_logic:ofd_init(Pid,
                    IpAddr, DataPathId, Features, Version, ConnectionPid, Opt),
    {ok, #?STATE{handler_pid = ConnPid, connection_pid = ConnectionPid}}.

handle_connect(IpAddr, DataPathId, Features, Version, ConnectionPid, AuxId, Opt) ->
    {ok, Pid} = echo_logic:ofd_find_handler(DataPathId),
    {ok, ConnPid} = echo_logic:ofd_connect(Pid,
                IpAddr, DataPathId, Features, Version, ConnectionPid, AuxId, Opt),
    {ok, #?STATE{handler_pid = ConnPid, connection_pid = ConnectionPid}}.

handle_message(Msg, State = #?STATE{
                                handler_pid = ConnPid,
                                connection_pid = ConnectionPid}) ->
    case echo_logic:ofd_message(ConnPid, ConnectionPid, Msg) of
        ok ->
            {ok, State};
        {terminate, Reason} ->
            {terminate, Reason, State}
    end.

handle_error(Error, State = #?STATE{
                                handler_pid = ConnPid,
                                connection_pid = ConnectionPid}) ->
    case echo_logic:ofd_error(ConnPid, ConnectionPid, Error) of
        ok ->
            {ok, State};
        {terminate, Reason} ->
            {terminate, Reason, State}
    end.

handle_disconnect(Reason, #?STATE{
                                handler_pid = ConnPid,
                                connection_pid = ConnectionPid}) ->
    ok = echo_logic:ofd_disconnect(ConnPid, ConnectionPid, Reason).

terminate(Reason, #?STATE{ handler_pid = ConnPid,
                           connection_pid = ConnectionPid}) ->
    ok = echo_logic:ofd_terminate(ConnPid, ConnectionPid, Reason).
