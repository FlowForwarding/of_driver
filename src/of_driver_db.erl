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
-include_lib("of_driver/include/of_driver_acl.hrl").

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
          remove_datapath_id/1,
          remove_datapath_aux_id/2,
          lookup_datapath_id/1,
          add_aux_id/3
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
    case ets:info(?DATAPATH_TBL) of
        undefined ->
            ?DATAPATH_TBL = ets:new(?DATAPATH_TBL,
                                    [ordered_set, public, named_table]),
	    ok;
        _Options ->
            ok
    end.

%%--- IP white/black list  --------------------------------------------------

clear_acl_list() ->
    of_driver_acl:clear().

-spec allowed(Address :: inet:ip_address()) -> boolean().
allowed(Address) ->
    of_driver_acl:read(Address).

-spec grant_ipaddr(IpAddr        :: inet:ip_address(), 
                   SwitchHandler :: term(),
                   Opts          :: list()) -> ok | {error, einval}.
grant_ipaddr(IpAddr, SwitchHandler, Opts) ->
    of_driver_acl:write(IpAddr, SwitchHandler, Opts).

-spec revoke_ipaddr(IpAddr :: inet:ip_address()) -> ok | {error, einval}.
revoke_ipaddr(IpAddr) ->
    of_driver_acl:delete(IpAddr).

-spec get_allowed_ipaddrs() -> [] | [ allowance() ].
get_allowed_ipaddrs() ->
    of_driver_acl:all().

%%--- Datapath ID/Mac -----------------------------------------------------

insert_datapath_id(DatapathInfo, ConnPID) ->
    true = ets:insert_new(?DATAPATH_TBL,                          
                          {DatapathInfo, [{main,ConnPID}]}
                         ).

remove_datapath_id(DatapathInfo) ->
    true = ets:delete(?DATAPATH_TBL, DatapathInfo).


remove_datapath_aux_id(DatapathInfo, AuxID) ->
    case lookup_datapath_id(DatapathInfo) of
        []      -> false;
        [Entry] -> remove_aux_id(Entry,DatapathInfo, AuxID)
    end.

remove_aux_id(Entry,DatapathInfo, AuxID) ->
    Pos=2,
    CurrentAuxs = element(Pos,Entry),
    Updated=lists:keydelete(AuxID,1,CurrentAuxs),
    true=ets:update_element(?DATAPATH_TBL, DatapathInfo, [{Pos,Updated}]).

add_aux_id(Entry,DatapathInfo, Aux) ->
    Pos=2,
    CurrentAuxs = element(Pos, Entry),
    Updated=[Aux | CurrentAuxs],
    true = ets:update_element(?DATAPATH_TBL, DatapathInfo, [{Pos, Updated}]).
        
lookup_datapath_id(DatapathInfo) ->
    ets:lookup(?DATAPATH_TBL,DatapathInfo).
