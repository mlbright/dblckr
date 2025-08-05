

1. Create the files as shown above
2. Run `make install` to build and install the service
3. Check service status with `systemctl status ec2-monitor`

This service will:
- Use IMDSv2 (more secure) with token-based authentication
- Check every 5 seconds for spot interruption notices and rebalance recommendations
- Log findings to the system journal
- Automatically restart if it crashes
- Start automatically on system boot

You can extend the `checkMetadata` function to take specific actions when interruptions are detected, such as draining connections, saving state, or triggering a graceful shutdown process.

