-module(of_driver_connection).

-behaviour(gen_server).

-export([start_link/1, init/1, handle_call/3, handle_cast/2, handle_info/2,terminate/2, code_change/3]).
-export([ping/0]).

-define(STATE,of_driver_connection_state).

-include_lib("of_protocol/include/of_protocol.hrl").

-record(?STATE,{socket              :: inet:socket(),
                ctrl_versions       :: list(),
                version             :: integer(),
                pid                 :: pid(),
                address             :: inet:ip_address(),
                port                :: port(),
                parser              :: #ofp_parser{},
                hello_buffer = <<>> :: binary(),
                protocol            :: tcp | ssl,
                conn_role = main    :: main | aux,
                aux_id              :: integer()
               }).

%%------------------------------------------------------------------

start_link(Socket) ->
    gen_server:start_link(?MODULE, [Socket], []).

init([Socket]) ->
    Protocol=tcp,
    of_driver_utils:setopts(Protocol,Socket,[{active, once}]),
    {ok, #?STATE{socket        = Socket,
                 ctrl_versions = of_driver_utils:conf_default(of_comaptible_versions,fun erlang:is_list/1,[3,4]),
                 %% TODO: Complete SSL
                 protocol      = Protocol,
                 aux_id        = 0
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
        {ok, #ofp_message{xid = Xid, body = #ofp_hello{}} = Hello, Leftovers} ->
            case decide_on_version(Versions, Hello) of
                {failed, Reason} ->
                    handle_failed_negotiation(Xid, Reason, State);
                Version ->
                    io:format("... [~p] Using version ~p ...",[?MODULE,Version]),
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
                                         version = Version,
                                         hello_buffer = Buffer,
                                         protocol = Protocol,
                                         socket = Socket
                                       } = State) ->
    io:format("... [~p] OFS Handler needs to handle messages .... \n",[?MODULE]),
    of_driver_utils:setopts(Protocol,Socket,[{active, once}]),
    case ofp_parser:parse(Parser, Data) of
        {ok, NewParser, Messages} ->
            _NewState = lists:foldl(fun(Message, AccState) -> handle_message(Message, AccState) end, State, Messages),
            {noreply, State#?STATE{parser = NewParser}};
        _Else ->
            terminate_connection(State, {bad_data, Data})
    end;

handle_info({tcp_closed, Socket},State) ->
    erlang:exit(self(),kill), %% Todo; review exit/close strategy...
    {noreply,State};

handle_info({tcp_error, Socket, Reason},State) ->
    io:format("...!!! Error on socket ~p reason: ~p~n", [Socket, Reason]),
    {noreply,State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%---------------------------------------------------------------------------------

handle_message(#ofp_message{ version = Version, type = features_reply, body = Body } = Msg,
               #?STATE{ socket = Socket, aux_id = AuxID } = State) ->
    io:format("... [~p] handling Message ~p ... \n",[?MODULE,Body]),
    DataPathID=of_driver_utils:get_datapath_id(Version,Body),
    case ets:lookup(of_driver_channel_datapath,DataPathID) of
        [] when AuxID =:= 0 ->
            {ok,ChannelPID} = of_driver_channel_sup:start_child(DataPathID),
            of_driver_db:insert_datapath_id(ChannelPID,DataPathID),
            io:format("... [~p] Created channel ~p ... \n",[?MODULE,ChannelPID]),
            State;
        [Entry] when AuxID =/= 0 ->
            
            State;
        _Else ->
            of_driver_utils:close(Socket),
            erlang:exit(self(),kill) %% Todo; review exit/close strategy...
    end;
handle_message(#ofp_message{ version = Version, type = _Type, body = Body } = Msg,State) ->
    io:format("... [~p] handling Message ~p (Not doing anything...) ... \n",[?MODULE,Body]),
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

handle_failed_negotiation(Xid, Reason, #?STATE{socket = Socket,
                                               ctrl_versions = Versions} = State) ->
    io:format("... [~p] Version negotiation failed Reason :~p...",[?MODULE,Reason]),
    send_incompatible_version_error(Xid, Socket, tcp,
                                    lists:max(Versions)),
    terminate_connection(State, Reason).

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

terminate_connection(#?STATE{socket = Socket} = State, Reason) ->
    of_driver_utils:close(tcp, Socket).

ping() ->
    ok.
