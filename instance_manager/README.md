# Instance Manager Project

## Dependencies

### Pyenv setup

The Makefile will check and will install the pyenv if not exist

This is the step you must do manually: Add Pyenv init to bash shell profile

- Load pyenv automatically by appending the following to ~/.bash_profile if it exists,
  otherwise ~/.profile (for login shells) and ~/.bashrc (for interactive shells):

```bash
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - bash)"
```

- Restart your shell for the changes to take effect.

### Python 3.12 setup

The Makefile will check and install the Python3.12 if not exist

### Poetry setup

The Makefile will check and install the Poetry if not exist

## How to run

- To hibernate all instances in develop environment use command: `make hibernate`
- To resume all instances in develop environment, use command: `make resume`
