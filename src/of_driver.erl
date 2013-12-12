-module(of_driver).

-include_lib("of_protocol/include/of_protocol.hrl").
-include_lib("of_driver/include/of_driver.hrl").

-export([ start/0,
          start_link/0,
          grant_ipaddr/1,
          grant_ipaddr/3,
          revoke_ipaddr/1,
          get_allowed_ipaddrs/0,
          set_allowed_ipaddrs/1,
          send/2,
          sync_send/2,
          send_list/2,
          sync_send_list/2,
          close_connection/1,
          close_ipaddr/1,
          set_xid/2,
          gen_xid/1
        ]).

%%------------------------------------------------------------------

start() ->
    start(6633).

start(Port) ->
    ok.

start_link() ->
    ok.

-spec grant_ipaddr(IpAddr :: inet:ip_address()) -> ok | {error, einval}.
grant_ipaddr(IpAddr) ->
    grant_ipaddr(IpAddr, ofs_handler, []).

-spec grant_ipaddr(IpAddr        :: inet:ip_address(), 
                   SwitchHandler :: term(),
                   Opts          :: list()) -> ok | {error, einval}.
grant_ipaddr(IpAddr, SwitchHandler, Opts) ->
    of_driver_db:grant_ipaddr(IpAddr,SwitchHandler,Opts).

-spec revoke_ipaddr(IpAddr :: inet:ip_address()) -> ok | {error, einval}.
revoke_ipaddr(IpAddr) -> 
    %% TODO: Closes any existing connections from IpAddr and calls
    %% appropriate callbacks.  Does nothing if IpAddr was not in the
    %% allowed list.
    of_driver_db:revoke_ipaddr(IpAddr).

-spec get_allowed_ipaddrs() -> [] | [allowance()].
get_allowed_ipaddrs() ->
    of_driver_db:get_allowed_ipaddrs().

-spec set_allowed_ipaddrs(Allowances :: list(allowance())) -> ok.
set_allowed_ipaddrs(Allowances) -> 
    %% TODO: Close any existing connections from IpAddr that was removed.
    PrevAllowed = of_driver_db:get_allowed_ipaddrs(),
    of_driver_db:clear(),
    lists:foreach(fun([{IpAddr,SwitchHandler,Opts}]) ->
                          grant_ipaddr(IpAddr,SwitchHandler,Opts)
                  end, Allowances),
    PrevAllowed.

-spec send(Connection :: term(), Msg :: #ofp_message{}) ->
                                            ok | {error, Reason :: term()}.
send(_Connection, _Msg = #ofp_message{}) -> 
    %% Connection ! Msg ...
    ok.

-spec sync_send(Connection :: term(), Msg :: #ofp_message{}) ->
                                    {ok, Reply :: #ofp_message{} | noreply} |
                                    {error, Reason :: term()}.
sync_send(_Connection, #ofp_message{} = _Msg) -> 
    %% {ok, Reply = #ofp_message{} | noreply } | {error, Reason}.
    ok.

send_list(_Connection, [#ofp_message{} = _Msg]) -> 
    %% ok | {error, [ok | {error, Reason}]}.
    ok.

sync_send_list(_Connection, [#ofp_message{} = _Msg ]) -> 
    %% {ok, [{ok, Reply = #ofp_message{} | noreply}]} | {error, Reason, [{ok, Reply = #ofp_message{} | noreply} | {error, Reason}]}.
    %% {ok, [{ok, Reply = #ofp_message{} | noreply}]}.
    ok.

close_connection(_Connection) ->
    ok.

close_ipaddr(_IpAddr) -> 
    ok.

set_xid(_Msg = #ofp_message{}, _Xid) -> 
    %% NewMsg = #ofp_message{}.
    ok.

gen_xid(_Connection) -> 
    %% integer().
    ok.
