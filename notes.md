# EC2 Monitoring Tool

Repository: https://github.com/jk377y/ec2-monitoring-tool/tree/main

Goal:  creating a simple tool to monitor EC2 instances

## Objective
It will collect metrics such as CPU utilization, memory usage, disk storage usage, and network activity from the EC2 instance and display them via a web dashboard.

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

## Linux Notes
ssh connectivity instructions

## AWS Notes
how to connect to the ec2 instance

## Documentation references

## Future Enhancements
1) Controlled CPU and memory stress testing.
2) Additional monitoring metrics.
3) More detailed event logging.
4) Improved deployment troubleshooting.
5) Optional CloudWatch integration.
6) Support for additional Linux distributions.