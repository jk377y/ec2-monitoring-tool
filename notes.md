# EC2 Monitoring Tool

Repository: https://github.com/jk377y/ec2-monitoring-tool/tree/main

Goal:  creating a simple tool to monitor EC2 instances


---
## Objective
App will collect metrics such as CPU utilization, memory usage, disk storage usage, and network activity from the EC2 instance and display them via a web dashboard.

I want to automate as much as possible to simplify and reliably execute the monitoring process.


Topics to address:
1) Support different EC2 IP addresses, usernames, and .pem files.
2) Use Git Bash and SSH to connect to EC2.
3) Collect CPU, memory, disk, and network information.
4) Save the collected information to JSON every few seconds.
5) Display system health using green, yellow, and red indicators.
6) Avoid requiring additional AWS services or permissions.
7) Keep the deployment process as simple as possible.


Perhaps I'll create a walkthrough guide instructing other users to install GitBash/VSCode and configure the necessary SSH settings for connecting to their EC2 instances.


---
## Linux Notes


---
### SSH connectivity instructions



---
### To see processor statistics in the EC2 terminal run: ```head -n 1 /proc/stat```
the output should contain:
|Position | Name | Meaning
---|---|---
1 | user | Running regular programs
2 | nice | Running programs with adjusted priority
3 | system | Running operating system code
4 | idle | Not doing work
5 | iowait | Waiting for input/output operations
6 | irq | Handling hardware interrupts
7 | softirq | Handling software interrupts
8 | steal | Time taken by the virtualization host
9–10 | guest fields | Guest CPU accounting, already included in earlier counters
---

### <u>CPU monitoring</u>

Found out Linux has a /proc/stat file that tracks CPU activity.

Apparently the numbers aren't percentages. We have to grab two readings and calculate how much the CPU was working between them.

Used read to grab the numbers and Bash arithmetic $((...)) to do the calculations.

Also learned $(...) and $((...)) do completely different things.

Reference:
https://www.kernel.org/doc/html/v6.8/filesystems/proc.html

Bash arithmetic:
https://www.gnu.org/software/bash/manual/html_node/Shell-Arithmetic.html


### <u>Memory monitor</u>

Used the free command to check RAM usage.

free -h makes the numbers easier to read, but free -b gives us bytes for the script.

Learned that the available column is probably better to use than just free because Linux uses memory for caching.

Also learned how to pipe commands together with | and use awk to grab specific columns.

References:

https://man7.org/linux/man-pages/man1/free.1.html
https://www.gnu.org/software/gawk/manual/gawk.html


### <u>Disk monitoring</u>
```DISK_USAGE=$(df -P / | awk 'NR == 2 {gsub(/%/, "", $5); print $5}')```
df -P / produces this:
|Filesystem | 1024-blocks | Used | Available | Capacity | Mounted on
---|---|---|---|---|---
/dev/xvda1 | 8192000 | 2048000 | 6144000 | 25% | /

NR — The current line number being processed.<br>
== 2 — Only do something when we're on line 2.<br>
print $5 — Print the fifth column.<br>

Part | Meaning
gsub | Global substitution (replace matching text)
/%/	| Find the % symbol
""	| Replace it with nothing
$5	| Perform that replacement on column 5

Reference:<br>
https://www.gnu.org/software/coreutils/manual/html_node/df-invocation.html
https://www.gnu.org/software/gawk/manual/html_node/String-Functions.html


### <u>Network monitoring</u><br>
```
NET_IFACE=$(ip -4 route show default | awk '{for (i=1; i<=NF; i++) if ($i=="dev") {print $(i+1); exit}}')
```

Part | Meaning
---|---
ip -4 route show default | Displays default IPv4 routes
\| | Sends the result to awk
for | Loops through the fields in the output
NF | The number of fields in the current line
$i == "dev" | Finds the field containing dev
$(i+1) | The field immediately after dev, containing the interface name
exit | Stops awk after finding the first match


- Used ip route show default to find which network interface the server uses.<br>
- Linux also has some files under /sys/class/net/ that keep track of network traffic.<br>
- rx_bytes tracks received bytes.<br>
- tx_bytes tracks transmitted bytes.<br>
- The numbers keep increasing, so I had to check them twice, one second apart, to figure <br>
- out how much data was moving.<br>
- Divided by 1024 to get KiB/s.<br>
- This is measuring actual network traffic, not a percentage of the maximum available bandwidth.

References:<br>
https://docs.kernel.org/networking/statistics.html<br>
https://man7.org/linux/man-pages/man8/ip-route.8.html<br>


### <u>Writing the JSON File</u>
Part | Meaning
---|---
${BASH_SOURCE[0]} | Path to the current Bash script
dirname | Removes the filename, leaving the directory
cd | Moves into that directory
&& | Only runs the next command if the first succeeds
pwd | Prints the current directory



### <u>Writing the JSON File</u>

Started saving our metrics to a JSON file instead of just printing everything in the terminal.

Used a while true loop so the script keeps running. The CPU and network checks already take about 2 seconds combined, so I'm going to use that for our refresh rate.

Also learned about EOF, which lets us write several lines to a file at once.

I'm saving the JSON to a temporary file first, then using mv to replace the old file. This should keep the website from reading the JSON while it's still being written.

References:<br>
https://www.gnu.org/software/bash/manual/html_node/Looping-Constructs.html<br>
https://www.gnu.org/software/bash/manual/html_node/Redirections.html<br>
https://www.gnu.org/software/coreutils/manual/html_node/mv-invocation.html<br>


### <u>Managing background processes</u>
- Started working on manage.sh so I don't have to leave the terminal running just to collect metrics.
- Learned about PIDs (Process IDs). Linux gives each running process a number that we can use to find or stop it.
- Used nohup with & to run the monitoring script in the background.
- Also found out that kill -0 doesn't actually kill anything. It just checks whether we can signal the process.
- The script saves its PID in a file so we can find it again.

References:

https://www.gnu.org/software/coreutils/manual/html_node/nohup-invocation.html

https://www.gnu.org/software/bash/manual/html_node/Special-Parameters.html

https://www.gnu.org/software/coreutils/manual/html_node/kill-invocation.html

---
## AWS Notes
how to connect to the ec2 instance


---

## Documentation references
File transfer from local env to ec2 via scp (I needed to xfer the script for initial testing, it will be automated later): <br>
https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/linux-file-transfer-scp.html?utm_source=chatgpt.com

```
scp -i ./labsuser.pem \
  remote/scripts/monitor.sh \
  ec2-user@<LAB_PUBLIC_IP>:~/ec2-monitoring-tool/remote/scripts/
```



---
## Future Enhancements
1) Controlled CPU and memory stress testing.
2) Additional monitoring metrics.
3) More detailed event logging.
4) Improved deployment troubleshooting.
5) Optional CloudWatch integration.
6) Support for additional Linux distributions.