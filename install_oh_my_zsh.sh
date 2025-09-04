#!/bin/zsh
# install_oh_my_zsh.sh
# Script to install Oh My Zsh and recommended plugins on macOS

set -e

# Install Oh My Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "Installing Oh My Zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || {
    echo "Oh My Zsh installation failed." >&2
    exit 1
  }
else
  echo "Oh My Zsh is already installed."
fi

# Install zsh-syntax-highlighting
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" ]; then
  echo "Installing zsh-syntax-highlighting..."
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
else
  echo "zsh-syntax-highlighting is already installed."
fi

# Install zsh-autosuggestions
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ]; then
  echo "Installing zsh-autosuggestions..."
  git clone https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
else
  echo "zsh-autosuggestions is already installed."
fi

echo "\nInstallation complete!"
echo "To enable plugins, add them to the plugins array in your ~/.zshrc:"
echo "  plugins=(git zsh-syntax-highlighting zsh-autosuggestions)"
