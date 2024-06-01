#!/bin/bash

clear

echo -e "Super Mario 64 Steam Deck builder - script by Linux Gaming Central\n"

title="Super Mario 64 Steam Deck Builder"

# Removes unhelpful GTK warnings
zen_nospam() {
  zenity 2> >(grep -v 'Gtk' >&2) "$@"
}

# zenity functions
error() {
	e=$1
	zen_nospam --error --title="$title" --width=500 --height=100 --text "$1"
}

info() {
	i=$1
	zen_nospam --info --title "$title" --width 400 --height 75 --text "$1"
}

progress_bar() {
	t=$1
	zen_nospam --title "$title" --text "$1" --progress --pulsate --auto-close --auto-kill --width=300 --height=100

	if [ "$?" != 0 ]; then
		echo -e "\nUser canceled.\n"
	fi
}

question() {
	q=$1
	zen_nospam --question --title="$title" --width=300 height=200 --text="$1"
}

# menus
main_menu() {
	zen_nospam --width 1000 --height 350 --list --radiolist --multiple --title "$title"\
	--column ""\
	--column "Option"\
	--column="Description"\
	FALSE $SM64 "The original SM64 PC port."\
	FALSE $SM64PLUS "SM64 with more responsive controls/camera, 60 FPS support, and can continue the level after getting a star."\
	FALSE $SM64EX "SM64 with new options menu, support for texture packs, analog camera, etc."\
	FALSE $SM64EX_ALO "Fork of $SM64EX with newer camera, QoL fixes and features, etc."\
	FALSE $RENDER96 "Fork of $SM64EX with HD character models and textures."\
	FALSE OPTIONS "Download and install needed dependencies, back up save files, download hi-res textures, etc."\
	TRUE EXIT "Exit this script."
}

sub_menu() {
	s=$1
	zen_nospam --width 1000 --height 350 --list --radiolist --multiple --title "$title"\
	--column ""\
	--column "Option"\
	--column="Description"\
	FALSE INSTALL_$1 "Install $1"\
	FALSE UPDATE_$1 "Update $1"\
	FALSE PLAY_$1 "Play $1"\
	FALSE STEAM_$1 "Add $1 as a non-Steam shortcut"\
	FALSE EDIT_$1 "Adjust options for $1"\
	FALSE UNINSTALL_$1 "Uninstall $1 (warning: save data may be lost! Back it up first!)"\
	TRUE EXIT "Exit this menu."
}

options() {
	zen_nospam --width 1000 --height 300 --list --radiolist --multiple --title "$title"\
	--column ""\
	--column "Option"\
	--column="Description"\
	FALSE DEPENDENCIES "Install build dependencies. (Root password required.)"\
	FALSE UBUNTU_DEPENDENCIES "Install build dependencies for Ubuntu-based distros (Pop!_OS, Mint, etc. Root password required.)"\
	FALSE BACKUP "Backup save files"\
	FALSE INSTALL_SM64_RELOADED "Install SM64 Reloaded (hi-res textures)"\
	FALSE INSTALL_TEXTURE_PACKS "Install model/texture packs for $RENDER96 (downloading texture pack will take a while)"\
	TRUE EXIT "Exit this menu."
}

# fork options
install() {
	fork=$1
	repo=$2
	
	# check if cloned repo exists. If it does, exit
	if [ -d "$1" ]; then
		error "$1 already exists. Please run UPDATE_$1 if you wish to update $1."
	else
		(
		echo -e "Cloning repo...\n"
		git clone https://github.com/$2/$1.git

		echo -e "Copying ROM...\n"
		cp $HOME/$ROM $1/
		cd $1
		echo -e "Compiling...\n"
		make -j$(nproc)
		echo -e "Finished compiling!\n"
		) | progress_bar "Installing...this will take a minute or two."
		
		info "Installation complete!"
	fi
}

update() {
	fork=$1
	# check if directory exists. If it doesn't, exit this option
	if ! [ -d "$1" ]; then
		error "$1 doesn't exist. Please run INSTALL_$1 before running this option."
	else
		(
		cd $1

		echo -e "Updating repository...\n"
		git pull

		echo -e "Re-compiling...\n"
		make -j$(nproc)
		echo -e "Finished compiling!\n"
		) | progress_bar "Updating. This shouldn't take long."

		info "Update complete!"
	fi
}

play() {
	fork=$1
	# check to see if executable exists. Discontinue if it's not detected
	if [ -f "$1/build/$REGION${PC}/sm64.$REGION" ] || [ -f "$1/build/$REGION${PC}/sm64.$REGION.f3dex2e" ]; then
		cd $1/build/$REGION${PC}/
		./sm64.$REGION || ./sm64.$REGION.f3dex2e --skip-intro
		cd $HOME/Applications
	else
		error "Executable file not found."
	fi
}

add_to_steam() {
	fork=$1
	
	# temporarily download some python scripts, execute them, then remove them when we're done
	wget https://raw.githubusercontent.com/linuxgamingcentral/Steam-Shortcut-Manager/master/shortcuts.py
	wget https://raw.githubusercontent.com/linuxgamingcentral/Steam-Shortcut-Manager/master/crc_algorithms.py
	if [ $USER != "deck" ]; then
		python shortcuts.py "$HOME/.steam/debian-installation/userdata/$STEAMID/config/shortcuts.vdf" "$1" "$HOME/Applications/$1/build/$REGION${PC}/sm64.$REGION" $HOME/Applications/$1/build/$REGION${PC}/ "" "" "" 0 0 1 0 0 SM64
		python shortcuts.py "$HOME/.steam/debian-installation/userdata/$STEAMID/config/shortcuts.vdf" "$1" "$HOME/Applications/$1/build/$REGION${PC}/sm64.$REGION.f3dex2e" $HOME/Applications/$1/build/$REGION${PC}/ "" "" "" 0 0 1 0 0 SM64
	else
		python shortcuts.py "$HOME/.local/share/Steam/userdata/$STEAMID/config/shortcuts.vdf" "$1" "$HOME/Applications/$1/build/$REGION${PC}/sm64.$REGION" $HOME/Applications/$1/build/$REGION${PC}/ "" "" "" 0 0 1 0 0 SM64
		python shortcuts.py "$HOME/.local/share/Steam/userdata/$STEAMID/config/shortcuts.vdf" "$1" "$HOME/Applications/$1/build/$REGION${PC}/sm64.$REGION.f3dex2e" $HOME/Applications/$1/build/$REGION${PC}/ "" "" "" 0 0 1 0 0 SM64
	fi
	rm shortcuts.py crc_algorithms.py
	rm -rf __pycache__
	info "$1 added as a non-Steam shortcut! Note if Steam is open you'll need to restart it to see the changes."
}

edit_config() {
	config_file=$1

	if ! [ -f $1 ]; then
		error "$1 file not found."
	else
		xdg-open $1
	fi
}

uninstall() {
	fork=$1
	if ! [ -d $1 ]; then
		error "$1 folder not found."
	else
		if ( question "WARNING: please back up your save file from the Options menu, otherwise it might be deleted! Select Yes to continue, or No to stop." ); then
		yes |
			rm -rf $1
			info "Uninstall complete."
		else
			echo -e "\nUser selected no, continuing...\n"
		fi
	fi
}

# Check if GitHub is reachable
if ! curl -Is https://github.com | head -1 | grep 200 > /dev/null
then
    echo "GitHub appears to be unreachable, you may not be connected to the Internet."
    exit 1
fi

US_ROM=baserom.us.z64
JP_ROM=baserom.jp.z64
EU_ROM=baserom.eu.z64

# check for ROM in home. If it doesn't exist, close the program
if ! [[ -f "$HOME/$US_ROM" ]] && ! [[ -f "$HOME/$JP_ROM" ]] && ! [[ -f "$HOME/$EU_ROM" ]]; then
	error "Error: ROM not found. Place your legally-dumped SM64 ROM in $HOME and name it to $US_ROM, $JP_ROM, or $EU_ROM, depending on the region of the ROM."
	exit
fi

# assign the appropriate region ROM to a new variable
if [ -f "$HOME/$US_ROM" ]; then
	ROM=$US_ROM
elif [ -f "$HOME/$JP_ROM" ]; then
	ROM=$JP_ROM
elif [ -f "$HOME/$EU_ROM" ]; then
	ROM=$EU_ROM
fi

echo -e "ROM is $ROM"

# extract the region name from the ROM
REGION=$(cut -c 9-10 <<< $ROM)
echo -e "Region is $REGION\n"

PC=_pc

SM64=sm64-port
SM64PLUS=sm64plus
SM64EX=sm64ex
SM64EX_ALO=sm64ex-alo
RENDER96=Render96ex

# get Steam ID - for adding forks as a non-Steam shortcut
if [ $USER != "deck" ]; then
	STEAMID=$(find ~/.steam/debian-installation/userdata/ -mindepth 1 -maxdepth 1 -type d | sed -n '2p')
else
	STEAMID=$(find ~/.local/share/Steam/userdata/ -mindepth 1 -maxdepth 1 -type d | sed -n '1p')
fi
STEAMID=$(basename "$STEAMID")
echo -e "Steam ID is $STEAMID\n"

cd $HOME
mkdir -p Applications
cd Applications

# Main menu
while true; do
Choice=$(main_menu)

if [ $? -eq 1 ] || [ "$Choice" == "EXIT" ]; then
	echo Goodbye!
	exit

elif [ "$Choice" == "$SM64" ]; then
	# sub menu
	while true; do
	Choice=$(sub_menu "$SM64")

	if [ $? -eq 1 ] || [ "$Choice" == "EXIT" ]; then
		echo -e "\nUser selected EXIT, going back to main menu.\n"
		break

	elif [ "$Choice" == "INSTALL_$SM64" ]; then
		install $SM64 $SM64

	elif [ "$Choice" == "UPDATE_$SM64" ]; then
		update $SM64

	elif [ "$Choice" == "PLAY_$SM64" ]; then
		play $SM64

	elif [ "$Choice" == "STEAM_$SM64" ]; then
		add_to_steam $SM64
	
	elif [ "$Choice" == "EDIT_$SM64" ]; then
		edit_config "$SM64/build/$REGION${PC}/sm64config.txt"

	elif [ "$Choice" == "UNINSTALL_$SM64" ]; then
		uninstall $SM64
	fi
	done

elif [ "$Choice" == "$SM64PLUS" ]; then
	# sub menu
	while true; do
	Choice=$(sub_menu $SM64PLUS)

	if [ $? -eq 1 ] || [ "$Choice" == "EXIT" ]; then
		echo -e "\nUser selected EXIT, going back to main menu.\n"
		break

	elif [ "$Choice" == "INSTALL_$SM64PLUS" ]; then
		install $SM64PLUS "MorsGames"

	elif [ "$Choice" == "UPDATE_$SM64PLUS" ]; then
		update $SM64PLUS

	elif [ "$Choice" == "PLAY_$SM64PLUS" ]; then
		play $SM64PLUS

	elif [ "$Choice" == "STEAM_$SM64PLUS" ]; then
		add_to_steam $SM64PLUS
	
	elif [ "$Choice" == "EDIT_$SM64PLUS" ]; then
		edit_config "$HOME/.config/SM64Plus/settings.ini"

	elif [ "$Choice" == "UNINSTALL_$SM64PLUS" ]; then
		uninstall $SM64PLUS
	fi
	done

elif [ "$Choice" == "$SM64EX" ]; then
	# sub menu
	while true; do
	Choice=$(sub_menu $SM64EX)

	if [ $? -eq 1 ] || [ "$Choice" == "EXIT" ]; then
		echo -e "\nUser selected EXIT, going back to main menu.\n"
		break

	elif [ "$Choice" == "INSTALL_$SM64EX" ]; then
		install $SM64EX "sm64pc"

	elif [ "$Choice" == "UPDATE_$SM64EX" ]; then
		update $SM64EX

	elif [ "$Choice" == "PLAY_$SM64EX" ]; then
		play $SM64EX

	elif [ "$Choice" == "STEAM_$SM64EX" ]; then
		add_to_steam $SM64EX

	elif [ "$Choice" == "EDIT_$SM64EX" ]; then
		edit_config "$HOME/.local/share/$SM64EX/sm64config.txt"

	elif [ "$Choice" == "UNINSTALL_$SM64EX" ]; then
		uninstall $SM64EX
	fi
	done

elif [ "$Choice" == "$SM64EX_ALO" ]; then
	# sub menu
	while true; do
	Choice=$(sub_menu $SM64EX_ALO)

	if [ $? -eq 1 ] || [ "$Choice" == "EXIT" ]; then
		echo -e "\nUser selected EXIT, going back to main menu.\n"
		break

	elif [ "$Choice" == "INSTALL_$SM64EX_ALO" ]; then
		install $SM64EX_ALO "AloUltraExt"

	elif [ "$Choice" == "UPDATE_$SM64EX_ALO" ]; then
		update $SM64EX_ALO

	elif [ "$Choice" == "PLAY_$SM64EX_ALO" ]; then
		play $SM64EX_ALO

	elif [ "$Choice" == "STEAM_$SM64_ALO" ]; then
		add_to_steam $SM64_ALO

	elif [ "$Choice" == "EDIT_$SM64EX_ALO" ]; then
		edit_config "$HOME/.local/share/$SM64EX/sm64config.txt"

	elif [ "$Choice" == "UNINSTALL_$SM64EX_ALO" ]; then
		uninstall $SM64EX_ALO
	fi
	done

elif [ "$Choice" == "$RENDER96" ]; then
	# sub menu
	while true; do
	Choice=$(sub_menu $RENDER96)

	if [ $? -eq 1 ] || [ "$Choice" == "EXIT" ]; then
		echo -e "\nUser selected EXIT, going back to main menu.\n"
		break

	elif [ "$Choice" == "INSTALL_$RENDER96" ]; then
		install $RENDER96 "Render96"
		info "To enable HD models, you must first download them from the Options menu, then enable them in-game."

	elif [ "$Choice" == "UPDATE_$RENDER96" ]; then
		update $RENDER96

	elif [ "$Choice" == "PLAY_$RENDER96" ]; then
		play $RENDER96

	elif [ "$Choice" == "STEAM_$RENDER96" ]; then
		add_to_steam $RENDER96

	elif [ "$Choice" == "EDIT_$RENDER96" ]; then
		edit_config "$HOME/.local/share/$SM64EX/sm64config.txt"

	elif [ "$Choice" == "UNINSTALL_$RENDER96" ]; then
		uninstall $RENDER96
	fi
	done

# options menu
elif [ "$Choice" == "OPTIONS" ]; then
	while true; do
	Choice=$(options)

	if [ $? -eq 1 ] || [ "$Choice" == "EXIT" ]; then
		echo -e "\nUser selected EXIT, going back to main menu.\n"
		break

	elif [ "$Choice" == "DEPENDENCIES" ]; then
		sudo_password=$(zen_nospam --password --title="$title")
		if [[ ${?} != 0 || -z ${sudo_password} ]]; then
			echo -e "User canceled.\n"
		elif ! sudo -kSp '' [ 1 ] <<<${sudo_password} 2>/dev/null; then
			echo -e "User entered wrong password.\n"
			error "Wrong password."
		else
			(
			# Disable the filesystem until we're done
			echo -e "Disabling read-only mode...\n"
			sudo -Sp '' steamos-readonly disable <<<${sudo_password}

			# Get pacman keys
			echo -e "Populating pacman keys...\n"
			sudo pacman-key --init
			sudo pacman-key --populate archlinux holo

			echo -e "Installing essential build tools...\n"
			sudo pacman -S --needed --noconfirm base-devel "$(cat /usr/lib/modules/$(uname -r)/pkgbase)-headers"

			# some additional commands needed to install SM64Plus
			if ( question "Additional tools are required to install $SM64PLUS. Would you like to install these?" ); then
			yes |
				sudo sed -i 's/\(^\[.*\]\)/\1\nSigLevel = Never/g' /etc/pacman.conf
				sudo pacman -Syyu --noconfirm
				sudo pacman -S --needed $(pacman -Ql | grep include | cut -d' ' -f1 | awk '!a[$0]++') --noconfirm
				sudo pacman --overwrite=/etc/ld.so.conf.d/fakeroot.conf -S --needed --noconfirm python sdl2 glew
			else
				echo -e "\nUser selected no, continuing...\n"
			fi

			# restore the read-only FS
			echo -e "Restoring read-only filesystem...\n"
			sudo steamos-readonly enable
			echo -e "Done.\n"
			) | progress_bar "Installing dependencies, please wait..."

			info "Make dependencies installed!"
		fi
	
	elif [ "$Choice" == "UBUNTU_DEPENDENCIES" ]; then
		sudo_password=$(zen_nospam --password --title="$title")
		if [[ ${?} != 0 || -z ${sudo_password} ]]; then
			echo -e "User canceled.\n"
		elif ! sudo -kSp '' [ 1 ] <<<${sudo_password} 2>/dev/null; then
			echo -e "User entered wrong password.\n"
			error "Wrong password."
		else
			(
			sudo -Sp '' sudo apt update <<<${sudo_password}

			echo -e "Installing essential build tools...\n"
			sudo apt install -y git build-essential pkg-config libusb-1.0-0-dev libsdl2-dev

			echo -e "Done.\n"
			) | progress_bar "Installing dependencies, please wait..."

			info "Make dependencies installed!"
		fi

	elif [ "$Choice" == "BACKUP" ]; then
		mkdir -p $HOME/sm64_save_backups
		mkdir -p $HOME/sm64_save_backups/$RENDER96
		mkdir -p $HOME/sm64_save_backups/$SM64EX
		mkdir -p $HOME/sm64_save_backups/$SM64
		mkdir -p $HOME/sm64_save_backups/$SM64PLUS
		cp $HOME/.local/share/sm64ex/render96_save_file_*.sav $HOME/sm64_save_backups/$RENDER96
		cp $HOME/.local/share/sm64ex/sm64_save_file.bin $HOME/sm64_save_backups/$SM64EX
		cp $HOME/.config/SM64Plus/savedata.bin $HOME/sm64_save_backups/$SM64PLUS
		cp $HOME/Applications/$SM64/build/$REGION${PC}/sm64_save_file.bin $HOME/sm64_save_backups/$SM64

		info "Save data backed up to $HOME/sm64_save_backups."

	elif [ "$Choice" == "INSTALL_SM64_RELOADED" ]; then
		(
		echo -e "Downloading...\n"
		curl -L https://evilgames.eu/texture-packs/files/sm64-reloaded-v2.4.0-pc-1080p.zip -o sm64-reloaded.zip
		
		echo -e "Extracting...\n"
		7za x sm64-reloaded.zip
		cp -r gfx/ $SM64EX/build/$REGION${PC}/res/
		cp -r gfx/ $SM64EX_ALO/build/$REGION${PC}/res/
		cp -r gfx/ $SM64PLUS/build/$REGION${PC}/

		rm sm64-reloaded.zip
		rm -rf gfx/
		) | progress_bar "Downloading and installing SM64 Reloaded textures, please wait..."

		info "Hi-res textures installed to $SM64EX, $SM64EX_ALO, and $SM64PLUS."
	
	elif [ "$Choice" == "INSTALL_TEXTURE_PACKS" ]; then
		(
		echo -e "Downloading model pack...\n"
		curl -L $(curl -s https://api.github.com/repos/Render96/ModelPack/releases/latest | grep "browser_download_url" | cut -d '"' -f 4) -o Render96_DynOs.7z
		echo -e "Extracting model pack...\n"
		7za x Render96_DynOs.7z -o/$PWD/$RENDER96/build/$REGION${PC}/dynos/packs
		rm Render96_DynOs.7z
		) | progress_bar "Downloading model pack..."

		(
		echo -e "Downloading texture pack...\n"
		git clone https://github.com/pokeheadroom/RENDER96-HD-TEXTURE-PACK.git -b master
		echo -e "Copying...\n"
		mkdir -p $RENDER96/build/$REGION${PC}/res
		cp RENDER96-HD-TEXTURE-PACK/gfx/ -r $RENDER96/build/$REGION${PC}/res/
		rm -rf RENDER96-HD-TEXTURE-PACK
		echo -e "Done.\n"
		) | progress_bar "Downloading texture pack...this will probably take a while."

		info "Install complete. Note that you will need to enable the HD models via the in-game options menu in order to use them."
	fi
	done
fi
done
