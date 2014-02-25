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
