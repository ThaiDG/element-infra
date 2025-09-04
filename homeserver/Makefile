.PHONY: select-workspace init plan apply destroy \
	refresh sygnal-refresh synapse-refresh coturn-refresh element-refresh

# OS detection: windows, macos (darwin), linux
ifeq ($(OS),)
	UNAME_S := $(shell uname -s 2>/dev/null)
	ifeq ($(UNAME_S),Linux)
		OS := linux
	else ifeq ($(UNAME_S),Darwin)
		OS := macos
	else ifeq ($(UNAME_S),)
		OS := windows
	else
		OS := unknown
	endif
endif

ifeq ($(OS),windows)
	SHELL := powershell.exe
else
	SHELL := /bin/zsh
endif

init:
ifeq ($(OS),windows)
	@powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(CURDIR)/terraform-deploy.ps1" -Action init
else ifeq ($(OS),macos)
	@zsh ./terraform-deploy.sh -Action init
else
	@./terraform-deploy.sh -Action init
endif

select-workspace: init
ifeq ($(OS),windows)
	@powershell -ExecutionPolicy Bypass -File select-workspace.ps1
else ifeq ($(OS),macos)
	@zsh ./select-workspace.sh
else
	@bash -c "./select-workspace.sh"
endif

plan: select-workspace
ifeq ($(OS),windows)
	@powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(CURDIR)/terraform-deploy.ps1" -Action plan
else ifeq ($(OS),macos)
	@zsh ./terraform-deploy.sh -Action plan
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
else ifeq ($(OS),macos)
	ifeq ($(origin AUTOAPPROVE), undefined)
		@zsh ./terraform-deploy.sh -Action apply
	else
		@zsh ./terraform-deploy.sh -Action apply -AutoApprove
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
else ifeq ($(OS),macos)
	ifeq ($(origin AUTOAPPROVE), undefined)
		@zsh ./terraform-deploy.sh -Action destroy
	else
		@zsh ./terraform-deploy.sh -Action destroy -AutoApprove
	endif
else
	@./terraform-deploy.sh -Action destroy
endif

# Refresh instances in the specified Auto Scaling Groups
# The role is to refresh the instances of the dev environment only
synapse-refresh:
ifeq ($(OS),windows)
	@powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(CURDIR)/refresh-instance.ps1" -AsgPrefix "synapse-server"
else
	@echo "synapse-refresh is only supported on Windows."
endif

sygnal-refresh:
ifeq ($(OS),windows)
	@powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(CURDIR)/refresh-instance.ps1" -AsgPrefix "sygnal-service"
else
	@echo "sygnal-refresh is only supported on Windows."
endif

coturn-refresh:
ifeq ($(OS),windows)
	@powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(CURDIR)/refresh-instance.ps1" -AsgPrefix "coturn"
else
	@echo "coturn-refresh is only supported on Windows."
endif

element-refresh:
ifeq ($(OS),windows)
	@powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(CURDIR)/refresh-instance.ps1" -AsgPrefix "element-web"
else
	@echo "element-refresh is only supported on Windows."
endif

livekit-refresh:
ifeq ($(OS),windows)
	@powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(CURDIR)/refresh-instance.ps1" -AsgPrefix "livekit-server"
else
	@echo "livekit-refresh is only supported on Windows."
endif

refresh: synapse-refresh sygnal-refresh coturn-refresh element-refresh livekit-refresh
