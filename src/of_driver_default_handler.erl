-module(of_driver_default_handler).

-export([
    init/6,
    handle_connect/7,
    handle_message/2,
    handle_error/2,
    handle_disconnect/2,
    terminate/2
]).

init(_IpAddr, _DataPathId, _Features, _Version, _Connection, _InitOpt) ->
    {error, no_handler}.

handle_connect(_IpAddr, _DataPathId, _Features, _Version, _Connection, _AuxId, _InitOpt) ->
    {error, no_handler}.

% init/handle_connect refuse the connection, so these other callback
% functions should never be called.
handle_message(_Msg, State) ->
    {ok, State}.

handle_error(_Msg, State) ->
    {ok, State}.

handle_disconnect(_Reason, _State) ->
    ok.

terminate(_Reason, _State) ->
    ok.
