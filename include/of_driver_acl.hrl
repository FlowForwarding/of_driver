-define(ACL_TBL,of_driver_acl).
-define(COLS,{ip_address                   :: atom() | inet:ip4_address() | inet:ip6_address(),
              switch_handler = ofs_handler :: any(),
              opts                         :: list()
             }).
-record(?ACL_TBL,?COLS).
