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
Memory monitoring

Used the free command to check RAM usage.

free -h makes the numbers easier to read, but free -b gives us bytes for the script.

Learned that the available column is probably better to use than just free because Linux uses memory for caching.

Also learned how to pipe commands together with | and use awk to grab specific columns.

References:

https://man7.org/linux/man-pages/man1/free.1.html
https://www.gnu.org/software/gawk/manual/gawk.html



---
## AWS Notes
how to connect to the ec2 instance


---
## Documentation references


---
## Future Enhancements
1) Controlled CPU and memory stress testing.
2) Additional monitoring metrics.
3) More detailed event logging.
4) Improved deployment troubleshooting.
5) Optional CloudWatch integration.
6) Support for additional Linux distributions.