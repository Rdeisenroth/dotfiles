#! /bin/bash

# $1: monitor name
# $2: monitor id
generate_workspaces() {
    echo -n "workspace=$1,$(echo $(echo $2)1 | sed 's/^0*//')\n"
    for i in {1..9}; do
        echo -n "wsbind=$(echo $2$i | sed 's/^0*//'),$1\n"
    done
}

MONITORS=`hyprctl monitors -j`
# now do the rest
for MONITOR in $(echo $MONITORS | jq -r '.[].name'); do
    #echo "generate_workspaces $MONITOR $(echo $MONITORS | jq -r ".[] | select(.name == \"$MONITOR\") | .id")"
    RESULT="$RESULT$(generate_workspaces $MONITOR $(echo $MONITORS | jq -r ".[] | select(.name == \"$MONITOR\") | .id"))"
    DONE="$DONE $MONITOR"
done
# create workspaces.conf if it doesn't exist
if [ ! -f ~/.config/hypr/workspaces.conf ]; then
    touch ~/.config/hypr/workspaces.conf
fi
echo -e $RESULT > ~/.config/hypr/workspaces.conf