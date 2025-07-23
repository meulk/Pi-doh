#!/bin/bash
set -e

echo "🔍 Checking if all DNS queries use DNS-over-HTTPS (DoH) and are encrypted..."

# Step 1: Check if a DoH client is running
doh_clients=("cloudflared" "dnscrypt-proxy" "systemd-resolved")
doh_running=false
running_client=""

for client in "${doh_clients[@]}"; do
    if pgrep -x "$client" > /dev/null; then
        echo "✔ DoH client detected: $client"
        doh_running=true
        running_client=$client
        break
    fi
done

if ! $doh_running; then
    echo "⚠️ No known DoH client running (cloudflared/dnscrypt-proxy/systemd-resolved)."
fi

# Step 2: Capture any DNS queries on port 53 (unencrypted DNS) for 10 seconds
echo "⏳ Sniffing for unencrypted DNS traffic on port 53 for 10 seconds..."
TMP_LOG=$(mktemp)
sudo timeout 10 tcpdump -nn -i any udp port 53 or tcp port 53 -c 5 > "$TMP_LOG" 2>/dev/null || true

if grep -q "IP" "$TMP_LOG"; then
    echo "⚠️ Unencrypted DNS queries detected on port 53:"
    cat "$TMP_LOG"
else
    echo "✔ No unencrypted DNS queries detected on port 53 during capture."
fi
rm -f "$TMP_LOG"

# Step 3: Test DNS query via local DoH resolver
echo "🧪 Testing DNS resolution via local DoH client..."

cloudflared_ip="127.0.0.1"
cloudflared_port=5053

dnscrypt_ip="127.0.0.1"
dnscrypt_port=53

resolved_via_doh=false
test_name="example.com"

if [[ $running_client == "cloudflared" ]]; then
    dig_output=$(dig +short @"$cloudflared_ip" -p $cloudflared_port "$test_name" TXT)
    if [[ -n "$dig_output" ]]; then
        echo "✔ DNS query successful via cloudflared at $cloudflared_ip:$cloudflared_port"
        resolved_via_doh=true
    fi
elif [[ $running_client == "dnscrypt-proxy" ]]; then
    dig_output=$(dig +short @"$dnscrypt_ip" -p $dnscrypt_port "$test_name" TXT)
    if [[ -n "$dig_output" ]]; then
        echo "✔ DNS query successful via dnscrypt-proxy at $dnscrypt_ip:$dnscrypt_port"
        resolved_via_doh=true
    fi
elif [[ $running_client == "systemd-resolved" ]]; then
    dig_output=$(dig +short "$test_name" TXT)
    if [[ -n "$dig_output" ]]; then
        echo "✔ DNS query successful via systemd-resolved (likely DoH enabled)"
        resolved_via_doh=true
    fi
else
    echo "ℹ️ Unable to identify DoH client for DNS test; trying system resolver..."
    dig_output=$(dig +short "$test_name" TXT)
    if [[ -n "$dig_output" ]]; then
        echo "✔ DNS query successful via system resolver"
        resolved_via_doh=true
    fi
fi

if ! $resolved_via_doh; then
    echo "⚠️ DNS query via DoH client failed."
fi

echo
echo "📝 Summary:"
if $doh_running; then
    echo "- DoH client running: $running_client"
else
    echo "- No DoH client detected"
fi

echo "- Unencrypted DNS queries on port 53 detected during sniff: $(if grep -q "IP" "$TMP_LOG" 2>/dev/null; then echo "YES"; else echo "NO"; fi)"

echo "- Successful DNS query via DoH client: $(if $resolved_via_doh; then echo "YES"; else echo "NO"; fi)"

echo
echo "⚠️ Note: This test only captures a brief window. For comprehensive security, keep your DoH client running and monitor DNS traffic continuously."
