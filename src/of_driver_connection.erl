-module(of_driver_connection).

-behaviour(gen_server).

-export([start_link/2, init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-export([ping/0]).

-define(STATE,of_driver_connection_state).

-include_lib("of_protocol/include/of_protocol.hrl").

-record(?STATE,{ switch_handler      :: atom(),
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
                 datapath_id         :: integer(),
                 datapath_mac        :: list()
               }).

%%------------------------------------------------------------------

start_link(Socket,SwitchHandler) ->
    gen_server:start_link(?MODULE, [Socket,SwitchHandler], []).

init([Socket,SwitchHandler]) ->

    %% The switch uses this SwitchHandler the next time it connects. 

    Protocol=tcp,
    of_driver_utils:setopts(Protocol,Socket,[{active, once}]),
    {ok, #?STATE{ switch_handler = SwitchHandler,
                  socket         = Socket,
                  ctrl_versions  = of_driver_utils:conf_default(of_comaptible_versions,fun erlang:is_list/1,[3,4]),
                  %% TODO: Complete SSL
                  protocol       = Protocol,
                  aux_id         = 0
                }}.

handle_call(_Request, _From,State) ->
    {reply, ok, State}.

handle_cast(_Req,State) ->
    {noreply,State}.

handle_info({tcp, Socket, Data},#?STATE{ parser = undefined,
                                         version = undefined,
                                         ctrl_versions = Versions,
                                         hello_buffer = Buffer,
                                         protocol = Protocol
                                       } = State) ->
    of_driver_utils:setopts(Protocol,Socket,[{active, once}]),
    case of_protocol:decode(<<Buffer/binary, Data/binary>>) of
        {ok, #ofp_message{xid = Xid, body = #ofp_hello{}} = Hello, _Leftovers} ->
            case decide_on_version(Versions, Hello) of
                {failed, Reason} ->
                    handle_failed_negotiation(Xid, Reason, State);
                Version ->
                    %% io:format("... [~p] Using version ~p ...\n",[?MODULE,Version]),
                    %% store connected somewhere
                    %% and do something with left overs....
                    {ok, Parser} = ofp_parser:new(Version),
                    {ok, HelloBin} = of_protocol:encode(of_driver_utils:create_hello(Versions)),
                    ok = of_driver_utils:send(tcp, Socket, HelloBin),                    
                    {ok, FeaturesBin} = of_protocol:encode(of_driver_utils:create_features_request(Version)),
                    ok = of_driver_utils:send(tcp, Socket, FeaturesBin),
                    {noreply, State#?STATE{parser = Parser,version = Version}}
            end;
        {error, binary_too_small} ->
            {noreply, State#?STATE{hello_buffer = <<Buffer/binary,
                                                    Data/binary>>}};
        {error, unsupported_version, Xid} ->
            handle_failed_negotiation(Xid, unsupported_version_or_bad_message,
                                      State)
    end;

handle_info({tcp, Socket, Data},#?STATE{ parser = Parser, 
                                         version = _Version,
                                         hello_buffer = _Buffer,
                                         protocol = Protocol,
                                         socket = Socket
                                       } = State) ->
    of_driver_utils:setopts(Protocol,Socket,[{active, once}]),
    case ofp_parser:parse(Parser, Data) of
        {ok, NewParser, Messages} ->
            NewState = lists:foldl(fun(Message, AccState) -> handle_message(Message, AccState) end, State, Messages),
            {noreply, NewState#?STATE{parser = NewParser}};
        _Else ->
            close_of_connection(State)
    end;

handle_info({tcp_closed,_Socket},State) ->
    close_of_connection(State),
    {noreply,State};

handle_info({tcp_error, _Socket, _Reason},State) ->
    close_of_connection(State),
    {noreply,State}.

terminate(_Reason,State) ->
    close_of_connection(State),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%---------------------------------------------------------------------------------

close_of_connection(#?STATE{ socket = Socket,
                             datapath_id = DatapathID,
                             datapath_mac = DatapathMac,
                             conn_role = ConnRole,
                             aux_id = AuxID } = _State) ->
    case ConnRole of
        main -> 
            of_driver_db:remove_datapath_id({DatapathID,DatapathMac});
        aux  -> 
            of_driver_db:remove_datapath_aux_id({DatapathID,DatapathMac},AuxID)
    end,
    ok = terminate_connection(Socket),
    erlang:exit(self(),kill). %% Todo; review exit/close strategy...

%%---------------------------------------------------------------------------------

handle_message(#ofp_message{ version = Version, type = features_reply, body = Body } = _Msg,
               #?STATE{ socket = _Socket } = State)  when Version =:= 3  ->
    [DatapathID,DatapathMac]=of_driver_utils:get_datapath_info(Version,Body),
    State#?STATE{ datapath_id = DatapathID, datapath_mac = DatapathMac };

handle_message(#ofp_message{ version = Version, type = features_reply, body = Body } = _Msg, State) ->
    [DatapathID,DatapathMac]=of_driver_utils:get_datapath_info(Version,Body),
    AuxID=of_driver_utils:get_aux_id(Version,Body),
    NewState=
        case of_driver_db:lookup_datapath_id({DatapathID,DatapathMac}) of
            [] when AuxID =:= 0 ->
                {ok,ChannelPID} = of_driver_channel_sup:start_child({DatapathID,DatapathMac}),
                %%io:format("... [~p] Created channel ~p ... \n",[?MODULE,ChannelPID]),
                of_driver_db:insert_datapath_id({DatapathID,DatapathMac},self(),ChannelPID),
                State#?STATE{ conn_role = main };
            [Entry] when AuxID =/= 0 ->
                %% add aux entry...
                %%io:format("... [~p] Adding Aux entry AuxID:~p...\n",[?MODULE,AuxID]),
                of_driver_db:add_aux_id(Entry,{DatapathID,DatapathMac},[AuxID,self()]),
                State#?STATE{ conn_role = aux, aux_id = AuxID };
            _Else ->
                close_of_connection(State),
                State
        end,
    NewState#?STATE{ datapath_id = DatapathID, datapath_mac = DatapathMac };

handle_message(#ofp_message{ version = _Version, type = _Type, body = _Body } = _Msg,State) ->
    %% io:format("... [~p] Unknown MSG ~p Not doing anything... \n",[?MODULE,Body]),
    State.

decide_on_version(SupportedVersions, #ofp_message{version = CtrlHighestVersion,
                                                  body = HelloBody}) ->
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

%% @doc Greatest common version.
greatest_common_version([], _) ->
    no_common_version;
greatest_common_version(_, []) ->
    no_common_version;
greatest_common_version(ControllerVersions, SwitchVersions) ->
    lists:max([CtrlVersion || CtrlVersion <- ControllerVersions,
                              lists:member(CtrlVersion, SwitchVersions)]).

handle_failed_negotiation(Xid, _Reason, #?STATE{socket = Socket,
                                                ctrl_versions = Versions
                                               } = State) ->
    send_incompatible_version_error(Xid, Socket, tcp,lists:max(Versions)),
    close_of_connection(State).

send_incompatible_version_error(Xid, Socket, Proto, OFVersion) ->
    ErrorMessageBody = create_error(OFVersion, hello_failed, incompatible),
    ErrorMessage = #ofp_message{version = OFVersion,
                                xid = Xid,
                                body = ErrorMessageBody},
    {ok, EncodedErrorMessage} = of_protocol:encode(ErrorMessage),
    ok = of_driver_utils:send(Proto, Socket, EncodedErrorMessage).

create_error(3, Type, Code) ->
    ofp_client_v3:create_error(Type, Code);
create_error(4, Type, Code) ->
    ofp_client_v4:create_error(Type, Code).

terminate_connection(Socket) ->
    of_driver_utils:close(tcp, Socket).

ping() ->
    ok.
