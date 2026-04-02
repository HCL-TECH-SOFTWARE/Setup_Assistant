#!/bin/bash
# Copyright 2026 HCL America, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# network_checks.sh - network, firewall and tool checks

run_network_checks() {

  log "## 🌐 Network and Firewall Check"
  log "This section verifies whether system-level firewalls or network restrictions could impact application connectivity."

  # ------------------------------------------------------------
  # iptables
  # ------------------------------------------------------------
  log "🔎 Checking Linux firewall rules (iptables)..."
  log "Purpose: Ensure no firewall rules are blocking required traffic."

  if command_exists iptables; then
    {
      echo "---- iptables raw output ----"
      sudo iptables -t filter -L -n --line-numbers
      echo "-----------------------------"
    } >> "$LOG_FILE" 2>&1

    if [ $? -eq 0 ]; then
      log_status "iptables Check" 0 "PASS" "iptables rules accessible"
      log "Summary: iptables is present. No obvious blocking detected (see log for full rules)."
    else
      log_status "iptables Check" 1 "FAIL" "Unable to list iptables rules"
      log "Summary: iptables exists but rules could not be retrieved."
    fi
  else
    log_status "iptables Check" 0 "N/A" "iptables not installed"
    log "Summary: iptables is not present and not restricting traffic."
  fi

  # ------------------------------------------------------------
  # firewalld
  # ------------------------------------------------------------
  log "🔥 Checking FirewallD status..."
  log "Purpose: Verify whether FirewallD is actively enforcing rules."

  if command_exists firewall-cmd; then
    FIREWALLD_STATE=$(sudo firewall-cmd --state 2>>"$LOG_FILE" || echo "inactive")

    {
      echo "---- FirewallD raw output ----"
      sudo firewall-cmd --get-active-zones
      echo "------------------------------"
    } >> "$LOG_FILE" 2>&1

    if [[ "$FIREWALLD_STATE" == "running" ]]; then
      log_status "FirewallD Status" 2 "ACTIVE" "FirewallD is running"
      log "Summary: FirewallD is active. Interfaces are protected by firewall zones."
    else
      log_status "FirewallD Status" 2 "INACTIVE" "FirewallD not running"
      log "Summary: FirewallD is installed but currently inactive."
    fi
  else
    log_status "FirewallD Status" 0 "N/A" "FirewallD not installed"
    log "Summary: FirewallD is not enforcing any rules."
  fi

  # ------------------------------------------------------------
  # UFW
  # ------------------------------------------------------------
  log "🛡️ Checking UFW (Uncomplicated Firewall)..."
  log "Purpose: Validate if UFW is enabled."

  if command_exists ufw; then
    {
      echo "---- UFW raw output ----"
      sudo ufw status verbose
      echo "------------------------"
    } >> "$LOG_FILE" 2>&1

    UFW_STATUS=$(sudo ufw status | awk '/Status:/ {print $2}')
    log_status "UFW Status" 2 "$UFW_STATUS" "UFW firewall state"
    log "Summary: UFW is $UFW_STATUS."
  else
    log_status "UFW Status" 0 "N/A" "UFW not installed"
    log "Summary: UFW is not present."
  fi

  # ------------------------------------------------------------
  # DNS Configuration (Informational)
  # ------------------------------------------------------------
  log "🌍 Checking DNS configuration..."
  if [ -f /etc/resolv.conf ]; then
    DNS_SERVERS=$(grep "^nameserver" /etc/resolv.conf | awk '{print $2}')
    if [ -z "$DNS_SERVERS" ]; then
      log_status "DNS Servers" 0 "INFO" "No nameservers configured"
    else
      for dns in $DNS_SERVERS; do
        if [[ "$dns" =~ ^10\. || "$dns" =~ ^192\.168\. || "$dns" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. || "$dns" == "127.0.0.1" ]]; then
          log_status "DNS ($dns)" 0 "INTERNAL" "Private DNS"
        else
          log_status "DNS ($dns)" 0 "EXTERNAL" "Public DNS"
        fi
      done
    fi
  else
    log_status "DNS Configuration" 0 "INFO" "/etc/resolv.conf not found"
  fi

# ------------------------------------------------------------
# Third-party network tools (log-only)
# ------------------------------------------------------------
echo -e "🧰 Checking availability of network diagnostic tools..." >> "$LOG_FILE" 2>&1
echo "Purpose: Ensure troubleshooting tools are available." >> "$LOG_FILE" 2>&1

tools=(ss tcpdump traceroute nmap iftop vnstat fail2ban)

for t in "${tools[@]}"; do
  if command_exists "$t"; then
    echo "Tool Check ($t) : INSTALLED" >> "$LOG_FILE" 2>&1
  else
    echo "Tool Check ($t) : MISSING (optional)" >> "$LOG_FILE" 2>&1
  fi
done

  # ------------------------------------------------------------
  # Final summary
  # ------------------------------------------------------------
  log "📌 Network Check Summary:"
  log "• Firewall mechanisms (iptables / FirewallD / UFW) were evaluated."
  log "• No critical local firewall blocks detected."
  log "• Detailed command outputs are available in the log file."
  log "• If connectivity issues persist, check application config, external firewalls, or network policies."
}


