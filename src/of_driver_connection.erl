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

-module(of_driver_connection).
-copyright("2013, Erlang Solutions Ltd.").

-behaviour(gen_server).

-export([idle_check/1,
         ping_timeout/1]).

-export([start_link/1,
         init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3
        ]).

-define(STATE, of_driver_connection_state).
-define(NOREPLY, noreply).

-include_lib("of_protocol/include/of_protocol.hrl").
-include_lib("of_driver/include/of_driver_logger.hrl").

% XXX can only handle one sync_send at a time.  Can organize
% XIDs by XID of barrier reply to get around this.

-record(?STATE,{ switch_handler          :: atom(),
                 switch_handler_opts     :: list(),
                 ping_timeout            :: integer(),
                 ping_idle               :: integer(),
                 ping_xid                :: integer(),
                 ping_timeout_timer      :: term(),
                 idle_poll_interval      :: integer(),
                 multipart_timeout       :: integer(),
                 socket                  :: inet:socket(),
                 ctrl_versions           :: list(),
                 version                 :: integer(),
                 main_monitor            :: reference(),
                 address                 :: inet:ip_address(),
                 port                    :: port(),
                 parser                  :: #ofp_parser{},
                 hello_buffer = <<>>     :: binary(),
                 protocol                :: tcp | ssl,
                 aux_id = 0              :: integer(),
                 datapath_info           :: { DatapathId :: integer(), DatapathMac :: term() },
                 connection_init = false :: boolean(),
                 handler_state           :: term(),
                 pending_msgs            :: term(),
                 xid = 0                 :: integer(),
                 startup_leftovers       :: binary(),
                 idle_timer_poller       :: term(),
                 last_receive            :: term()
               }).

%%------------------------------------------------------------------

idle_check(ServerPid) ->
    gen_server:cast(ServerPid, idle_check).

ping_timeout(ServerPid) ->
    gen_server:cast(ServerPid, ping_timeout).

%%------------------------------------------------------------------

start_link(Socket) ->
    gen_server:start_link(?MODULE, [Socket], []).

init([Socket]) ->
    Protocol = tcp,
    of_driver_utils:setopts(Protocol, Socket, [{active, once}]),
    {ok, {Address, Port}} = inet:peername(Socket),
    SwitchHandler = of_driver_utils:conf_default(callback_module, fun erlang:is_atom/1, of_driver_default_handler),
    PingEnable = of_driver_utils:conf_default(enable_ping, fun erlang:is_atom/1, false),
    PingTimeout = of_driver_utils:conf_default(ping_timeout, fun erlang:is_integer/1, 1000),
    PingIdle = of_driver_utils:conf_default(ping_idle, fun erlang:is_integer/1, 5000),
    IdlePollInt = of_driver_utils:conf_default(idle_timeout_poll, fun erlang:is_integer/1, 1000),
    MultipartTimeout = of_driver_utils:conf_default(multipart_timeout, fun erlang:is_integer/1, 30000),
    Opts = of_driver_utils:conf_default(init_opt, []),
    ?INFO("Connected to Switch on ~s:~p. Connection : ~p \n",[inet_parse:ntoa(Address), Port, self()]),
    Versions = of_driver_utils:conf_default(of_compatible_versions, fun erlang:is_list/1, [3, 4]),
    ok = gen_server:cast(self(), {send, hello}),
    ITRef = maybe_idle_check(PingEnable, IdlePollInt),
    {ok, #?STATE{ switch_handler      = SwitchHandler,
                  switch_handler_opts = Opts,
                  ping_timeout        = PingTimeout,
                  ping_idle           = PingIdle,
                  idle_poll_interval  = IdlePollInt,
                  multipart_timeout   = MultipartTimeout,
                  socket              = Socket,
                  ctrl_versions       = Versions,
                  protocol            = Protocol,
                  address             = Address,
                  port                = Port,
                  pending_msgs        = gb_trees:empty(),
                  idle_timer_poller   = ITRef,
                  last_receive        = now()
                }}.

%%------------------------------------------------------------------

handle_call(close_connection, _From, State) ->
    close_of_connection(State, called_close_connection);
handle_call({sync_send, OfpMsgs}, From, State =
                                            #?STATE{xid = XID,
                                                    version = Version,
                                                    protocol = Protocol,
                                                    socket = Socket,
                                                    pending_msgs = PSM}) ->
    Barrier = of_msg_lib:barrier(Version),
    {NewXID, EncodedMessages} = encode_msgs(XID,
                                        lists:append(OfpMsgs, [Barrier])),
    XIDs = send_msgs(Protocol, Socket, EncodedMessages),
    NewPSM = pending_msgs(From, XIDs, PSM),
    {noreply, State#?STATE{xid = NewXID, pending_msgs = NewPSM}};
handle_call({send, Msgs}, _From, State) ->
    R = [do_send(Msg, State) || Msg <- Msgs],
    {reply, R, State};
handle_call(next_xid, _From, #?STATE{ xid = XID } = State) ->
    {XID, NewState} = next_xid(State),
    {reply, {ok, XID}, NewState};
handle_call(pending_msgs, _From, State) -> %% ***DEBUG
    {reply,{ok, State#?STATE.pending_msgs}, State};
handle_call(state, _From, State) ->
    {reply, {ok, State}, State}.
    
%%------------------------------------------------------------------

handle_cast({send, hello}, State) ->
    Versions = of_driver_utils:conf_default(of_compatible_versions, fun erlang:is_list/1, [3, 4]),
    Msg = of_driver_utils:create_hello(Versions),
    do_send(Msg, State),
    {noreply, State};
handle_cast(idle_check, State) ->
    NewState = maybe_ping(State),
    {noreply, NewState};
handle_cast(ping_timeout, State) ->
    close_of_connection(State, ping_timeout).

%%------------------------------------------------------------------

handle_info({'DOWN', MonitorRef, process, _MainPid, Reason},
                            State = #?STATE{main_monitor = MonitorRef}) ->
    close_of_connection(State, {main_closed, Reason});
handle_info({tcp, Socket, Data},#?STATE{ protocol = Protocol, socket = Socket } = State) ->
    of_driver_utils:setopts(Protocol,Socket,[{active, once}]),
    do_handle_tcp(State, Data);
handle_info({tcp_closed,_Socket},State) ->
    close_of_connection(State,tcp_closed);
handle_info({tcp_error, _Socket, _Reason},State) ->
    close_of_connection(State,tcp_error).

%%------------------------------------------------------------------

terminate(Reason, #?STATE{socket = undefined}) ->
    % terminating after connection is closed
    ?INFO("[~p] terminating: ~p~n",[?MODULE, Reason]),
    ok;
terminate(Reason, State) ->
    % terminate and close connection
    ?INFO("[~p] terminating (crash): ~p~n",[?MODULE, Reason]),
    close_of_connection(State,gen_server_terminate),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%-----------------------------------------------------------------------------

next_xid(#?STATE{xid = XID} = State) ->
    {XID, State#?STATE{xid = XID + 1}}.

maybe_ping(#?STATE{
                connection_init = true,
                ping_idle = PingIdle,
                last_receive = LastReceive,
                ping_xid = undefined} = State) ->
    case timer:now_diff(now(), LastReceive) > 1000 * PingIdle of
        false ->
            State;
        _ ->
            send_ping(State)
    end;
maybe_ping(State) ->
    % don't send until conneciton is initialized or when
    % another ping while one is outstanding.
    State.

send_ping(#?STATE{version = Version, ping_timeout = PingTimeout} = State) ->
    {Xid, NewState} = next_xid(State),
    Echo = of_driver:set_xid(of_msg_lib:echo_request(Version, <<>>), Xid),
    do_send(Echo, State),
    {ok, TRef} = timer:apply_after(PingTimeout, ?MODULE, ping_timeout, [self()]),
    NewState#?STATE{ping_xid = Xid, ping_timeout_timer = TRef}.

receive_ping(#?STATE{ping_timeout_timer = TRef} = State) ->
    {ok, cancel} = timer:cancel(TRef),
    State#?STATE{ping_timeout_timer = undefined, ping_xid = undefined}.

do_send(Msg, #?STATE{protocol = Protocol,
                     socket   = Socket} = _State) ->
    case of_protocol:encode(Msg) of
        {ok, EncodedMessage} ->
            ?DEBUG("Send: ~p~n", [Msg]),
            of_driver_utils:send(Protocol, Socket, EncodedMessage);
        {error, Error} ->
            {error, Error}
    end.

pending_msgs(From, XIDStatus, Pending) ->
    pending_msgs(From, XIDStatus, XIDStatus, Pending).

pending_msgs(From, XIDStatus, [{BarrierXID, _}], Pending) ->
    % XXX check for barrier error
    gb_trees:insert(BarrierXID, {barrier, From, XIDStatus}, Pending);
pending_msgs(From, XIDStatus, [{XID, Status} | R], Pending) ->
    ReplyStatus = case Status of ok -> ?NOREPLY; RS -> RS end,
    pending_msgs(From, XIDStatus, R,
                                gb_trees:insert(XID, ReplyStatus, Pending)).

send_msgs(Protocol, Socket, EncodedMsgs) ->
    [
        case A of
            {_X, {error, _Error}} ->
                A;
            {X, EM} ->
                R = of_driver_utils:send(Protocol, Socket, EM),
                {X, R}
        end || A <- EncodedMsgs].

encode_msgs(XID, Msgs) ->
    {NewXID, Ms} = lists:foldl(
            fun(Msg, {X, L}) ->
                M = case of_protocol:encode(Msg#ofp_message{xid = X}) of
                    {ok, EncodedMessage} ->
                        EncodedMessage;
                    {error, Error} ->
                        {error, Error}
                end,
                {X + 1, [{X, M} | L]}
            end, {XID, []}, Msgs),
    {NewXID, lists:reverse(Ms)}.

%%-----------------------------------------------------------------------------

do_handle_tcp(State, <<>>) ->
    {noreply, State};
do_handle_tcp(#?STATE{parser        = undefined,
                      version       = undefined,
                      socket        = Socket,
                      ctrl_versions = Versions,
                      hello_buffer  = Buffer,
                      protocol      = Protocol
                     } = State, Data) ->
    case of_protocol:decode(<<Buffer/binary, Data/binary>>) of
        {ok, #ofp_message{xid = XID, body = #ofp_hello{}} = Hello, Leftovers} ->
            case decide_on_version(Versions, Hello) of
                {failed, Reason} ->
                    handle_failed_negotiation(XID, Reason, State);
                Version ->
                    {ok, Parser} = ofp_parser:new(Version),
                    {ok, FeaturesBin} = of_protocol:encode(create_features_request(Version)),
                    ok = of_driver_utils:send(Protocol, Socket, FeaturesBin),
                    do_handle_tcp(State#?STATE{parser = Parser,
                                               version = Version}, Leftovers)
            end;
        {ok, #ofp_message{xid = _XID, body = _Body} = Msg, Leftovers} ->
            ?WARNING("Hello handshake in progress, dropping message: ~p~n",[Msg]),
            do_handle_tcp(State, Leftovers);
        {error, binary_too_small} ->
            {noreply, State#?STATE{hello_buffer = <<Buffer/binary,
                                                    Data/binary>>}};
        {error, unsupported_version, XID} ->
            handle_failed_negotiation(XID, unsupported_version_or_bad_message,
                                      State)
    end;
do_handle_tcp(#?STATE{ parser = Parser} = State, Data) ->
    case ofp_parser:parse(Parser, Data) of
        {ok, NewParser, Messages} ->
            case handle_messages(Messages, State) of
                {ok, NewState} ->
                    {noreply, NewState#?STATE{
                                        parser = NewParser,
                                        last_receive = now()}};
                {stop, Reason, NewState} ->
                    {stop, Reason, NewState}
            end;
        _Else ->
            close_of_connection(State,parse_error)
    end.  

handle_messages([], NewState) ->
    {ok, NewState};
handle_messages([Message|Rest], NewState) ->
    ?DEBUG("Receive: ~p~n", [Message]),
    case handle_message(Message, NewState) of
        {stop, Reason, State} ->
            {stop, Reason, State};
        NextState ->
            handle_messages(Rest, NextState)
    end.

handle_message(#ofp_message{version = Version,
                            type    = features_reply,
                            body    = Features} = _Msg,
                            #?STATE{connection_init     = false,
                                    switch_handler      = SwitchHandler,
                                    switch_handler_opts = Opts,
                                    address             = IpAddr} = State) ->
    % process feature reply from our initial handshake
    {ok, DatapathInfo} = of_driver_utils:get_datapath_info(Version, Features),
    NewState1 = State#?STATE{datapath_info = DatapathInfo},
    NewState2 = case Version of
        3 ->
            NewState1#?STATE{aux_id = 0};
        _ ->
            {ok, AuxID} = of_driver_utils:get_aux_id(Version, Features),
            NewState1#?STATE{aux_id = AuxID}
    end,
    case handle_datapath(NewState2) of 
        Error1 = {stop, _, _} ->
            Error1;
        NewState3 ->
            InitAuxID = NewState3#?STATE.aux_id,
            R = case InitAuxID of
                0 ->
                    do_callback(SwitchHandler, init,
                                        [IpAddr, DatapathInfo,
                                         Features, Version, self(), Opts],
                                        NewState3);
                _ ->
                    MainPid = of_driver_db:lookup_connection(DatapathInfo, 0),
                    MonitorRef = erlang:monitor(process, MainPid),
                    NewState4 = NewState3#?STATE{main_monitor = MonitorRef},
                    do_callback(SwitchHandler, handle_connect,
                                        [IpAddr, DatapathInfo, Features,
                                         Version, self(), InitAuxID, Opts],
                                        NewState4)
            end,
            case R of
                Error2 = {stop, _, _} ->
                    Error2;
                NewState5 ->
                    NewState5#?STATE{connection_init = true}
            end
    end;
handle_message(#ofp_message{} = Msg, #?STATE{connection_init = false} = State) ->
    ?WARNING("Features handshake in progress, dropping message: ~p~n",[Msg]),
    State;
handle_message(#ofp_message{xid = XID, type = barrier_reply} = Msg,
                                    #?STATE{pending_msgs = PSM} = State) ->
    case gb_trees:lookup(XID, PSM) of 
        {value, ?NOREPLY} ->
            % explicit barrier
            update_response(XID, Msg, State);
        {value, {barrier, From, XIDStatus}} ->
            SyncResults = get_pending_results(XIDStatus, PSM),
            NewPSM = delete_pending_results(XIDStatus, PSM),
            gen_server:reply(From, SyncResults),
            State#?STATE{pending_msgs = NewPSM};
        false ->
            % these aren't the droids you're looking for...
            switch_handler_next_state(Msg, State)
    end;
handle_message(#ofp_message{xid = XID, type = echo_reply},
                                        #?STATE{ping_xid = XID} = State) ->
    receive_ping(State);
handle_message(#ofp_message{xid = XID} = Msg, State) ->
    update_response(XID, Msg, State).
    
update_response(XID, Msg, State = #?STATE{pending_msgs = PSM}) ->
    case gb_trees:lookup(XID, PSM) of
        {value, ?NOREPLY} ->
            State#?STATE{pending_msgs = gb_trees:enter(XID, Msg, PSM)};
        {value, _} ->
            % XXX more than one response - report an error
            State;
        none ->
            % these aren't the droids you're looking for...
            switch_handler_next_state(Msg, State)
    end.

get_pending_results(XIDStatus, PSM) ->
    get_pending_results(XIDStatus, PSM, []).

get_pending_results([{_BarrierXID, _}], _PSM, Replies) ->
    lists:reverse(Replies);
get_pending_results([{XID, _} | Rest], PSM, Replies) ->
    R = case gb_trees:get(XID, PSM) of
        Error = {error, _} -> Error;
        Response -> {ok, Response}
    end,
    get_pending_results(Rest, PSM, [R | Replies]).

delete_pending_results(XIDStatus, PSM) ->
    lists:foldl(
            fun({XID, _Status}, T) ->
                gb_trees:delete(XID, T)
            end, PSM, XIDStatus).

handle_datapath(#?STATE{ datapath_info = DatapathInfo,
                         aux_id        = AuxID} = State) ->
    case of_driver_db:insert_connection(DatapathInfo, AuxID, self()) of
        true ->
            State;
        false ->
            % duplicate main connection
            close_of_connection(State, already_connected)
    end.

switch_handler_next_state(Msg, #?STATE{ switch_handler = SwitchHandler,
                                       handler_state = HandlerState
                                       } = State) ->
    {ok, NewHandlerState} = SwitchHandler:handle_message(Msg, HandlerState),
    State#?STATE{handler_state = NewHandlerState}.

%%-----------------------------------------------------------------------------

close_of_connection(#?STATE{ socket        = Socket,
                             datapath_info = DatapathInfo,
                             aux_id        = AuxID,
                             switch_handler= SwitchHandler,
                             handler_state = HandlerState } = State, Reason) ->
    ?WARNING("connection terminated: datapathid(~p) aux_id(~p) reason(~p)~n",
                            [DatapathInfo, AuxID, Reason]),
    of_driver_db:delete_connection(DatapathInfo, AuxID),   
    connection_close_callback(SwitchHandler,HandlerState,AuxID),
    ok = terminate_connection(Socket),
    {stop, normal, State#?STATE{socket = undefined}}.

connection_close_callback(Module, HandlerState, 0) ->
    Module:terminate(driver_closed_connection, HandlerState);
connection_close_callback(Module, HandlerState, _AuxID) ->
    Module:handle_disconnect(driver_closed_connection,HandlerState).

%%-----------------------------------------------------------------------------

create_features_request(3) ->
    of_driver_utils:create_features_request(3);
create_features_request(Version) ->
    of_msg_lib:get_features(Version).

decide_on_version(SupportedVersions, #ofp_message{version = CtrlHighestVersion,
                                                  body    = HelloBody}) ->
    SupportedHighestVersion = lists:max(SupportedVersions),
    if
        SupportedHighestVersion == CtrlHighestVersion ->
            SupportedHighestVersion;
        SupportedHighestVersion >= 4 andalso CtrlHighestVersion >= 4 ->
            decide_on_version_with_bitmap(SupportedVersions, CtrlHighestVersion,
                                          HelloBody);
        true ->
            decide_on_version_without_bitmap(SupportedVersions,
                                             CtrlHighestVersion)
    end.

decide_on_version_with_bitmap(SupportedVersions, CtrlHighestVersion,
                                                                  HelloBody) ->
    Elements = HelloBody#ofp_hello.elements,
    SwitchVersions = get_opt(versionbitmap, Elements, []),
    SwitchVersions2 = lists:umerge([CtrlHighestVersion], SwitchVersions),
    case greatest_common_version(SupportedVersions, SwitchVersions2) of
        no_common_version ->
            {failed, {no_common_version, SupportedVersions, SwitchVersions2}};
        Version ->
            Version
    end.

decide_on_version_without_bitmap(SupportedVersions, CtrlHighestVersion) ->
    case lists:member(CtrlHighestVersion, SupportedVersions) of
        true ->
            CtrlHighestVersion;
        false ->
            {failed, {unsupported_version, CtrlHighestVersion}}
    end.

get_opt(Opt, Opts, Default) ->
    case lists:keyfind(Opt, 1, Opts) of
        false ->
            Default;
        {Opt, Value} ->
            Value
    end.

greatest_common_version([], _) ->
    no_common_version;
greatest_common_version(_, []) ->
    no_common_version;
greatest_common_version(ControllerVersions, SwitchVersions) ->
    lists:max([CtrlVersion || CtrlVersion <- ControllerVersions,
                              lists:member(CtrlVersion, SwitchVersions)]).

handle_failed_negotiation(XID, _Reason, #?STATE{socket        = Socket,
                                                ctrl_versions = Versions } = State) ->
    send_incompatible_version_error(XID, Socket, tcp,lists:max(Versions)),
    close_of_connection(State,failed_version_negotiation).

send_incompatible_version_error(XID, Socket, Proto, OFVersion) ->
    ErrorMessageBody = create_error(OFVersion, hello_failed, incompatible),
    ErrorMessage = #ofp_message{version = OFVersion,
                                xid     = XID,
                                body    = ErrorMessageBody},
    {ok, EncodedErrorMessage} = of_protocol:encode(ErrorMessage),
    ok = of_driver_utils:send(Proto, Socket, EncodedErrorMessage).

%% TODO: move to of_msg_lib...
create_error(3, Type, Code) ->
    ofp_client_v3:create_error(Type, Code);
create_error(4, Type, Code) ->
    ofp_client_v4:create_error(Type, Code).

terminate_connection(Socket) ->
    of_driver_utils:close(tcp, Socket).

do_callback(M, F, A, State) ->
    case erlang:apply(M, F, A) of
        {ok, HandlerState} ->
            State#?STATE{handler_state = HandlerState};
        {error, Reason} ->
            {stop, Reason, State}
    end.

maybe_idle_check(true, IdlePollInt) ->
    {ok, ITRef} = timer:apply_interval(IdlePollInt,
                                            ?MODULE, idle_check, [self()]),
    ITRef;
maybe_idle_check(_, _IdlePollInt) ->
    undefined.
