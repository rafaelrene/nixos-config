anchor=com.apple/000.nixos-workstation
rules=/etc/pf.anchors/nixos-workstation
state=/var/run/nixos-workstation-firewall

/sbin/pfctl -n -a "$anchor" -f "$rules"
main_rules=$(/sbin/pfctl -sr)
if ! printf '%s\n' "$main_rules" | /usr/bin/grep -Fq 'anchor "com.apple/*"'; then
	if [[ -n "$main_rules" || -n "$(/sbin/pfctl -sn)" ]]; then
		printf >&2 'The existing PF ruleset has no Apple anchor; refusing to replace it.\n'
		exit 1
	fi
	/sbin/pfctl -f /etc/pf.conf
fi
/sbin/pfctl -a "$anchor" -f "$rules"

/usr/bin/install -d -m 0700 "$state"
previous=''
if [[ -f "$state/token" ]]; then
	previous=$(cat "$state/token")
fi
temporary=$(/usr/bin/mktemp "$state/token.XXXXXXXX")
trap 'rm -f "$temporary"' EXIT
enabled=$(/sbin/pfctl -E 2>&1)
printf '%s\n' "$enabled" | /usr/bin/awk '/Token :|Token:/ {print $NF}' >"$temporary"
[[ -s "$temporary" ]]
mv -f "$temporary" "$state/token"
if [[ -n "$previous" ]]; then
	/sbin/pfctl -X "$previous" || printf >&2 'The previous PF enable reference was already released.\n'
fi
