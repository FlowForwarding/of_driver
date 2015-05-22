-module (of_driver_message_4).

-include_lib("of_protocol/include/of_protocol.hrl").
-include_lib("of_protocol/include/ofp_v4.hrl").

-export([append_body/2]).

append_body(#ofp_message{ body = #ofp_flow_stats_reply{ body = InnerBody1 } } = Msg1,
            #ofp_message{ body = #ofp_flow_stats_reply{ body = InnerBody2 } } = _Msg2) ->
    Msg1#ofp_message{ body = #ofp_flow_stats_reply{ body = lists:flatten([InnerBody1|InnerBody2]) } };

append_body(#ofp_message{ body = #ofp_table_stats_reply{ body = InnerBody1 } } = Msg1,
            #ofp_message{ body = #ofp_table_stats_reply{ body = InnerBody2 } } = _Msg2) ->
    Msg1#ofp_message{ body = #ofp_table_stats_reply{ body = lists:flatten([InnerBody1|InnerBody2]) } };

append_body(#ofp_message{ body = #ofp_port_stats_reply{ body = InnerBody1 } } = Msg1,
            #ofp_message{ body = #ofp_port_stats_reply{ body = InnerBody2 } } = _Msg2) ->
    Msg1#ofp_message{ body = #ofp_port_stats_reply{ body = lists:flatten([InnerBody1|InnerBody2]) } };

append_body(#ofp_message{ body = #ofp_port_desc_reply{ body = InnerBody1 } } = Msg1,
            #ofp_message{ body = #ofp_port_desc_reply{ body = InnerBody2 } } = _Msg2) ->
    Msg1#ofp_message{ body = #ofp_port_desc_reply{ body = lists:flatten([InnerBody1|InnerBody2]) } };

append_body(#ofp_message{ body = #ofp_queue_stats_reply{ body = InnerBody1 } } = Msg1,
            #ofp_message{ body = #ofp_queue_stats_reply{ body = InnerBody2 } } = _Msg2) ->
    Msg1#ofp_message{ body = #ofp_queue_stats_reply{ body = lists:flatten([InnerBody1|InnerBody2]) } };

append_body(#ofp_message{ body = #ofp_group_stats_reply{ body = InnerBody1 } } = Msg1,
            #ofp_message{ body = #ofp_group_stats_reply{ body = InnerBody2 } } = _Msg2) ->
    Msg1#ofp_message{ body = #ofp_group_stats_reply{ body = lists:flatten([InnerBody1|InnerBody2]) } };

append_body(#ofp_message{ body = #ofp_group_desc_reply{ body = InnerBody1 } } = Msg1,
            #ofp_message{ body = #ofp_group_desc_reply{ body = InnerBody2 } } = _Msg2) ->
    Msg1#ofp_message{ body = #ofp_group_desc_reply{ body = lists:flatten([InnerBody1|InnerBody2]) } };

append_body(#ofp_message{ body = #ofp_meter_stats_reply{ body = InnerBody1 } } = Msg1,
            #ofp_message{ body = #ofp_meter_stats_reply{ body = InnerBody2 } } = _Msg2) ->
    Msg1#ofp_message{ body = #ofp_meter_stats_reply{ body = lists:flatten([InnerBody1|InnerBody2]) } };

append_body(#ofp_message{ body = #ofp_meter_config_reply{ body = InnerBody1 } } = Msg1,
            #ofp_message{ body = #ofp_meter_config_reply{ body = InnerBody2 } } = _Msg2) ->
    Msg1#ofp_message{ body = #ofp_meter_config_reply{ body = lists:flatten([InnerBody1|InnerBody2]) } };

append_body(#ofp_message{ body = #ofp_table_features_reply{ body = InnerBody1 } } = Msg1,
            #ofp_message{ body = #ofp_table_features_reply{ body = InnerBody2 } } = _Msg2) ->
    Msg1#ofp_message{ body = #ofp_table_features_reply{ body = lists:flatten([InnerBody1|InnerBody2]) } };

append_body(_,_) -> %% Non matching...
    false.