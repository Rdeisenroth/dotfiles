#!/bin/sh
# Install ZSH if neededc
sudo pacman -S zsh git nano thefuck --needed
# Install Oh my zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh) --unattended"
# Shell Theme (Powerlevel10k)
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
# Other Plugins
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM:=~/.oh-my-zsh/custom}/plugins/zsh-completions
# Config Files

copyConfigFile() { # (source file, target dir) Target file will be renamed if existant
    local DESTINATION_FILE="$HOME/$(basename $1)"
    if [ -f "$DESTINATION_FILE" ]; then
        mv "$DESTINATION_FILE" "$DESTINATION_FILE-$(date +%H%M%S).bak" # Rename logfile if existant
        cp $1 $2                                                       # Actually copy the log
    fi
}

command_exists() {
	command -v "$@" >/dev/null 2>&1
}

copyConfigFile ".zshrc" "$HOME"
copyConfigFile ".p10k.zsh" "$HOME"
copyConfigFile ".bash_aliases" "$HOME"

setup_shell() {
    # If this user's login shell is already "zsh", do not attempt to switch.
    if [ "$(basename -- "$SHELL")" = "zsh" ]; then
        return
    fi

    # If this platform doesn't provide a "chsh" command, bail out.
    if ! command_exists chsh; then
        cat <<EOF
I can't change your shell automatically because this system does not have chsh.
${BLUE}Please manually change your default shell to zsh${RESET}
EOF
        return
    fi

    echo "Time to change your default shell to zsh:"

    # Prompt for user choice on changing the default login shell
    printf "Do you want to change your default shell to zsh? [Y/n] "
    read opt
    case $opt in
    y* | Y* | "") echo "Changing the shell..." ;;
    n* | N*)
        echo "Shell change skipped."
        return
        ;;
    *)
        echo "Invalid choice. Shell change skipped."
        return
        ;;
    esac

    # Check if we're running on Termux
    case "$PREFIX" in
    *com.termux*)
        termux=true
        zsh=zsh
        ;;
    *) termux=false ;;
    esac

    if [ "$termux" != true ]; then
        # Test for the right location of the "shells" file
        if [ -f /etc/shells ]; then
            shells_file=/etc/shells
        elif [ -f /usr/share/defaults/etc/shells ]; then # Solus OS
            shells_file=/usr/share/defaults/etc/shells
        else
            fmt_error "could not find /etc/shells file. Change your default shell manually."
            return
        fi

        # Get the path to the right zsh binary
        # 1. Use the most preceding one based on $PATH, then check that it's in the shells file
        # 2. If that fails, get a zsh path from the shells file, then check it actually exists
        if ! zsh=$(which zsh) || ! grep -qx "$zsh" "$shells_file"; then
            if ! zsh=$(grep '^/.*/zsh$' "$shells_file" | tail -1) || [ ! -f "$zsh" ]; then
                fmt_error "no zsh binary found or not present in '$shells_file'"
                fmt_error "change your default shell manually."
                return
            fi
        fi
    fi

    # We're going to change the default shell, so back up the current one
    if [ -n "$SHELL" ]; then
        echo $SHELL >~/.shell.pre-oh-my-zsh
    else
        grep "^$USER:" /etc/passwd | awk -F: '{print $7}' >~/.shell.pre-oh-my-zsh
    fi

    # Actually change the default shell to zsh
    if ! chsh -s "$zsh"; then
        fmt_error "chsh command unsuccessful. Change your default shell manually."
    else
        export SHELL="$zsh"
        echo "Shell successfully changed to '$zsh'."
    fi
    echo
}
setup_shell
echo "run zsh to try it"
echo "done :D"
