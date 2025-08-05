.PHONY: build install uninstall clean

build:
	go build -o ec2-monitor main.go

install: build
	sudo cp ec2-monitor /usr/local/bin/
	sudo cp ec2-monitor.service /etc/systemd/system/
	sudo systemctl daemon-reload
	sudo systemctl enable ec2-monitor.service
	sudo systemctl start ec2-monitor.service

uninstall:
	sudo systemctl stop ec2-monitor.service
	sudo systemctl disable ec2-monitor.service
	sudo rm -f /etc/systemd/system/ec2-monitor.service
	sudo rm -f /usr/local/bin/ec2-monitor

clean:
	rm -f ec2-monitor
