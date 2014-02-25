-module(of_driver_handler_mock).

-include_lib("eunit/include/eunit.hrl").

-export([
    init/6,
    handle_connect/7,
    handle_message/2,
    handle_error/2,
    handle_disconnect/2,
    terminate/2
]).

% init param is the ets table to capture the connection
init(_IpAddr, _DataPathId, _Features, _Version, Connection, ConnTable) ->
    true = ets:insert(ConnTable, {0, Connection}),
    {ok, callback_state}.

handle_connect(_IpAddr, _DataPathId, _Features, _Version, Connection, AuxId, ConnTable) ->
    true = ets:insert(ConnTable, {AuxId, Connection}),
    {ok, callback_state}.

handle_message(_Msg, State) ->
    {ok, State}.

handle_error(_Msg, State) ->
    {ok, State}.

handle_disconnect(_Reason, _State) ->
    ok.

terminate(_Reason, _State) ->
    ok.
