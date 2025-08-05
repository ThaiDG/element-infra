.ONESHELL:
PYENV := $(shell command -v pyenv 2>/dev/null)
POETRY := $(shell command -v poetry 2>/dev/null)
PYTHON_VERSION := 3.12

check-env:
	@if [ -z "$(PYENV)" ]; then
		echo "📦 pyenv not found. Installing pyenv...";
		curl https://pyenv.run | bash;
		export PYENV_ROOT="$$HOME/.pyenv";
		export PATH="$$PYENV_ROOT/bin:$$PATH";
		eval "$$(pyenv init - bash)";
		echo "✅ pyenv installed and initialized for this session.";
		echo "INFO: Add the following to your .bashrc to make pyenv available in every session:";
		echo 'export PYENV_ROOT="$$HOME/.pyenv"';
		echo '[[ -d $$PYENV_ROOT/bin ]] && export PATH="$$PYENV_ROOT/bin:$$PATH"';
		echo 'eval "$$(pyenv init - bash)"';
	else
		echo "✅ pyenv detected.";
	fi

	@if ! pyenv versions | grep -q "$(PYTHON_VERSION)"; then
		echo "📦 Python$(PYTHON_VERSION) not found. Installing build dependencies...";
		sudo apt-get update;
		sudo apt-get install -y make build-essential libssl-dev zlib1g-dev \
			libbz2-dev libreadline-dev libsqlite3-dev curl \
			libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev;

		echo "📦 Installing Python $(PYTHON_VERSION)...";
		pyenv install $(PYTHON_VERSION);
	else
		echo "✅ Python $(PYTHON_VERSION) already installed.";
	fi

	@if [ -z "$(POETRY)" ]; then
		echo "📦 Poetry is not installed. Installing...";
		curl -sSL https://install.python-poetry.org | python3 -;
		echo "✅ Poetry installed.";
	else
		echo "✅ Poetry detected.";
	fi

deps: check-env
	@poetry lock --quiet
	@poetry install

hibernate: deps
	@poetry run python -m instance_manager.manage_lifecycle dev hibernate

resume: deps
	@poetry run python -m instance_manager.manage_lifecycle dev resume
