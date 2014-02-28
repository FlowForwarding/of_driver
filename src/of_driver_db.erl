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

-module(of_driver_db).
-copyright("2013, Erlang Solutions Ltd.").

-include_lib("of_driver/include/of_driver.hrl").
-include_lib("of_driver/include/echo_handler_logic.hrl").

%% DB API to seperate DB infrastructure from LOOM.

-export([ install/0
        ]).
-export([ clear_acl_list/0,
          allowed/1,
          grant_ipaddr/3,
          revoke_ipaddr/1,
          get_allowed_ipaddrs/0
        ]).
-export([ insert_datapath_info/2,
          remove_datapath_info/3,
          remove_datapath_info/1,
          remove_datapath_aux_id/2,
          lookup_datapath_info/1,
          add_aux_id/3,
          lookup_datapath_id/1
        ]).
-export([ insert_switch_connection/4,
          remove_switch_connection/2,
          lookup_connection_pid/1
        ]).

%%--- Provisioning -----------------------------------------------------------

install() ->
    try
	install_try()
    catch
	C:E ->
	    io:format("... [~p] Install failed. ~p.\n...Reason:~p...\n...Stacktrace:~p...\n",
        [?MODULE,C,E,erlang:get_stacktrace()]),
	    ok
    end.

install_try() ->
    application:stop(mnesia),
    mnesia:create_schema([node()]),
    application:start(mnesia),
    ok = of_driver_acl:create_table([node()]),
    ok = mnesia:wait_for_tables([of_driver_acl],infinity),

    %% NOTE: just allowing ANY connection in the interim...
    of_driver:grant_ipaddr(any),

    ets:new(?ECHO_HANDLER_TBL, [named_table, ordered_set, {keypos, 2}, public]),

    lists:foreach(fun(Tbl) -> install_try_ets(Tbl) end,
                  [?DATAPATH_TBL, ?SWITCH_CONN_TBL]).

install_try_ets(Tbl) ->
  install_try_ets(Tbl,[ordered_set, public, named_table]).

install_try_ets(Tbl,TblOpts) ->
    case ets:info(Tbl) of
        undefined           -> Tbl = ets:new(Tbl,TblOpts);
        _ExistingTblOptions -> ok
    end.

%%--- IP white/black list  --------------------------------------------------

-spec clear_acl_list() -> ok.
%% @doc
clear_acl_list() ->
    of_driver_acl:clear().

-spec allowed(Address :: inet:ip_address()) -> boolean().
%% @doc
allowed(Address) ->
    of_driver_acl:read(Address).

-spec grant_ipaddr(IpAddr        :: inet:ip_address(), 
                   SwitchHandler :: term(),
                   Opts          :: list()) -> ok | {error, einval}.
%% @doc
grant_ipaddr(IpAddr, SwitchHandler, Opts) ->
    of_driver_acl:write(IpAddr, SwitchHandler, Opts).

-spec revoke_ipaddr(IpAddr :: inet:ip_address()) -> ok | {error, einval}.
%% @doc
revoke_ipaddr(IpAddr) ->
    of_driver_acl:delete(IpAddr).

-spec get_allowed_ipaddrs() -> [] | [ allowance() ].
%% @doc
get_allowed_ipaddrs() ->
    of_driver_acl:all().

%%--- Datapath ID/Mac -----------------------------------------------------

-spec insert_datapath_info(DatapathInfo :: { DatapathId :: integer(), DatapathMac :: term() }, ConnPID :: pid()) -> boolean().
%% @doc
insert_datapath_info(DatapathInfo, ConnPID) ->
    of_driver_datapath:insert_datapath_info(DatapathInfo, ConnPID).

-spec remove_datapath_info(atom(), DatapathInfo :: { DatapathId :: integer(), DatapathMac :: term() }, AuxId :: integer() ) -> ok.
% @doc
remove_datapath_info(main,DatapathInfo,_) ->
    remove_datapath_info(DatapathInfo);
remove_datapath_info(aux,DatapathInfo,AuxId) ->
    remove_datapath_aux_id(DatapathInfo,AuxId).

-spec remove_datapath_info(DatapathInfo :: { DatapathId :: integer(), DatapathMac :: term() }) -> boolean().
%% @doc
remove_datapath_info(DatapathInfo) ->
  of_driver_datapath:remove_datapath_info(DatapathInfo).

-spec remove_datapath_aux_id(DatapathInfo :: { DatapathId :: integer(), DatapathMac :: term() }, AuxID :: integer()) -> boolean().
%% @doc
remove_datapath_aux_id(DatapathInfo, AuxID) ->
  of_driver_datapath:remove_datapath_aux_id(DatapathInfo, AuxID).

-spec add_aux_id(Entry :: tuple(), DatapathInfo :: { DatapathId :: integer(), DatapathMac :: term() }, AuxID :: integer()) -> boolean().
%% @doc
add_aux_id(Entry,DatapathInfo, Aux) ->
  of_driver_datapath:add_aux_id(Entry, DatapathInfo, Aux).
        
-spec lookup_datapath_info(DatapathInfo :: { DatapathId :: integer(), DatapathMac :: term() }) -> list().
%% @doc
lookup_datapath_info(DatapathInfo) ->
  of_driver_datapath:lookup_datapath_info(DatapathInfo).

-spec lookup_datapath_id(DatapathId :: integer()) -> [] | list().
% @doc
lookup_datapath_id(DatapathId) ->
    of_driver_db:lookup_datapath_id(DatapathId).

%%--- Switch Connection -----------------------------------------------------

-spec insert_switch_connection(IpAddr :: inet:ip_address(), Port :: inet:port_number(), ConnectionPid :: pid(),ConnRole :: atom()) -> ok.
%% @doc
insert_switch_connection(IpAddr,Port,ConnectionPid,ConnRole) ->
    of_driver_switch_connection:insert_switch_connection(IpAddr, Port, ConnectionPid, ConnRole).

-spec remove_switch_connection(IpAddr :: inet:ip_address(), Port :: inet:port_number()) -> ok.
% @doc
remove_switch_connection(IpAddr,Port) ->
    of_driver_switch_connection:remove_switch_connection(IpAddr,Port).

-spec lookup_connection_pid(IpAddr :: inet:ip_address()) -> list().
% @doc
lookup_connection_pid(IpAddr) ->
    of_driver_switch_connection:lookup_connection_pid(IpAddr).








