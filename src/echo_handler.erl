-module(echo_handler).

-record(echo_handler_state, {
          pid
         }).

setup() ->
    SwitchIP = {10,151,1,72},
    of_driver:start(SwitchIP,6633),
    of_driver:grant_ipaddr(SwitchIP, echo_handler, []).

init(_IpAddr, _DataPathId, Version, Conn, _Opt) ->
    {ok, Pid} = echo_logic:start(Version, Conn),
    {ok, #echo_handler_state{pid = Pid}}.

handle_connect(NewAuxConn, State = #echo_handler_state{pid = Pid}) ->
    gen_server:cast(Pid, {connect, NewAuxConn}),
    {ok, State}.

handle_disconnect(AuxConn, State = #echo_handler_state{pid = Pid}) ->
    NewAuxConn=AuxConn, %% ??
    gen_server:cast(Pid, {disconnect, NewAuxConn}),
    {ok, State}.

terminate(State = #echo_handler_state{pid = Pid}) ->
    gen_server:cast(Pid, terminate),
    ok.

handle_message(_Conn, Msg, State = #echo_handler_state{pid = Pid}) ->
    gen_server:cast(Pid, {message, Msg}),
    {ok, State}.
