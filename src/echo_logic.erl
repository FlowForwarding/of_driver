-module(echo_logic).

-record(echo_handler_state, { version,
                              conn,
                              aux_conns = [],
                              xid
                            }).

start(Version, Conn) ->
    gen_server:start({local, echo_logic}, echo_logic, [Version, Conn], []).

init([Version, Conn]) ->
    gen_sever:cast(self(), ping),
    {ok, #echo_handler_state{version = Version, conn = Conn}}.

handle_cast({connect, AuxConn},
              State = #echo_handler_state{aux_conns = AuxConns}) ->
    {noreply, State#echo_handler_state{aux_conns =
                                     [AuxConn | AuxConns]}};

handle_cast({disconnect, AuxConn},#echo_handler_state{aux_conns = AuxConns} = State) ->
    {noreply,State#echo_handler_state{aux_conns = lists:deleted(AuxConn, AuxConns)}};

handle_cast(terminate,#echo_handler_state{aux_conns = AuxConns} = State) ->
    %% assumes of_driver closes auxiliary connections automatically and does not
    %% call handle_disconnect.
    {stop, no_connection,
        State#echo_handler_state{conn = undefined, aux_conns = []}};

handle_cast({message, Msg}, State) ->
    DecodedMsg = of_msg_lib:decode(Msg),
    handle_message(undefined,undefined,DecodedMsg, State),
    {noreply, State};

handle_cast(ping, State = #echo_handler_state{conn = Conn}) ->
    Xid = of_driver:gen_xid(Conn),
    EchoData = "",
    % XXX of_msg_lib:echo not implemented !?!?!!!
    EchoRequest = of_driver:set_xid(of_msg_lib:echo(EchoData), Xid),
    of_driver:send(Conn, EchoRequest),
    {noreply, State#echo_handler_state{xid = Xid}}.

handle_message(Pid, Conn, {echo_request, Xid, Properties},#echo_handler_state{xid = Xid} = State) ->
    % echo received!
    {ok, State};
handle_message(Pid, Conn, _Msg, State) ->
    % ignore anything else
    {ok, State}.
