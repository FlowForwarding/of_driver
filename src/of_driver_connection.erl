-module(of_driver_connection).

-behaviour(gen_server).

-export([start/1, init/1, handle_call/3, handle_cast/2, handle_info/2,terminate/2, code_change/3]).
-export([do_send/2, hello/0, hello/1, echo_request/0, echo_request/1, role_request/0 ]).

-define(SERVER,?MODULE). 
-define(START_VERSION,4).
-define(STATE,of_driver_connection_state).

-include_lib("of_protocol/include/of_protocol.hrl").
-include_lib("of_protocol/include/ofp_v4.hrl").%% TODO, initial version per controller ? ...

-record(?STATE,{socket  :: inet:socket(),
                pid     :: pid(),
                address :: inet:ip_address(),
                port    :: port(),
                parser  :: #ofp_parser{} %% Parser version per connection ? ....
               }).

%%------------------------------------------------------------------

start(Socket) ->
    gen_server:start(?MODULE, [Socket], []).

init([Socket]) ->
    inet:setopts(Socket, [{active, once}]),
    {ok, #?STATE{socket = Socket}}.

handle_call({update_state, {Pid, Address, Port, Socket}}, _From, State) ->
    io:format("...updating connection gs state...\n"),
    {reply, ok, State#?STATE{ pid = Pid, address = Address, port = Port, socket = Socket }};
handle_call(state, _From, State) ->
    io:format("~p, ~p, ~p, ~p, ~p\n",[State#?STATE.socket,State#?STATE.pid,State#?STATE.address,State#?STATE.port,State#?STATE.parser]),
    {reply,ok,State};
handle_call(Request, _From, State) ->
    io:format("...!!! Unknown gen server call ~p !!!...\n",[Request]),
    {reply, ok, State}.

handle_cast(Msg, State) ->
    io:format("...!!! Unknown gen server cast ~p !!!...\n",[Msg]),
    {noreply, State}.

handle_info({tcp, Socket, Data},#?STATE{ parser = undefined } = State) ->
    inet:setopts(Socket, [{active, once}]),
    %% io:format("...handle first tcp...\n", []),
    
    %% TODO: does the OpenFlow header stay the same ??? if so, then we can use this for version.
    <<Version:8, _TypeInt:8, _Length:16, _XID:32, _Binary2/bytes>> = Data,
    
    {ok, Parser} = ofp_parser:new(Version),
    {ok, NewParser, Messages} = ofp_parser:parse(Parser, Data),
    lists:foreach(fun(Msg) -> handle_msg(Msg, Socket) end,Messages),
    
    io:format("... [~p] About to handle scenario's ...\n",[?MODULE]),
    Scenarios = [hello,echo_request,role_request],
    F=fun(Scenario) -> 
              io:format("...Scenario ~p ...\n",[Scenario]),
              timer:sleep(200),
              ok = do_send(Socket,?MODULE:Scenario())
      end,
    lists:foreach(F,Scenarios),
    
    {noreply,State#?STATE{ parser = NewParser }};

handle_info({tcp, Socket, Data},#?STATE{ parser = Parser } = State) ->
    inet:setopts(Socket, [{active, once}]),
    io:format("...handle tcp data...\n", []),
    {ok, NewParser, Messages} = ofp_parser:parse(Parser, Data),
     lists:foreach(fun(Msg) -> handle_msg(Msg, Socket) end,Messages),
    {noreply,State#?STATE{ parser = NewParser }};

handle_info({tcp_closed, Socket},State) ->
    inet:setopts(Socket, [{active, once}]),
    erlang:exit(self(),kill),
    {noreply,State};

handle_info({tcp_error, Socket, Reason},State) ->
    inet:setopts(Socket, [{active, once}]),
    io:format("Error on socket ~p reason: ~p~n", [Socket, Reason]),
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

hello() ->
    hello(4).

hello(Version) ->
    message(#ofp_hello{},Version).

echo_request() ->
    echo_request(<<>>).
echo_request(Data) ->
    message(#ofp_echo_request{data = Data}).

role_request() ->
    message(#ofp_role_request{role = nochange, generation_id = 1}).

message(Body) ->
    message(Body,?START_VERSION).

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
            lager:error("Error in encode of: ~p", [Message])
    end.

handle_msg(#ofp_message{ body = #ofp_error_msg{type = hello_failed,
                                               code = incompatible}} = Message,_Socket) ->
    io:format("___hello_failed...\n"),
    io:format("___Received message ~p\n", [Message]),
    ok;
handle_msg(#ofp_message{ body = #ofp_packet_in{buffer_id = _BufferId,
                                               match     = _Match,
                                               data      = _Data}} = Message,_Socket) ->
    io:format("___switch entry...\n"),
    io:format("___Received message ~p\n", [Message]),
    ok;
handle_msg(Message,_Socket) ->
    io:format("___Received message ~p\n", [Message]),
    ok.
%%---------------------------------------------------------------------------------
