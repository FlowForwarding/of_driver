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

-define(ACL_TBL,of_driver_acl).
-define(COLS,{ip_address     :: atom() | inet:ip4_address() | inet:ip6_address(),
              switch_handler :: any(),
              opts           :: list()
             }).
-record(?ACL_TBL,?COLS).
