#!/bin/sh
exec erl -pa deps/*/ebin -pa ebin \
    -boot start_sasl \
    -config system.config \
    -sname local_of_driver \
    -init_debug