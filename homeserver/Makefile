.PHONY: select-workspace init plan apply destroy

# I will update the script to support Linux and MacOS when I can access to a Linux or MacOS environment.
# This Makefile is designed to work with both Windows and Unix-like systems (Linux, MacOS).
OS ?= windows
# Default ENV would be demo if not specified

ifeq ($(OS),windows)
	SHELL := powershell.exe
else
	SHELL := /bin/bash
endif

init:
ifeq ($(OS),windows)
	powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(CURDIR)/terraform-deploy.ps1" -Action init
else
	./terraform-deploy.sh -Action init
endif

select-workspace: init
ifeq ($(OS),windows)
	@powershell -ExecutionPolicy Bypass -File select-workspace.ps1
else
	@bash -c "./select-workspace.sh"
endif

plan: select-workspace
ifeq ($(OS),windows)
	powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(CURDIR)/terraform-deploy.ps1" -Action plan
else
	./terraform-deploy.sh -Action plan
endif

apply: select-workspace
ifeq ($(OS),windows)
	ifeq ($(origin AUTOAPPROVE), undefined)
		powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(CURDIR)/terraform-deploy.ps1" -Action apply -AutoApprove
	else
		powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(CURDIR)/terraform-deploy.ps1" -Action apply
	endif
else
	./terraform-deploy.sh -Action apply
endif

destroy: select-workspace
ifeq ($(OS),windows)
	ifeq ($(origin AUTOAPPROVE), undefined)
		powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(CURDIR)/terraform-deploy.ps1" -Action destroy -AutoApprove
	else
		powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(CURDIR)/terraform-deploy.ps1" -Action destroy
	endif
else
	./terraform-deploy.sh -Action destroy
endif
