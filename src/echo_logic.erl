
%%%-------------------------------------------------------------------
%%% @copyright (C) 1999-2013, Erlang Solutions Ltd
%%% @author Ruan Pienaar <ruan.pienaar@erlang-solutions.com>
%%% @doc 
%%% gen_server to handle the connection from of_driver
%%% @end
%%%-------------------------------------------------------------------
-module(echo_logic).
-copyright("2013, Erlang Solutions Ltd.").

-behaviour(gen_server).

-export([start_link/6, listall/1]).

-export([   
        init/1,
        handle_call/3,
        handle_cast/2,
        handle_info/2,
        terminate/2,
        code_change/3
        ]).

-define(STATE,echo_logic_state).

-include_lib("of_protocol/include/of_protocol.hrl").
-include_lib("of_driver/include/of_driver_logger.hrl").

-record(?STATE, { version,
                  conn,
                  aux_conns = [],
                  xid,
                  ip_address,
                  datapath_id,
                  features_reply,
                  opts,
                  loop_ref
                }).

listall(Pid) ->
  gen_server:call(Pid,listall).

start_link(IpAddr,DatapathInfo,FeaturesReply,Version,Conn,Opts) ->
    gen_server:start_link(?MODULE, [IpAddr,DatapathInfo,FeaturesReply,Version,Conn,Opts], []).

init([IpAddr,DatapathInfo,FeaturesReply,Version,Conn,Opts]) ->
    case of_driver_utils:proplist_default(enable_ping, Opts, false) of
        true ->
            gen_server:cast(self(), ping);
        false ->
            ok
    end,
    {ok, #?STATE{version        = Version, 
                 conn           = Conn,
                 ip_address     = IpAddr,
                 datapath_id    = DatapathInfo,
                 features_reply = FeaturesReply,
                 opts           = Opts
                }}.

handle_call(state,_From,State) ->
    {reply,{ok,State},State};
handle_call({message, Msg},_From,State) ->
    DecodedMsg = of_msg_lib:decode(Msg),
    ?INFO("Handling message:~p ... \n",[DecodedMsg]),
    handle_message(self(),undefined,DecodedMsg, State),
    {reply,{ok,State},State};
handle_call({connect, AuxConn, ConnRole, AuxId} ,_From,#?STATE{aux_conns = AuxConns} = State) ->
    UpdatedState = State#?STATE{aux_conns = [{AuxConn, ConnRole, AuxId} | AuxConns]},
    {reply, {ok,UpdatedState}, UpdatedState};
handle_call({disconnect, AuxConn},_From,#?STATE{aux_conns = AuxConns} = State) ->
    UpdatedState = State#?STATE{aux_conns = lists:deleted(AuxConn, AuxConns)},
    {reply, {ok,UpdatedState}, UpdatedState};

handle_call(listall,_From,State) ->
    {reply,{ok,State#?STATE.aux_conns}, State};

handle_call(_Request, _From, State) ->
    {reply, ok, State}.
    
handle_cast({message, Msg}, State) ->
    DecodedMsg = of_msg_lib:decode(Msg),
    handle_message(self(),undefined,DecodedMsg, State),
    {noreply, State};
handle_cast(ping, #?STATE{opts = Opts} = State) ->
    case of_driver_utils:proplist_default(enable_ping, Opts, false) of
        true ->
            Timeout = of_driver_utils:proplist_default(ping_timeout, Opts, 10000),
            {ok,TRef} = timer:apply_after(Timeout, gen_server, cast, [self(),do_ping]),
            {noreply,State#?STATE{loop_ref=TRef}};
        false ->
            {noreply,State}
    end;
handle_cast(do_ping, #?STATE{conn    = Conn, 
                             version = Version } = State) ->
    ?INFO(" sending ping_request to switch from handler (~p) ... \n",[self()]),
    {ok,Xid} = of_driver:gen_xid(Conn),
    {ok,EchoRequest} = of_driver:set_xid(of_msg_lib:echo_request(Version, <<1,2,3,4,5,6,7>>),Xid),
    of_driver:send(Conn, EchoRequest),
    gen_server:cast(self(),ping),
    {noreply, State#?STATE{xid = Xid}};
handle_cast(close_connection,#?STATE{ loop_ref = TRef, opts = Opts } = State) ->
    case of_driver_utils:proplist_default(enable_ping, Opts, false) of
        true ->
            {ok, cancel} = timer:cancel(TRef);
        false ->
            ok 
    end,
    {stop, no_connection, State#?STATE{conn = undefined, aux_conns = []}};
handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

handle_message(_Pid, _Conn, #ofp_message{ type = echo_reply } = _Msg, #?STATE{xid = _Xid} = State) ->
    {ok, State};
handle_message(_Pid, _Conn, _Msg, State) ->
    {ok, State}.