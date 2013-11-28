-module(of_driver_listener).

-behaviour(gen_server).

-export([start_link/0, init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

%% API
-export([connections/0]).

-export([accept/2, conf_default/3]).

-define(SERVER, ?MODULE). 
-define(STATE,of_driver_listener_state).

-include_lib("of_protocol/include/of_protocol.hrl").
-include_lib("of_protocol/include/ofp_v4.hrl").%% TODO, initial version per controller ? ...

-record(?STATE, { lsock    :: inets:socket(),
                  versions :: integer()
                }).

%% - API ---

connections() ->
    gen_server:call(?MODULE,connections).

%% --------

start_link() ->
    {ok,Pid} = gen_server:start_link({local, ?SERVER}, ?MODULE, [], []),
    ok = gen_server:cast(?MODULE,startup),
    {ok,Pid}.

init(_) ->
    Port=conf_default(listen_port,fun erlang:is_integer/1,12345),
    CompatibleVersions=conf_default(of_comaptible_versions,fun erlang:is_list/1,[3,4]),
    {ok, LSocket} = gen_tcp:listen(Port,[binary, {packet, raw}, {active, false}, {reuseaddr, true}]),
    {ok, #?STATE{lsock=LSocket,versions=CompatibleVersions}}.

handle_call(Msg,_From,State) ->
    io:format("... [~p] Unknown handle_info ~p ...\n",[?MODULE,Msg]),
    {reply,ok,State}.

handle_cast(startup, #?STATE{lsock=LSocket,versions=Versions} = State) ->
    spawn_link(?MODULE,accept,[LSocket,Versions]),
    {noreply,State};
handle_cast(Msg, State) ->
    io:format("... [~p] !!! Unknown handle_cast ~p !!!...\n",[?MODULE,Msg]),
    {noreply, State}.

handle_info(Msg,State) ->
    io:format("... [~p] Unknown handle_info ~p ...\n",[?MODULE,Msg]),
    {noreply,State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
%%---------------------------------------------------------------------------------

accept(ListenSocket,Versions) ->
    io:format("... [~p] accept(ListenSocket,Versions) \n",[?MODULE]),
    case gen_tcp:accept(ListenSocket) of
        {ok, Socket} ->
            {ok, {Address, Port}}=inet:peername(Socket),
            io:format("... [~p] peername: ~p ...\n ",[?MODULE,{Address, Port}]),
            case of_driver_db:allowed(Address) of
                true ->
                    {ok,ConnCtrlPID} = of_driver_connection_sup:start_child(Socket,Versions),
                    ok = gen_tcp:controlling_process(Socket,ConnCtrlPID),
                    accept(ListenSocket,Versions);
                false ->
                    io:format("... [~p] Socket closed to unallowed switch : ~p\n",[?MODULE,Address]),
                    gen_tcp:close(Socket),
                    accept(ListenSocket,Versions)
            end;
        Error ->
            io:format("... [~p] Accept Error : ~p\n",[?MODULE,Error]),
            accept(ListenSocket,Versions)
    end.

%%---------------------------------------------------------------------------------

conf_default(Entry,Guard,Default) ->
    case application:get_env(of_driver,Entry) of
	{ok,Value} -> 
            case Guard(Value) of
                true -> Value;
                false -> Default
            end;
	_ -> 
            Default
    end.

%% TODO: add logging....
%% TODO, initial version per controller ? ...
