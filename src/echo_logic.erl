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

-module(echo_logic).
-copyright("2013, Erlang Solutions Ltd.").

-include_lib("of_driver/include/echo_handler_logic.hrl").
-include_lib("of_driver/include/of_driver_logger.hrl").

-behaviour(gen_server).
-define(SERVER, ?MODULE).

-define(STATE,echo_logic_state).
-record(?STATE,
    {
        ipaddr,
        datapath_id,
        features,
        of_version,
        main_connection,
        aux_connections,
        callback_mod,
        callback_state,
        generation_id,
        opt
    }
).

%% ------------------------------------------------------------------
%% API Function Exports
%% ------------------------------------------------------------------

-export([start_link/1]).
-export([
    ofd_find_handler/1,
    ofd_init/7,
    ofd_connect/8,
    ofd_message/3,
    ofd_error/3,
    ofd_disconnect/3,
    ofd_terminate/3
]).

%% ------------------------------------------------------------------
%% gen_server Function Exports
%% ------------------------------------------------------------------

-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

%% ------------------------------------------------------------------
%% API Function Definitions
%% ------------------------------------------------------------------

start_link(DatapathId) ->
    gen_server:start_link(?MODULE, [DatapathId], []).

ofd_find_handler(DatapathId) ->
    P=case ets:lookup(?ECHO_HANDLER_TBL, DatapathId) of
        [] ->
            {ok, Pid} = echo_logic:start_link(DatapathId),
            % XXX put code to remove the entry in ets somewhere.
            true = ets:insert_new(?ECHO_HANDLER_TBL,#echo_handlers_table{
                                                   datapath_id = DatapathId,
                                                   handler_pid = Pid}),
            Pid;
        [Handler = #echo_handlers_table{}] ->
            Handler#echo_handlers_table.handler_pid
    end,
    {ok,P}.

ofd_init(Pid, IpAddr, DatapathId, Features, Version, Connection, Opt) ->
    gen_server:call(Pid,
            {init, IpAddr, DatapathId, Features, Version, Connection, Opt}).

ofd_connect(Pid, IpAddr, DatapathId, Features, Version, Connection, AuxId, Opt) ->
    gen_server:call(Pid,
            {connect, IpAddr, DatapathId, Features, Version, Connection, AuxId, Opt}).

ofd_message(Pid, Connection, Msg) ->
    gen_server:call(Pid, {message, Connection, Msg}).

ofd_error(Pid, Connection, Error) ->
    gen_server:call(Pid, {error, Connection, Error}).

ofd_disconnect(Pid, Connection, Reason) ->
    gen_server:call(Pid, {disconnect, Connection, Reason}).

ofd_terminate(Pid, Connection, Reason) ->
    gen_server:call(Pid, {terminate_from_driver, Connection, Reason}).

%% ------------------------------------------------------------------
%% gen_server Function Definitions
%% ------------------------------------------------------------------

init([DatapathId]) ->
    gen_server:cast(self(), init),
    {ok, #?STATE{datapath_id = DatapathId}}.

% handle callbacks from of_driver
handle_call({init, IpAddr, DatapathId, Features, Version, Connection, Opt}, _From, 
    State = #?STATE{datapath_id = DatapathId}) ->
    % switch connected to of_driver.
    % this is the main connection.
    State1 = State#?STATE{
        ipaddr = IpAddr,
        features = Features,
        of_version = Version,
        main_connection = Connection,
        aux_connections = [],
        callback_mod = get_opt(callback_mod, Opt),
        opt = Opt
    },
    {reply, {ok, self()}, State1};

handle_call(terminate, _From, State) ->
    {reply, ok, State};
handle_call({connect, _IpAddr, _DatapathId, _Features, _Version, Connection, AuxId, _Opt}, _From, State = #?STATE{aux_connections = AuxConnections}) ->
    State1 = State#?STATE{aux_connections = [{AuxId, Connection} | AuxConnections]},
    % switch connected to of_driver.
    % this is an auxiliary connection.
    {reply, {ok, self()}, State1};
handle_call({message, _Connection, _Message}, _From, State) ->
    ?INFO("Got message from Driver...\n"),
    % switch sent us a message
    {reply, ok, State};
handle_call({error, _Connection, _Reason}, _From, State) ->
    % error on the connection
    {reply, ok, State};
handle_call({disconnect, Connection, Reason}, _From, 
    #?STATE{ datapath_id = DatapathId } = State) ->
    % lost an auxiliary connection
    ets:delete(?ECHO_HANDLER_TBL,DatapathId),
    {reply, ok, State};
handle_call({terminate_from_driver, Connection, Reason}, _From, State) ->
    % lost the main connection
    {stop, terminated_from_driver, ok, State};
handle_call(Request, _From, State) ->
    ?WARNING("\n\n !!!!!!!!!! Handling UNHANDLED handle_call [Request : ~p]",[Request]),
    % unknown request
    {reply, ok, State}.

% needs an initialization path that does not include a connection
% two states - connected and not_connected
handle_cast(init, State) ->
    % callback module from opts
    Module = get_opt(callback_mod),

    % controller peer from opts
    Peer = get_opt(peer),

    % callback module options
    ModuleOpts = get_opt(callback_opts),

    % find out if this controller is active or standby
    Mode = my_controller_mode(Peer),

    State1 = State#?STATE{
    },
    {noreply, State1};

handle_cast(Msg, State) ->
    ?WARNING("\n\n !!!!!!!!!! Handling UNHANDLED handle_cast [Msg : ~p]",[Msg]),
    {noreply, State}.

handle_info(Info, State) ->
    ?WARNING("\n\n !!!!!!!!!! Handling UNHANDLED handle_info [Info : ~p]",[Info]),
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% ------------------------------------------------------------------
%% Internal Function Definitions
%% ------------------------------------------------------------------

get_opt(Key) ->
    get_opt(Key, []).

get_opt(Key, Options) ->
    Default = case application:get_env(echo_handler, Key) of
        {ok, V} -> V;
        undefined -> undefined
    end,
    proplists:get_value(Key, Options, Default).

my_controller_mode(_Peer) ->
    active.

sync_send(MsgFn, State) ->
    sync_send(MsgFn, [], State).

sync_send(MsgFn, Args, State) ->
    Conn = State#?STATE.main_connection,
    Version = State#?STATE.of_version,
    case of_driver:sync_send(Conn,
                            apply(of_msg_lib, MsgFn, [Version | Args])) of
        {ok, noreply} ->
            noreply;
        {ok, Reply} ->
            {Name, _Xid, Res} = of_msg_lib:decode(Reply),
            {Name, Res};
        Error ->
            % {error, Reason}
            Error
    end.
