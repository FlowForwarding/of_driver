%%%-------------------------------------------------------------------
%%% @copyright (C) 1999-2013, Erlang Solutions Ltd
%%% @author Ruan Pienaar <ruan.pienaar@erlang-solutions.com>
%%% @doc 
%%% OF Driver switch connection 
%%% @end
%%%-------------------------------------------------------------------
-module(of_driver_connection).
-copyright("2013, Erlang Solutions Ltd.").

-behaviour(gen_server).

-export([ start_link/1,
          init/1,
          handle_call/3,
          handle_cast/2,
          handle_info/2,
          terminate/2,
          code_change/3
        ]).

-define(STATE, of_driver_connection_state).

-include_lib("of_protocol/include/of_protocol.hrl").
-include_lib("of_driver/include/of_driver_acl.hrl").
-include_lib("of_driver/include/of_driver_logger.hrl").

-record(?STATE,{ switch_handler      :: atom(),
                 switch_handler_opts :: list(),
                 socket              :: inet:socket(),
                 ctrl_versions       :: list(),
                 version             :: integer(),
                 pid                 :: pid(),
                 address             :: inet:ip_address(),
                 port                :: port(),
                 parser              :: #ofp_parser{},
                 hello_buffer = <<>> :: binary(),
                 protocol            :: tcp | ssl,
                 conn_role = main    :: main | aux,
                 aux_id              :: integer(),
                 datapath_info       :: { DatapathId :: integer(), DatapathMac :: term() },
                 connection_init     :: boolean(),
                 handler_state       :: term(),
                 handler_pid         :: pid()
               }).

%%------------------------------------------------------------------

start_link(Socket) ->
    gen_server:start_link(?MODULE, [Socket], []).

init([Socket]) ->
    {ok, {Address, Port}} = inet:peername(Socket),
    case of_driver:allowed_ipaddr(Address) of
        {true, #?ACL_TBL{switch_handler = SwitchHandler,
                         opts           = Opts } = _Entry} ->
            ?INFO("Connected to Switch on ~p:~p. Connection : ~p \n",[Address, Port, self()]),
            Versions = of_driver_utils:conf_default(of_compatible_versions, fun erlang:is_list/1, [3, 4]),
            Protocol = tcp,
            of_driver_utils:setopts(Protocol, Socket, [{active, once}]),
            ok = gen_server:cast(self(),hello),
            {ok, #?STATE{ switch_handler      = SwitchHandler,
                          switch_handler_opts = Opts,
                          socket              = Socket,
                          ctrl_versions       = Versions,
                          protocol            = Protocol,
                          aux_id              = 0,
                          connection_init     = false,
                          address             = Address
                        }};
        false ->
            terminate_connection(Socket),
            ?WARNING("Rejecting connection - "
                    "IP Address not allowed ipaddr(~p) port(~p)\n",
                                                        [Address, Port]),
            ignore
    end.

handle_call({send,#ofp_message{} = OfpMsg},_From,#?STATE{ protocol = Protocol,
                                                          socket   = Socket } = State) ->
    ok = of_driver_utils:send(Protocol,Socket,OfpMsg),
    {reply,ok,State};
handle_call(_Request, _From,State) ->
    {reply, ok, State}.

handle_cast(hello,#?STATE{ protocol = Protocol,
                           socket   = Socket } = State) ->
    Versions = of_driver_utils:conf_default(of_compatible_versions, fun erlang:is_list/1, [3, 4]),
    {ok, HelloBin} = of_protocol:encode(of_driver_utils:create_hello(Versions)),
    ok = of_driver_utils:send(Protocol, Socket, HelloBin),
    {noreply, State};
handle_cast({send,OfpMsg},#?STATE{ protocol = Protocol,
                                   socket   = Socket } = State) ->
    {ok,EncodedMessage} = of_protocol:encode(OfpMsg),
    ok = of_driver_utils:send(Protocol,Socket,EncodedMessage),
    {noreply, State};
handle_cast(_Req,State) ->
    {noreply, State}.

handle_info({tcp, Socket, Data},#?STATE{ parser        = undefined,
                                         version       = undefined,
                                         ctrl_versions = Versions,
                                         hello_buffer  = Buffer,
                                         protocol      = Protocol
                                       } = State) ->
    % handle initial hello from switch to determine OF protocol
    % version to use on the connection.
    of_driver_utils:setopts(Protocol, Socket, [{active, once}]),
    case of_protocol:decode(<<Buffer/binary, Data/binary>>) of
        {ok, #ofp_message{xid = Xid, body = #ofp_hello{}} = Hello, _Leftovers} ->
            case decide_on_version(Versions, Hello) of
            %% TODO: !!! check that CONNECTION gets stored correctly.
            %% and do something with Leftovers ... 
                {failed, Reason} ->
                    handle_failed_negotiation(Xid, Reason, State);
                Version = 3 -> %% of_msg_lib only currently supports V4... 
                    {ok, Parser} = ofp_parser:new(Version),
                    {ok,FeaturesBin} = of_protocol:encode(of_driver_utils:create_features_request(Version)),
                    handle_features_reply(FeaturesBin,State#?STATE{ parser = Parser, version = Version });
                Version ->
                    {ok, Parser} = ofp_parser:new(Version),
                    {ok,FeaturesBin} = of_protocol:encode(of_msg_lib:get_features(Version)),
                    handle_features_reply(FeaturesBin,State#?STATE{ parser = Parser, version = Version })
            end;
        {error, binary_too_small} ->
            {noreply, State#?STATE{hello_buffer = <<Buffer/binary,
                                                    Data/binary>>}};
        {error, unsupported_version, Xid} ->
            handle_failed_negotiation(Xid, unsupported_version_or_bad_message,
                                      State)
    end;

handle_info({tcp, Socket, Data},#?STATE{ parser       = Parser,
                                         version      = _Version,
                                         hello_buffer = _Buffer,
                                         protocol     = Protocol,
                                         socket       = Socket
                                       } = State) ->
    of_driver_utils:setopts(Protocol,Socket,[{active, once}]),
    case ofp_parser:parse(Parser, Data) of
        {ok, NewParser, Messages} ->
            case do_handle_message(Messages,State) of
                {ok,NewState} ->
                    {noreply, NewState#?STATE{parser = NewParser}};
                {stop, Reason, NewState} ->
                    {stop, Reason, NewState}
            end;
        _Else ->
            % XXX call appropriate callback
            close_of_connection(State)
    end;

handle_info({tcp_closed,_Socket},State) ->
    close_of_connection(State);

handle_info({tcp_error, _Socket, _Reason},State) ->
    % XXX call appropriate callback
    close_of_connection(State).

terminate(_Reason,_State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%-----------------------------------------------------------------------------

handle_features_reply(FeaturesBin,#?STATE{ socket = Socket, protocol = Protocol } = State) ->
    ok = of_driver_utils:send(Protocol, Socket, FeaturesBin),
    {noreply, State}.

close_of_connection(State) ->
    close_of_connection(State,connection_terminated).

close_of_connection(#?STATE{ socket        = Socket,
                             datapath_info = DatapathInfo,
                             conn_role     = ConnRole,
                             aux_id        = AuxID } = State,Reason) ->
    case ConnRole of
        main -> 
            of_driver_db:remove_datapath_id(DatapathInfo);
        aux  -> 
            of_driver_db:remove_datapath_aux_id(DatapathInfo, AuxID) 
    end,
    ok = terminate_connection(Socket),
    ?WARNING("connection terminated: datapathid(~p) aux_id(~p) reason(~p)\n",
                            [DatapathInfo, AuxID, Reason]),
    {stop, normal, State}.

%%-----------------------------------------------------------------------------

do_handle_message([],NewState) ->
    {ok,NewState};
do_handle_message([Message|Rest],NewState) ->
    case handle_message(Message,NewState) of
        {stop, Reason, State} ->
            {stop, Reason, State};
        NextState ->
            do_handle_message(Rest,NextState)
    end.

handle_message(#ofp_message{version = Version,
                            type    = features_reply,
                            body    = Body},
                            #?STATE{connection_init     = false,
                                    switch_handler      = SwitchHandler,
                                    switch_handler_opts = Opts,
                                    address             = IpAddr } = State) ->
    % Intercept features_reply for our initial features_request
    {ok,DatapathInfo} = of_driver_utils:get_datapath_info(Version, Body),
    NewState = 
        case Version of
            3 ->
                State#?STATE{datapath_info = DatapathInfo};
            4 ->
                {ok,AuxID} = of_driver_utils:get_aux_id(Version, Body),
                handle_datapath(State#?STATE{ datapath_info = DatapathInfo, 
                                              aux_id        = AuxID })
        end,
    %% XXX are we aux connection or main connection?  Call appropriate callback
    %% This needs to store the connection................
    {ok, HandlerPid, HandlerState} = SwitchHandler:init(IpAddr, DatapathInfo, Body, Version, self(), Opts),
    NewState#?STATE{ handler_pid = HandlerPid,
                     handler_state = HandlerState };
handle_message(Msg, #?STATE{connection_init = true,
                            switch_handler  = SwitchHandler,
                            handler_pid     = HandlerPid } = State) ->
    {ok,NewHandlerState} = SwitchHandler:handle_message(Msg,HandlerPid),
    State#?STATE{handler_state = NewHandlerState}.

%% Internal Functions

handle_datapath(#?STATE{ datapath_info = DatapathInfo,
                         aux_id        = AuxID } = State) ->
    case of_driver_db:lookup_datapath_id(DatapathInfo) of
        [] when AuxID =:= 0 ->
            %% %% TODO : implement
            %% handle connect
            of_driver_db:insert_datapath_id(DatapathInfo,self()),
            State#?STATE{conn_role       = main,
                         connection_init = true};
        [Entry] when AuxID =/= 0 ->
            of_driver_db:add_aux_id(Entry,DatapathInfo,{AuxID, self()}),
            %% TODO : implement
            %% SwitchHandler:handle_connect()
            State#?STATE{conn_role       = aux,
                         connection_init = true,
                         aux_id          = AuxID};
        _Else ->
            close_of_connection(State,aux_conflict),
            State
    end.

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

handle_failed_negotiation(Xid, _Reason, #?STATE{socket        = Socket,
                                                ctrl_versions = Versions } = State) ->
    send_incompatible_version_error(Xid, Socket, tcp,lists:max(Versions)),
    close_of_connection(State).

send_incompatible_version_error(Xid, Socket, Proto, OFVersion) ->
    ErrorMessageBody = create_error(OFVersion, hello_failed, incompatible),
    ErrorMessage = #ofp_message{version = OFVersion,
                                xid     = Xid,
                                body    = ErrorMessageBody},
    {ok, EncodedErrorMessage} = of_protocol:encode(ErrorMessage),
    ok = of_driver_utils:send(Proto, Socket, EncodedErrorMessage).

%% TODO: move to of_msg_lib...
create_error(3, Type, Code) ->
    ofp_client_v3:create_error(Type, Code);
create_error(4, Type, Code) ->
    ofp_client_v4:create_error(Type, Code).

terminate_connection(Socket) ->
    % XXX call appropriate callback
    of_driver_utils:close(tcp, Socket).
