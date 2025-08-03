.PHONY: select-workspace init plan apply destroy \
	refresh sygnal-refresh synapse-refresh coturn-refresh element-refresh

# I will update the script to support Linux and MacOS when I can access to a Linux or MacOS environment.
# This Makefile is designed to work with both Windows and Unix-like systems (Linux, MacOS).
OS ?= windows
# Default ENV would be dev if not specified

ifeq ($(OS),windows)
	SHELL := powershell.exe
else
	SHELL := /bin/bash
endif

init:
ifeq ($(OS),windows)
	@powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(CURDIR)/terraform-deploy.ps1" -Action init
else
	@./terraform-deploy.sh -Action init
endif

select-workspace: init
ifeq ($(OS),windows)
	@powershell -ExecutionPolicy Bypass -File select-workspace.ps1
else
	@bash -c "./select-workspace.sh"
endif

plan: select-workspace
ifeq ($(OS),windows)
	@powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(CURDIR)/terraform-deploy.ps1" -Action plan
else
	@./terraform-deploy.sh -Action plan
endif

apply: select-workspace
ifeq ($(OS),windows)
ifeq ($(origin AUTOAPPROVE), undefined)
	@powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(CURDIR)/terraform-deploy.ps1" -Action apply
else
	@powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(CURDIR)/terraform-deploy.ps1" -Action apply -AutoApprove
endif
else
	@./terraform-deploy.sh -Action apply
endif

destroy: select-workspace
ifeq ($(OS),windows)
ifeq ($(origin AUTOAPPROVE), undefined)
	@powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(CURDIR)/terraform-deploy.ps1" -Action destroy
else
	@powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(CURDIR)/terraform-deploy.ps1" -Action destroy -AutoApprove
endif
else
	@./terraform-deploy.sh -Action destroy
endif

synapse-refresh:
	@aws autoscaling start-instance-refresh --auto-scaling-group-name dev-synapse-server-asg --region ap-southeast-1

sygnal-refresh:
	@aws autoscaling start-instance-refresh --auto-scaling-group-name dev-sygnal-service-asg --region ap-southeast-1

coturn-refresh:
	@aws autoscaling start-instance-refresh --auto-scaling-group-name dev-coturn-tcp-asg --region ap-southeast-1
	@aws autoscaling start-instance-refresh --auto-scaling-group-name dev-coturn-udp-asg --region ap-southeast-1

element-refresh:
	@aws autoscaling start-instance-refresh --auto-scaling-group-name dev-element-web-asg --region ap-southeast-1

refresh: synapse-refresh sygnal-refresh coturn-refresh element-refresh
