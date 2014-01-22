-module(of_driver_tcp_stub).

-behaviour(gen_server).

-include_lib("of_protocol/include/of_protocol.hrl").

%% API
-export([start/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).
-export([get_message_heap/0,
		 clear_message_heap/0
	]).

%% Meck 
-export([connect/3, connect/4 ]).
-define(STATE,of_driver_tcp_stub_state).
-record(?STATE,{ socket :: inet:socket(),
				 parser,
				 message_heap=[]
 }).
%%%===================================================================
start() ->
    {ok,Pid} = gen_server:start({local, ?MODULE}, ?MODULE, [], []),
    gen_server:cast(?MODULE,connect),
    {ok,Pid}.

init([]) ->
	{ok, Parser} = ofp_parser:new(4),
	erlang:process_flag(trap_exit, true),
    {ok, #?STATE{ parser = Parser }}.

handle_call(stop,_From,State) ->
	{stop, stopped_self, State};
handle_call(message_heap,_From,#?STATE{ message_heap = MH } = State) ->
	{reply,{ok,MH},State};
handle_call(clear_message_heap,_From,State) ->
	{reply,ok,State#?STATE{ message_heap = [] }};
handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

handle_cast(connect,State) ->
	%%io:format("Trying to connect .... \n"),
	NS=case gen_tcp:connect("localhost",6633,[binary,{reuseaddr,true},{active,once}],5000) of
		{error,Reason} ->
			% io:format("Connect FAILED, trying again... .... \n"),
			timer:apply_after(1000, gen_server, cast, [?MODULE,connect]),
			State#?STATE{ socket = undefined };
		{ok,Socket} ->
			% io:format("Connected .... \n"),
			inet:setopts(Socket, [{active,once}]),
			gen_tcp:controlling_process(Socket, self()),
			gen_server:cast(?MODULE,hello),
			State#?STATE{ socket = Socket }
	end,
	{noreply,NS};
handle_cast(hello,#?STATE{ socket = Socket } = State) ->
	% io:format("Sending hello to CONTROLLER .... \n"),
	Versions = of_driver_utils:conf_default(of_compatible_versions, fun erlang:is_list/1, [3, 4]),
    {ok, HelloBin} = of_protocol:encode(of_driver_utils:create_hello(Versions)),
    ok = of_driver_utils:send(tcp, Socket, HelloBin),
	{noreply, State};
handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({'EXIT',_FromPid,_Reason},#?STATE{ socket = Socket } = State) ->
	of_driver_utils:close(tcp, Socket),
	timer:apply_after(1000, gen_server, cast, [?MODULE,connect]),
	{noreply,State};

handle_info({tcp, Socket, Data},#?STATE{ message_heap = MH } = State) ->
	% io:format("HANDLE TCP SENT FROM SWITCH .... DATA:~p \n",[Data]),
	inet:setopts(Socket, [{active,once}]),
	Heap = decoding_leftovers(Socket,Data,[]),
	{noreply,State#?STATE{ message_heap = Heap }};
handle_info({tcp_closed,_Socket},State) ->
	timer:apply_after(1000, gen_server, cast, [?MODULE,connect]),
    {noreply,State};
handle_info({tcp_error, _Socket, _Reason},State) ->
	timer:apply_after(1000, gen_server, cast, [?MODULE,connect]),
    {noreply,State};
handle_info(Msg,State) ->
	{noreply,State}.

decoding_leftovers(Socket,Data,Heap) ->
	Buffer = <<>>,
	{ok,OfpMessage,Leftovers} = of_protocol:decode(<<Buffer/binary, Data/binary>>),
	case OfpMessage of
		#ofp_message{ type = barrier_request, xid = XID } = Msg -> 
			%% TODO: make those messages records 
			BarrierReply = {ofp_message,4,barrier_reply,XID,{ofp_barrier_reply}},
			{ok,Bin} = of_protocol:encode(BarrierReply),
			of_driver_utils:send(tcp, Socket, Bin);
		#ofp_message{ type = features_request, xid = XID } = Msg ->
			%% TODO: make those messages records 
			FeaturesReply = {ofp_message,4,features_reply,XID,{ofp_features_reply,<<8,0,39,150,212,121>>,0,0,255,0,[flow_stats,table_stats,port_stats,group_stats,queue_stats]}},
			{ok,Bin} = of_protocol:encode(FeaturesReply),
			of_driver_utils:send(tcp, Socket, Bin);
		_Msg ->
			ok
	end,
	case Leftovers of 
		<<>> ->
			[OfpMessage|Heap];
		_Else ->
			decoding_leftovers(Socket,Leftovers,[OfpMessage|Heap])
	end.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================

connect(Address, Port, Options) ->
	gen_tcp:connect(Address, Port, Options).

connect(Address, Port, Options, Timeout) ->
	gen_tcp:connect(Address, Port, Options, Timeout).

get_message_heap() ->
	gen_server:call(?MODULE,message_heap).

clear_message_heap() ->
	gen_server:call(?MODULE,clear_message_heap).