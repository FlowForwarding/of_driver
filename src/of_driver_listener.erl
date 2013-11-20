-module(of_driver_listener).

-behaviour(gen_server).

%% Gen Server
-export([start_link/0, init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

%% API
-export([connections/0]).

-export([ accept/1, do_send/2 ]).
-export([ hello/0, echo_request/0, echo_request/1, role_request/0 ]).

-define(SERVER, ?MODULE). 
-define(START_VERSION,4).

-include_lib("of_protocol/include/of_protocol.hrl").
-include_lib("of_protocol/include/ofp_v4.hrl").%% TODO, initial version per controller ? ...

-record(switch_connection, { pid     :: pid(),
                             address :: inet:ip_address(),
                             port    :: port(),
                             socket  :: inet:socket(),
                             parser  :: #ofp_parser{} %% Parser version per connection ? ....
                           }).

-record(state, { lsock                                 :: inets:socket(),
                 connections=[]                        :: [ #switch_connection{} ]
               }).

%% - API ---

connections() ->
    gen_server:call(?MODULE,connections).

%% --------

start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

init(_) ->
    Port=listen_port_conf(),
    {ok, LSocket} = gen_tcp:listen(Port,[binary, {packet, raw},{active, once}, {reuseaddr, true}]),
    {ok, #state{lsock=LSocket
               },0}.

handle_call(connections,_From,#state{ connections = Connections } = State) ->
    AliveConnections = lists:filter(fun(C) -> is_process_alive(C#switch_connection.pid) end,Connections),
    {reply,AliveConnections,State#state{ connections = AliveConnections }};
handle_call({add_connection,{Pid, Address, Port, Socket}},_From,#state{ connections = Connections } = State) ->
    %% io:format("ADD CONNECTION:~p\n",[Pid]),
    {reply,ok,State#state{ connections = [assemble_connection(Pid,Address,Port,Socket)|Connections]} };
handle_call({remove_connection,ConnectionPID},_From,#state{ connections = Connections } = State) ->
    NewConnections=case lists:keyfind(ConnectionPID,2,Connections) of
                       []         -> Connections;
                       Connection -> lists:delete(Connection,Connections)
                   end,
    {reply,ok,State#state{ connections = NewConnections }};
handle_call({handle_switch_tcp, ConnectionPID, Socket, Data},_From,#state{ connections = Connections } = State) ->
    %% io:format("GET CONNECTION:~p\n",[ConnectionPID]),
    case lists:keyfind(ConnectionPID,2,Connections) of
        [] ->
            {reply,ok,State};
        Connection ->
            {ok, NewParser, Messages} = ofp_parser:parse(Connection#switch_connection.parser, Data),
            lists:foreach(fun(Msg) ->
                                  handle_msg(Msg,Socket) 
                          end,Messages),
            NewConnection = Connection#switch_connection{ parser = NewParser },
            {reply,ok,State#state{ connections = [ NewConnection |  lists:delete(Connection,Connections) ] }}
    end;
handle_call(Request, _From, State) ->
    io:format("...!!! Unknown gen server call !!!...\n"),
    io:format("...!!! ~p !!!...\n",[Request]),
    {reply, ok, State}.

handle_cast(_Msg, State) ->
    io:format("...!!! Unknown gen server cast !!!...\n"),
    {noreply, State}.

handle_info(timeout,#state{lsock=LSocket} = State) ->
    io:format("...startup accept...\n",[]),
    spawn_accept(LSocket),
    {noreply,State};
handle_info(_Info, State) ->
    io:format("...!!! Unknown gen server info !!!...\n"),
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
%%---------------------------------------------------------------------------------

spawn_accept(LSock) ->
    spawn(?MODULE,accept,[LSock]).

accept(ListenSocket) ->
    case gen_tcp:accept(ListenSocket) of
        {ok, Socket} ->
            %%io:format("...Accepted connection from switch...\n"),
            ok = send_hello(Socket,?START_VERSION),
            %% TODO: find a suitable place to send through scenarios....
            ScenarioList = [hello,echo_request,role_request],
            Pid = spawn(fun() -> loop(self(),Socket,ScenarioList) end),
            {ok, {Address, Port}} = inet:peername(Socket),
            ok = gen_server:call(?MODULE,{add_connection,{Pid, Address, Port, Socket}}),
            gen_tcp:controlling_process(Socket,Pid),
            Pid ! {connected,Socket,Pid},
            accept(ListenSocket);
        Error ->            
	    io:format("\nAccept Error : ~p\n",[Error]),
            exit(Error)
    end.

send_hello(Socket,Version) ->
    {ok,EncodedHelloMessage} = of_protocol:encode(hello()),
    ok = gen_tcp:send(Socket, EncodedHelloMessage).
    
loop(ConnectionPID,Sock,Scenarios) ->
    inet:setopts(Sock, [{active, once}]),
    receive
        %%- Custom -
        {connected,Socket,Pid} ->
            %%io:format("...Connected...\n"),
            F=fun(Scenario) -> 
                      %%io:format("...Scenario ~p ...\n",[Scenario]),
                      timer:sleep(200),
                      ok = do_send(Socket,?MODULE:Scenario())
              end,
            lists:foreach(F,Scenarios),
            loop(ConnectionPID,Socket,Scenarios);
        %%- TCP From Switch----
        {tcp, Socket, Data} ->
            gen_server:call(?MODULE,{handle_switch_tcp, ConnectionPID, Socket, Data}),
            loop(ConnectionPID,Socket,Scenarios);
        {tcp_closed, Socket} ->
            io:format("...tcp closed\n", []),
            ok = gen_server:call(?MODULE,{remove_connection,self()});
        {tcp_error, Socket, Reason} ->
            io:format("Error on socket ~p reason: ~p~n", [Socket, Reason])
            %%- /TCP ----
    end.

%%---------------------------------------------------------------------------------

hello() ->
    message(#ofp_hello{}).

echo_request() ->
    echo_request(<<>>).
echo_request(Data) ->
    message(#ofp_echo_request{data = Data}).

role_request() ->
    message(#ofp_role_request{role = nochange, generation_id = 1}).

message(Body) ->
    message(Body,4).

message(Body,Version) ->
    #ofp_message{version = Version,
                 xid = get_xid(),
                 body = Body}.

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
            lager:error("Error in encode of: ~p", [Message])
    end.

handle_msg(#ofp_message{ body = #ofp_error_msg{type = hello_failed,
                                    code = incompatible}} = Message,Socket) ->
    io:format("hello_failed...\n"),
    io:format("Received message ~p\n", [Message]),
    ok;
handle_msg(#ofp_message{ body = #ofp_packet_in{buffer_id = BufferId,
                                               match = Match,
                                               data = Data}} = Message,Socket) ->
    io:format("switch entry...\n"),
    io:format("Received message ~p\n", [Message]),
    ok;
handle_msg(Message,Socket) ->
    io:format("Received message ~p\n", [Message]),
    ok.
%%---------------------------------------------------------------------------------
%% of_driver_listener specific

assemble_connection(Pid,Address,Port,Socket) ->
    {ok, Parser} = ofp_parser:new(?START_VERSION),
    #switch_connection{ pid     = Pid,
                        address = Address,
                        port    = Port,
                        socket  = Socket,
                        parser  = Parser 
                      }.

%%---------------------------------------------------------------------------------

listen_port_conf() ->
    case application:get_env(of_driver,listen_port) of
	{ok,Port} when is_integer(Port) -> Port;
	_                               -> 12345
    end.
%% TODO: add logging....
