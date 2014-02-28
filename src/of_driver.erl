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

%%% @doc 
%%% of_driver manages the network connection between an OpenFlow
%%% controller and an OpenFlow switch.
%%% 
%%% === Application Environment Variables ===
%%% `listen_ip' - IP address
%%% to listen on for connections; default is any IP address.
%%% 
%%% `listen_tcp_options' - `gen_tcp:listen' tcp options.  of_driver
%%% overrides the data delivery options (e.g., active, packet, etc.);
%%% default is no special options.
%%% 
%%% `init_opt' - Erlang term passed to `Module:init' and `Module:connect';
%%% default is `undefined'.
%%% 
%%% `enable_ping' - If `true' enables automatic echo requests from
%%% of_driver to the connected switch.  If `false' there is no automatic
%%% echo.  Default is `true'. [not implemented].
%%% 
%%% `ping_timeout' - Maximum number of milliseconds to wait for an echo
%%% response; default is 1000.
%%% 
%%% `ping_idle' - Send an echo to the switch if there has not been any
%%% messages from the switch in this many milliseconds; default is 5000.
%%% 
%%% `multipart_timeout' - Maximum number of milliseconds to wait for
%%% the final part of a multipart message; default is 30000.
%%% 
%%% `callback_module' - of_driver callback module.
%%% 
%%% === Callback Functions ===
%%% `Module:init/6' and `Module:handle_connect/7' return a State variable
%%% which of_driver associates with the connection.  The State variable
%%% may be any Erlang term.  The callback module may store its own
%%% connection state information in State.  On subsequent callbacks
%%% of_driver passes the State to the callback module function for the
%%% connection that is making the callback.  Module may make changes
%%% to State and those changes are reflected in the next callback.
%%% 
%%% `Module:init(IpAddr, DatapathId, Features, Version, Connection,
%%% InitOpt) -> {ok, State} | {error, Reason}' - Called when a switch
%%% makes the main connection to of_driver.  `IpAddr' is the IP address
%%% of the switch formatted as `{A, B, C, D}', `DatapathId' is the datapath
%%% id reported by the switch
%%% in the OFP_FEATURES_REPLY, `Features' is the decoded OFP_FEATURES_REPLY,
%%% `Version' is the negotiated OpenFlow version, `Connection' is the
%%% Connection handle Module uses to identify the connection for sending
%%% and receiving messages.  `InitOpt' is the Erlang term from the `init_opt'
%%% application environment variable.
%%% `Module:init/6' returns an Erlang term State that is passed to
%%% the callbacks or an error to reject the connection.
%%% 
%%% `Module:handle_connect(IpAddr, DatapathId, Features, Version,
%%% AuxConnection, AuxId InitOpt) -> {ok, State} | {error, Reason}.' - 
%%% Called when a switch makes an auxiliary connection to of_driver.
%%% `IpAddr' is the IP address of the switch formatted as `{A, B, C,
%%% D}', `DatapathId' is the datapath id reported by the switch in the
%%% OFTP_FEATURES_REPLY, `Features' is the decoded OFTP_FEATURES_REPLY,
%%% `Version' is the negotiated OpenFlow version, `AuxConnection' is the
%%% connection handle Module uses to identify the auxiliary connection
%%% for sending and receiving messages, `AuxId' is the auxiliary connection
%%% id from the features reply, `InitOpt' is the Erlang term from the `init_opt'
%%% application environment variable.
%%% `Module:handle_connect/7' returns a State that is passed
%%% to callbacks or an error to reject the connection.
%%% 
%%% `Module:handle_message(Msg = #ofp_message{}, State) -> {ok, NewState} | {terminate, Reason, NewState}.' - 
%%% Called when of_driver receives a mesage from the switch.  The message
%%% may arrive on
%%% the main connection or an auxiliary connection.  `Msg' is the received
%%% message suitable for decoding by `of_msg_lib:decode/1'.  `State' is the
%%% `State' value initially returned by `Module:init/6' or `Module:handle_connect/7'
%%% and later modified by other callback functions. 
%%% Returns `ok' with an updated
%%% `NewState' to accept the message or `terminate' to close the connection.
%%% `Module:handle_message' is not called for replies to `of_driver:sync_send/2' and `of_driver:sync_send_list/2'
%%% requests.
%%% 
%%% `Module:handle_error(Reason, State) -> {ok, NewState} | {terminate,
%%% Reason, NewState}.' -
%%% Called when the switch does not send a valid OpenFlow message or
%%% some other error has occurred on the connection.  The error may be
%%% on the main connection or an auxiliary connection.  Examples:
%%% incomplete multipart message, message that does not parse as an
%%% OpenFlow message.  `State' is the `State' value initially returned by
%%% `Module:init/6' or `Module:handle_connect/7' and later modified by other
%%% callback functions.  Returns `ok' with an updated `NewState' or `terminate'
%%% to close the connection.
%%% 
%%% `Module:handle_disconnect(Reason, State) -> ok.' -
%%% Called when an auxiliary connection is lost because of `Reason'.
%%% `State' is the `State' value initially returned by `Module:handle_connect/7'
%%% and later modified by other callback functions.  The complement of
%%% `Module:handle_connect/7'.  This is the last callback for this particular
%%% auxiliary connection.
%%% 
%%% `Module:terminate(Reason, State) -> ok.'
%%% Called when the main connection is lost for `Reason'.  This is always
%%% the last callback for this particular main connection.  `State' is the
%%% `State' value initially returned by `Module:init/6' and later modified
%%% by other callback functions.  The complement of `Module:init/6'.  Module
%%% should cleanup and terminate.
%%% @end
%%%-------------------------------------------------------------------
-module(of_driver).
-copyright("2013, Erlang Solutions Ltd.").

-include_lib("of_protocol/include/of_protocol.hrl").
-include_lib("of_driver/include/of_driver.hrl").
-include_lib("of_driver/include/of_driver_logger.hrl").

-export([ allowed_ipaddr/1,
          grant_ipaddr/1,
          grant_ipaddr/3,
          revoke_ipaddr/1,
          get_allowed_ipaddrs/0,
          set_allowed_ipaddrs/1,
          send/2,
          send_list/2,
          sync_send/2,
          sync_send_list/2,
          close_connection/1,
          close_ipaddr/1,
          set_xid/2,
          gen_xid/1
        ]).

%%------------------------------------------------------------------
% @hidden
-spec allowed_ipaddr(IpAddr :: inet:ip_address()) -> ok | {error,einval}.
allowed_ipaddr(IpAddr) ->
    of_driver_db:allowed(IpAddr).

% @hidden
-spec grant_ipaddr(IpAddr :: inet:ip_address()) -> ok | {error, einval}.
grant_ipaddr(IpAddr) ->
    % XXX might be better to apply defaults on read so old defaults are
    % not stored in the database
    CallbackMod = of_driver_utils:conf_default(callback_module,
                            fun erlang:is_atom/1, of_driver_default_handler),
    Opts = of_driver_utils:conf_default(init_opt, []),
    grant_ipaddr(IpAddr, CallbackMod, Opts).

% @hidden
-spec grant_ipaddr(IpAddr        :: inet:ip_address(), 
                   SwitchHandler :: term(),
                   Opts          :: list()) -> ok | {error, einval}.
grant_ipaddr(IpAddr, SwitchHandler, Opts) ->
    of_driver_db:grant_ipaddr(IpAddr, SwitchHandler, Opts).

% @hidden
-spec revoke_ipaddr(IpAddr :: inet:ip_address()) -> ok | {error, einval}.
revoke_ipaddr(any) ->
    lists:foreach(fun({{_IpAddr,_Port},Pid,_ConnType}) -> close_connection(Pid) end,ets:tab2list(?SWITCH_CONN_TBL) ),
    of_driver_db:revoke_ipaddr(any);
revoke_ipaddr(IpAddr) -> 
    case of_driver_switch_connection:lookup_connection_pid(IpAddr) of 
        []      -> ok;
        Entries -> lists:foreach(fun([_Port,Pid,_ConnType]) -> close_connection(Pid) end,Entries)
    end,
    of_driver_db:revoke_ipaddr(IpAddr).

% @hidden
-spec get_allowed_ipaddrs() -> [] | [allowance()].
get_allowed_ipaddrs() ->
    of_driver_db:get_allowed_ipaddrs().

% @hidden
-spec set_allowed_ipaddrs(Allowances :: list(allowance())) -> ok.
set_allowed_ipaddrs(Allowances) when is_list(Allowances) ->
    %% TODO: Close any existing connections from IpAddr that was removed.
    lists:map(fun({IpAddr,_SwitchHandler,_Opts}) -> inet_parse:ntoa(IpAddr) end, Allowances), %% Validation could be improved.
    PrevAllowed = of_driver_db:get_allowed_ipaddrs(),
    of_driver_db:clear_acl_list(),
    lists:foreach(fun({IpAddr,SwitchHandler,Opts}) ->
                        grant_ipaddr(IpAddr,SwitchHandler,Opts);
                     (_) ->
                        ok
                  end, Allowances),
    PrevAllowed.

%%------------------------------------------------------------------

%% @doc
%% Send `Msg' to a switch via `Connection'.  `Connection' is returned
%% via the `Module:init/6' or `Module:handle_connect/7' callbacks.  A
%% long message is silently split into a multipart message as appropriate.
%% An `ok' return means of_driver successfully delivered the message.
%% It does not indicate the success of the request on the switch.
%% Switch responses, if any, are delivered via the `Module:handle_message'
%% callback.
%% @end
-spec send(ConnectionPid :: term(), Msg :: #ofp_message{}) ->
                                          ok | {error, Reason :: term()}.
send(ConnectionPid, #ofp_message{} = Msg) ->
    gen_server:cast(ConnectionPid,{send,Msg}).

%% @doc
%% Send a list of `Msg' records to a switch via `Connection'.
%% Automatically adds xids to the messages using `of_driver:gen_xid/1'.
%% Any long messages are silently split into multipart messages as appropriate.
%% `Connection' is the same as with the `of_driver:send/2'.  Returns `ok' if all
%% messages are delivered successfully.  Returns an `error' tuple if
%% there were any errors.  In the error there is one status reply or
%% each request in the send list.  The returned status has the
%% same meaning as `of_driver:send'.
%% @end
-spec send_list(ConnectionPid :: term(), Messages :: list(Msg::#ofp_message{})) -> 
                       ok | {error, [ok | {error, Reason :: term()}]}.
send_list(_ConnectionPid,[]) ->
    ok;
send_list(ConnectionPid,[H|T]) ->
    gen_server:cast(ConnectionPid,{send,H}),
    send_list(ConnectionPid,T).

%%------------------------------------------------------------------

%% @doc
%% Send `Msg' to a switch via `Connection' followed by a barrier request.
%% `Connection' is the same with `of_driver:send/2'.  Automatically adds the
%% xid to the message using `of_driver:gen_xid/1'.  A long message is
%% silently split into a multipart message as appropriate.
%% `Reply' is the reply from
%% the switch for `Msg'. Note that `Reply' may contain an error response
%% from the switch.  `noreply' indicates there was no reply to the
%% command.  A success reply to the implicitly added barrier request
%% is not returned.  An error from the implicitly added barrier is
%% reported as an error. An error return may also indicate that of_driver
%% was unable to deliver the message to the switch.  `Module:handle_message/2'
%% is not called for replies.
%% @end
-spec sync_send(ConnectionPid :: term(), Msg :: #ofp_message{}) -> 
                       {ok, Reply :: #ofp_message{} | noreply} |
                       {error, Reason :: term()}.
sync_send(ConnectionPid, #ofp_message{} = Msg) -> 
    of_driver_connection:sync_call(ConnectionPid,Msg).

%% @doc
%% Send a list of `Msg' records to a switch via `Connection' followed by
%% a barrier request.  `Connection' is the same as with `of_driver:send/2'.
%% Automatically adds the xid to the messages using `of_driver:gen_xid/2'.
%% Any long messages are silently split into multipart messages as appropriate.
%% Returns a `ok' tuple when there are no errors.  Returns
%% an `error' tuple if there are any errors.  In the error
%% return there is one status reply for each request in the
%% message list.  The status reply is the same as with `of_driver:sync_send/2'.
%% A successful reply from the implicitly added barrier request
%% is not returned.  A error from the implicitly added barrier is
%% reported as an error.  An error may also indicate that of_driver
%% was unable to deliver the messages to the switch.  `Module:handle_message/2'
%% is not called for any replies.
%% @end
-spec sync_send_list(ConnectionPid :: term(),Messages :: list(Msg::#ofp_message{})) -> 
                            {ok, [{ok, Reply :: #ofp_message{} | noreply}]} |
                            {error, Reason :: term(), [{ok, Reply :: #ofp_message{} | noreply} | {error, Reason :: term()}]}.
sync_send_list(ConnectionPid,Msgs) when is_list(Msgs) -> 
    of_driver_connection:sync_call(ConnectionPid,Msgs).

%%------------------------------------------------------------------

%% @doc
%% Close the connection.  Does nothing if the connection is already
%% closed or is not valid.  of_driver calls 'Module:handle_disconnect/2'
%% if closing a auxiliary connection or `Module:terminate/2' if closing
%% the main connection.  When closing the main connection, all auxiliary
%% connections to the same switch are automatically closed and
%% `Module:handle_disconnect/2' is called for each auxiliary connection
%% that is closed.
%% @end
-spec close_connection(ConnectionPid :: term()) -> ok.
close_connection(ConnectionPid) -> %% ONLY CLOSE CONNECTION, might be main, or aux
    try 
      gen_server:call(ConnectionPid,close_connection) 
    catch 
      exit:{normal,{gen_server,call,[ConnectionPid,close_connection]}} ->
        ok
    end.

%% @hidden
-spec close_ipaddr(IpAddr :: tuple()) -> ok.
close_ipaddr(IpAddr) ->
    [ close_connection(Pid) || [_Port,Pid,_Type] <- of_driver_switch_connection:lookup_connection_pid(IpAddr) ],
    ok.

%% doc
%% Update the xid in `Msg' to `Xid'.
%% @end
-spec set_xid(Msg :: #ofp_message{}, Xid :: integer()) -> {ok,#ofp_message{}}.
set_xid(#ofp_message{} = Msg, Xid) -> 
    {ok,Msg#ofp_message{ xid = Xid}}.

%% @doc
%% Generate a unique Xid for Connection.  The callback Module may use
%% this function to generate a unique Xid for a `Connection', or the
%% callback Module may use a method of its own choosing.  Recommendation:
%% if there is only one pid using the Connection, Module can use its
%% own code to create unique Xid.  If there are more then one pid
%% using a single `Connection', Module should use `of_driver:gen_xid/1' (or
%% some other intra-pid coordination) to generate unique Xids for the
%% `Connection'.
%% @end
-spec gen_xid(ConnectionPid :: term()) -> {ok,Xid :: integer()}.
gen_xid(ConnectionPidPid) ->
    {ok,Xid} = gen_server:call(ConnectionPidPid,next_xid),
    {ok,Xid}.
