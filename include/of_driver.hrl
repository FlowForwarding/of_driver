%%------------------------------------------------------------------------------
%% copyright 2014 flowforwarding.org
%%
%% licensed under the apache license, version 2.0 (the "license");
%% you may not use this file except in compliance with the license.
%% you may obtain a copy of the license at
%%
%%     http://www.apache.org/licenses/license-2.0
%%
%% unless required by applicable law or agreed to in writing, software
%% distributed under the license is distributed on an "as is" basis,
%% without warranties or conditions of any kind, either express or implied.
%% see the license for the specific language governing permissions and
%% limitations under the license.
%%-----------------------------------------------------------------------------

%% @author erlang solutions ltd. <openflow@erlang-solutions.com>
%% @copyright 2014 flowforwarding.org

-define(DATAPATH_TBL,   of_driver_datapath).
-define(SWITCH_CONN_TBL,of_driver_switch_connection).
-define(SYNC_MSG_TBL,   of_driver_sync_message).

%% Opt is an Erlang term that sets options for the handling of this IP address. 
-type allowance() :: [{IpAddr        :: tuple(),%% {0,0,0,0}
                       SwitchHandler :: atom(), %% usually  ofs_handler
                       Opts          :: list()  %% init_opt | enable_ping | ping_timeout | ping_idle | multipart_timeout
                      }].
