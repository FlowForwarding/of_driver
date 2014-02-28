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

-module(of_driver_demo).

-include_lib("of_protocol/include/of_protocol.hrl").
-include_lib("of_protocol/include/ofp_v4.hrl").

-export([create_flow/1]).
-export([clear_flow/1]).

create_flow(ConnectionPid) when is_pid(ConnectionPid) ->
	create_flow({connection,ConnectionPid});
create_flow({connection,ConnectionPid}) ->
	FlowMod = #ofp_message{    version = 4,
                             xid = 100,
                             body = #ofp_flow_mod{
                                  cookie = <<0:64>>,
                                  cookie_mask = <<0:64>>,
                                  table_id = 0,
                                  command = add,
                                  idle_timeout = 30000,
                                  hard_timeout = 60000,
                                  priority = 1,
                                  buffer_id = 1,
                                  out_port = 2,
                                  out_group = 5,
                                  flags = [],
                                  match = #ofp_match{
                                             fields = [#ofp_field{
                                                        class = openflow_basic,
                                                        name = in_port,
                                                        has_mask = false,
                                                        value = <<1:32>>}]},
                                  instructions = [#ofp_instruction_write_actions{
                                                     actions = [#ofp_action_output{
                                                                   port = 2,
                                                                   max_len = 64}]}]
                                }
                          },
    of_driver:sync_send(ConnectionPid,FlowMod).

clear_flow(ConnectionPid) when is_pid(ConnectionPid) ->
	clear_flow({connection,ConnectionPid});
clear_flow({connection,ConnectionPid}) ->
	RemoveFlows = #ofp_message{   version = 4,
                                xid = 200,
                                body = #ofp_flow_mod{
                                          cookie = <<0:64>>,
                                          cookie_mask = <<0:64>>,
                                          table_id = 0,
                                          command = delete,
                                          idle_timeout = 30000,
                                          hard_timeout = 60000,
                                          priority = 1,
                                          buffer_id = 1,
                                          out_port = 2,
                                          out_group = 5,
                                          flags = [],
                                          match = #ofp_match{fields = []},
                                          instructions = []}},
    of_driver:sync_send(ConnectionPid,RemoveFlows).
