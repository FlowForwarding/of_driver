%%%-------------------------------------------------------------------
%%% @copyright (C) 1999-2013, Erlang Solutions Ltd
%%% @author Ruan Pienaar <ruan.pienaar@erlang-solutions.com>
%%% @doc 
%%% OF Driver database abstraction module.
%%% @end
%%%-------------------------------------------------------------------
-module(of_driver_db).
-copyright("2013, Erlang Solutions Ltd.").

-include_lib("of_driver/include/of_driver.hrl").


%% DB API to seperate DB infrastructure from LOOM.

-export([ install/0
        ]).
-export([ clear_acl_list/0,
          allowed/1,
          grant_ipaddr/3,
          revoke_ipaddr/1,
          get_allowed_ipaddrs/0
        ]).
-export([ insert_datapath_id/2,
          remove_datapath_id/3,
          remove_datapath_id/1,
          remove_datapath_aux_id/2,
          lookup_datapath_id/1,
          add_aux_id/3
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
	    io:format("... [~p] Install failed. ~p.\n...Reason:~p...\n...Stacktrace:~p...\n",[?MODULE,C,E,erlang:get_stacktrace()]),
	    ok
    end.

install_try() ->
    application:stop(mnesia),
    mnesia:create_schema([node()]),
    application:start(mnesia),
    ok = of_driver_acl:create_table([node()]),
    ok = mnesia:wait_for_tables([of_driver_acl],infinity),
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

-spec insert_datapath_id(DatapathInfo :: { DatapathId :: integer(), DatapathMac :: term() }, ConnPID :: pid()) -> boolean().
%% @doc
insert_datapath_id(DatapathInfo, ConnPID) ->
    of_driver_datapath:insert_datapath_id(DatapathInfo, ConnPID).

-spec remove_datapath_id(atom(), DatapathInfo :: { DatapathId :: integer(), DatapathMac :: term() }, AuxId :: integer() ) -> ok.
% @doc
remove_datapath_id(main,DatapathInfo,_) ->
    remove_datapath_id(DatapathInfo);
remove_datapath_id(aux,DatapathInfo,AuxId) ->
    remove_datapath_aux_id(DatapathInfo,AuxId).

-spec remove_datapath_id(DatapathInfo :: { DatapathId :: integer(), DatapathMac :: term() }) -> boolean().
%% @doc
remove_datapath_id(DatapathInfo) ->
  of_driver_datapath:remove_datapath_id(DatapathInfo).

-spec remove_datapath_aux_id(DatapathInfo :: { DatapathId :: integer(), DatapathMac :: term() }, AuxID :: integer()) -> boolean().
%% @doc
remove_datapath_aux_id(DatapathInfo, AuxID) ->
  of_driver_datapath:remove_datapath_aux_id(DatapathInfo, AuxID).

-spec add_aux_id(Entry :: tuple(), DatapathInfo :: { DatapathId :: integer(), DatapathMac :: term() }, AuxID :: integer()) -> boolean().
%% @doc
add_aux_id(Entry,DatapathInfo, Aux) ->
  of_driver_datapath:add_aux_id(Entry, DatapathInfo, Aux).
        
-spec lookup_datapath_id(DatapathInfo :: { DatapathId :: integer(), DatapathMac :: term() }) -> list().
%% @doc
lookup_datapath_id(DatapathInfo) ->
  of_driver_datapath:lookup_datapath_id(DatapathInfo).

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








