-module(of_driver_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    
    of_driver_db:install(),
    
    case of_driver_sup:start_link() of
	{ok, Pid} -> {ok, Pid};
	Error     -> Error
    end.

stop(_State) ->
    ok.
