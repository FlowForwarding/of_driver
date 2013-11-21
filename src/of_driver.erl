-module(of_driver).

-include_lib("of_protocol/include/of_protocol.hrl").

-export([send/2,
	 send_list/2,
	 sync_send_list/2
	]).

%%------------------------------------------------------------------

-spec send(Switch :: term(), Msg :: #ofp_message{}) -> ok | {error, Reason :: term()}.
send(_Switch,#ofp_message{} = _Msg) ->
    call().

-spec send_list(Switch :: term(), [Msg :: #ofp_message{}]) -> ok | {error, Reason :: term()}.
send_list(_Switch, Msgs) when is_list(Msgs) ->
    call().

-spec sync_send_list(Switch :: term(), [Msg :: #ofp_message{}]) -> ok | {error, Msgs :: list()}.
sync_send_list(_Switch, Msgs) when is_list(Msgs) ->
    call().

call() ->
    %% do some external call...
    ok.
