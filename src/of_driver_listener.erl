-module(of_driver_listener).

-behaviour(gen_server).

-export([start_link/0, init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

%% API
-export([connections/0]).

-export([accept/1]).

-define(SERVER, ?MODULE). 
-define(START_VERSION,4).
-define(STATE,of_driver_listener_state).

-include_lib("of_protocol/include/of_protocol.hrl").
-include_lib("of_protocol/include/ofp_v4.hrl").%% TODO, initial version per controller ? ...

-record(?STATE, { lsock      :: inets:socket()
                }).

%% - API ---

connections() ->
    gen_server:call(?MODULE,connections).

%% --------

start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

init(_) ->
    process_flag(trap_exit,true),
    Port=listen_port_conf(),
    {ok, LSocket} = gen_tcp:listen(Port,[binary, {packet, raw},{active, once}, {reuseaddr, true}]),
    {ok, #?STATE{lsock=LSocket}, 0}.

handle_call(Msg,_From,State) ->
    io:format("... [~p] Unknown handle_info ~p ...\n",[?MODULE,Msg]),
    {reply,ok,State}.
    
handle_cast(Msg, State) ->
    io:format("... [~p] !!! Unknown handle_cast ~p !!!...\n",[?MODULE,Msg]),
    {noreply, State}.

handle_info(timeout,#?STATE{lsock=LSocket} = State) ->
    %% io:format("... [~p] handle_info create accept pid ...\n",[?MODULE]),
    spawn(?MODULE,accept,[LSocket]),
    {noreply,State};
handle_info(Msg,State) ->
    io:format("... [~p] Unknown handle_info ~p ...\n",[?MODULE,Msg]),
    {noreply,State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
%%---------------------------------------------------------------------------------

accept(ListenSocket) ->
    io:format("... [~p] accept...\n",[?MODULE]),
    case gen_tcp:accept(ListenSocket) of
        {ok, Socket} ->
            {ok,ConnCtrlPID} = of_driver_connection_sup:start_child(Socket),
            io:format("... [~p] created child ~p ...\n",[?MODULE,ConnCtrlPID]),
            ok = gen_tcp:controlling_process(Socket,ConnCtrlPID),
            {ok,EncodedHelloMessage} = of_protocol:encode(of_driver_connection:hello(4)),
            ok = gen_tcp:send(Socket, EncodedHelloMessage),
            io:format("... [~p] Hello sent to switch ... ~p\n",[?MODULE,EncodedHelloMessage]),
            accept(ListenSocket);
        Error ->
            io:format("... [~p] Accept Error : ~p\n",[?MODULE,Error]),
            accept(ListenSocket)
    end.

%%---------------------------------------------------------------------------------

listen_port_conf() ->
    case application:get_env(of_driver,listen_port) of
	{ok,Port} when is_integer(Port) -> Port;
	_                               -> 12345
    end.

%% TODO: add logging....
%% TODO, initial version per controller ? ...
