#!/bin/sh -e
if [ -z "$GITHUB_ACTION_REPOSITORY" ]; then export GITHUB_ACTION_REPOSITORY="$GITHUB_REPOSITORY"; fi
action_tag_name="$(echo "$GITHUB_ACTION_REF" | cut -sd @ -f 2-)"
if [ -z "$action_tag_name" ]; then action_tag_name="v$(cat "$my_dir"/../../../VERSION)"; fi
if [ "$GITHUB_REPOSITORY" = "$GITHUB_ACTION_REPOSITORY" ] && dpkg -l | grep -q opentelemetry-shell; then
  :
elif [ -n "$action_tag_name" ]; then
  debian_file="$(mktemp -u).deb"
  github repos/"$GITHUB_ACTION_REPOSITORY"/releases | { if [ "$action_tag_name" = main ]; then jq '.[0]'; else jq '.[] | select(.tag_name=="'"$action_tag_name"'")'; fi } | jq -r '.assets[].browser_download_url' | grep '.deb$' | xargs wget -O "$debian_file"
  sudo -E apt-get install -y "$debian_file"
  rm "$debian_file"
else
  wget -O - https://raw.githubusercontent.com/"$GITHUB_ACTION_REPOSITORY"/main/INSTALL.sh | sh
fi
