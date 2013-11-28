-module(of_driver_connection).

-behaviour(gen_server).

-export([start_link/2, init/1, handle_call/3, handle_cast/2, handle_info/2,terminate/2, code_change/3]).
-export([do_send/2]).

%% Scenario's
%% -export([hello/1,
%%          echo_request/1,
%%          echo_request/2,
%%          features_request/1,
%%          get_config_request/1,
%%          barrier_request/1,
%%          queue_get_config_request/1,
%%          desc_request/1,
%%          flow_stats_request/1,
%%          flow_stats_request_with_cookie/2,
%%          aggregate_stats_request/1,
%%          table_stats_request/1,
%%          port_stats_request/1,
%%          queue_stats_request/1,
%%          group_stats_request/1,
%%          group_desc_request/1,
%%          group_features_request/1,
%%          remove_all_flows/1,
%%          set_config/1,
%%          group_mod/1,
%%          port_mod/1,
%%          group_mod_add_bucket_with_output_to_controller/2,
%%          group_mod_modify_bucket/2,
%%          delete_all_groups/1,
%%          port_desc_request/1,
%%          role_request/1,
%%          flow_mod_table_miss/1,
%%          flow_mod_delete_all_flows/1,
%%          set_async/1,
%%          get_async_request/1,
%%          role_request/3,
%%          flow_add/4,
%%          table_features_keep_table_0/1
%%         ]).

-define(SERVER,?MODULE). 
-define(STATE,of_driver_connection_state).

-include_lib("of_protocol/include/of_protocol.hrl").
-include_lib("of_protocol/include/ofp_v4.hrl").%% TODO, initial version per controller ? ...

-record(?STATE,{socket        :: inet:socket(),
                ctrl_versions :: list(),
                version       :: integer(),
                pid           :: pid(),
                address       :: inet:ip_address(),
                port          :: port(),
                parser        :: #ofp_parser{}
               }).

%%------------------------------------------------------------------

start_link(Socket,Versions) ->
    gen_server:start_link(?MODULE, [Socket,Versions], []).

init([Socket,Versions]) ->
    inet:setopts(Socket, [{active, once}]),
    {ok, #?STATE{socket = Socket,
                 ctrl_versions = Versions
                }}.

handle_call(Request, _From, #?STATE{ socket = Socket } = State) ->
    inet:setopts(Socket, [{active, once}]),
    io:format("...!!! Unknown gen server call ~p !!!...\n",[Request]),
    {reply, ok, State}.

handle_cast({hello,Version},#?STATE{socket = Socket} = State) ->
    inet:setopts(Socket, [{active, once}]),
    io:format("... [~p] handle cast {hello,Version} , version : ~p\n",[?MODULE,Version]),
    ok = do_send_hello(Version,normal,Socket),
    {noreply,State};
handle_cast(hello,#?STATE{socket = Socket, ctrl_versions = Versions} = State) ->
    inet:setopts(Socket, [{active, once}]),
    [ begin
          io:format("... [~p] handle cast hello, version : ~p\n",[?MODULE,Version]),
          ok = do_send_hello(Version,normal,Socket)
      end
      || Version <- Versions],
    {noreply,State};
%% handle_cast(scenarios,#?STATE{ socket = Socket, version = Version } = State) ->
%%     inet:setopts(Socket, [{active, once}]),
%%     %% io:format("... [~p] About to handle scenario's ...\n",[?MODULE])
%%     F=fun(Scenario) -> 
%%               io:format("... [~p] Scenario ~p ...\n",[?MODULE,Scenario]),
%%               timer:sleep(400),
%%               ok = do_send(Socket,?MODULE:Scenario(Version))
%%       end,
%%     lists:foreach(F,[ ]),
%%     {noreply,State};
handle_cast(Msg, #?STATE{ socket = Socket } = State) ->
    inet:setopts(Socket, [{active, once}]),
    io:format("...!!! Unknown gen server cast ~p !!!...\n",[Msg]),
    {noreply, State}.

handle_info({tcp, Socket, Data},#?STATE{ parser = undefined, ctrl_versions = ControllerVersions } = State) ->
    inet:setopts(Socket, [{active, once}]),
    Self=self(),
    io:format("... [~p] handle first tcp...\n", [?MODULE]),
    <<SwitchVersion:8, _TypeInt:8, _Length:16, _XID:32, _Binary2/bytes>> = Data,
    {ok, SwitchVersionParser} = ofp_parser:new(SwitchVersion),
    {ok, NewParser, Messages} = ofp_parser:parse(SwitchVersionParser, Data),
    case lists:member(SwitchVersion,ControllerVersions) of
        true ->
            io:format("... [~p] Compatible, now send a compatible hello...\n",[?MODULE]),
            ok = do_send_hello(SwitchVersion,normal,Socket), %% Now that we are compatible, maybe send a hello to the switch
            %% ok = gen_server:cast(self(),scenarios),
            {noreply,State#?STATE{ version = SwitchVersion,
                                   parser = NewParser
                                 }};
        false ->
            io:format("...!!! [~p] Not Compatible, now disconnect...\n",[?MODULE]),
            do_send_hello(SwitchVersion,hello_with_bad_version,Socket),
            {noreply,State} %% Disconnect because not comapatible...how should i disconnect/stop/kill the child ? ...
    end;
handle_info({tcp, Socket, Data},#?STATE{ parser = Parser, version = Version } = State) ->
    inet:setopts(Socket, [{active, once}]),
    %% io:format("... [~p] handle tcp data...\n", [?MODULE]),
    {ok, NewParser, Messages} = ofp_parser:parse(Parser, Data),
    [ io:format("... [~p] MSG: ~p ...\n",[?MODULE,MSG]) || MSG <- Messages ],
    {noreply,State#?STATE{ parser = NewParser }};

handle_info({tcp_closed, Socket},State) ->
    inet:setopts(Socket, [{active, once}]),
    erlang:exit(self(),kill),
    {noreply,State};

handle_info({tcp_error, Socket, Reason},State) ->
    inet:setopts(Socket, [{active, once}]),
    io:format("...!!! Error on socket ~p reason: ~p~n", [Socket, Reason]),
    {noreply,State};

handle_info(Info, #?STATE{ socket = Socket } = State) ->
    inet:setopts(Socket, [{active, once}]),
    io:format("...!!! Unknown gen server info ~p !!!...\n",[Info]),
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%---------------------------------------------------------------------------------

do_send_hello(Version,Scenario,Socket) ->
    HMsg = hello(Version),
    io:format("... [~p] Sending Hello message ~p ...\n",[?MODULE,HMsg]),
    ok = gen_tcp:send(Socket, encoded_hello_message(Scenario,Version)).

encoded_hello_message(Scenario,Version) ->
    {ok, EncodedHello} = of_protocol:encode(hello(Version)),
    case Scenario of
        hello_with_bad_version -> malform_version_in_hello(EncodedHello);
        _                      -> EncodedHello
    end.

malform_version_in_hello(<<_:8, Rest/binary>>) ->
    <<(16#5):8, Rest/binary>>.

hello(Version) ->
    message(#ofp_hello{},Version).

%%--- Helpers --------------
message(Body,Version) ->
    #ofp_message{version = Version,
                 xid     = get_xid(),
                 body    = Body}.

get_xid() ->
    random:uniform(1 bsl 32 - 1).

do_send(Socket, Message) when is_binary(Message) ->
    try
        gen_tcp:send(Socket, Message)
    catch
        _:_ ->
            ok
    end;
do_send(Socket, Message) when is_tuple(Message) ->
    case of_protocol:encode(Message) of
        {ok, EncodedMessage} ->
            do_send(Socket, EncodedMessage);
        _Error ->
            lager:error("...!!! Error in encode of: ~p", [Message])
    end.
%%---------------------------------------------------------------------------------
handle_msg(#ofp_message{ version = Version,
                         body = #ofp_error_msg{type = hello_failed,
                                               code = incompatible}} = Message,_Socket) ->
    io:format("___hello_failed...\n"),
    ok;
handle_msg(#ofp_message{ body = #ofp_packet_in{buffer_id = _BufferId,
                                               match     = _Match,
                                               data      = _Data}} = Message,_Socket) ->
    io:format("___switch entry...\n"),
    ok;
handle_msg(Message,_Socket) ->
    io:format("___Received message ~p\n", [Message]),
    ok.
%%---------------------------------------------------------------------------------
version_negotiation(Version,StateVersion) when Version == StateVersion ->
    {ok,Version};
version_negotiation(Version,StateVersion) when Version < StateVersion ->
    {version_down,Version}; %% Controller needs to use lower version, and maybe resend hello ? ...
version_negotiation(Version,StateVersion) when Version > StateVersion ->
    {version_up,Version}. %% Controller needs to use higer version, and maybe resend hello ? ...


%%--- Scenarios ------------------------------------------------------------------------------

ping() ->
    %% create clear flow table message
    %% send message to swtich
    %% run this on switch : ets:tab2list(linc:lookup(0, flow_table_0)).
    
    ok.
