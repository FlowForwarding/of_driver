#!/bin/sh
#exec erl -pa $PWD/deps/*/ebin -pa $PWD/ebin \
#    -boot start_sasl \
#    -config system.config \
#    -sname local_of_driver \
#    -s of_driver_app 

cd `dirname $0`
exec erl -sname of_driver -config $PWD/sys.config -pa $PWD/ebin $PWD/deps/*/ebin $PWD/tests -boot start_sasl -mnesia dir "'"$PWD"/Mnesia'"