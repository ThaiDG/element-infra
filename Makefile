.PHONY: init plan apply destroy

# I will update the script to support Linux and MacOS when I can access to a Linux or MacOS environment.
# This Makefile is designed to work with both Windows and Unix-like systems (Linux, MacOS).
OS ?= windows

ifeq ($(OS),windows)
	SHELL := powershell.exe
else
	SHELL := /bin/bash

init:
ifeq ($(OS),windows)
	powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(CURDIR)/terraform-deploy.ps1" -Action init
else
	./terraform-deploy.sh -Action init
endif

plan:
ifeq ($(OS),windows)
	powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(CURDIR)/terraform-deploy.ps1" -Action plan
else
	./terraform-deploy.sh -Action plan
endif

apply:
ifeq ($(OS),windows)
	ifeq ($(origin AUTOAPPROVE), undefined)
		powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(CURDIR)/terraform-deploy.ps1" -Action apply -AutoApprove
	else
		powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(CURDIR)/terraform-deploy.ps1" -Action apply
else
	./terraform-deploy.sh -Action apply
endif

destroy:
ifeq ($(OS),windows)
	ifeq ($(origin AUTOAPPROVE), undefined)
		powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(CURDIR)/terraform-deploy.ps1" -Action destroy -AutoApprove
	else
		powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(CURDIR)/terraform-deploy.ps1" -Action destroy
else
	./terraform-deploy.sh -Action destroy
endif
