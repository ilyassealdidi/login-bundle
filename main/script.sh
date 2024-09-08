BASE_PATH="$HOME/goinfre/login-bundle/"
APPS_PATH=$BASE_PATH"Apps/"
SCRIPTS_PATH=$BASE_PATH"Scripts/"

if [ ! -d "$BASH_PATH" ]; then
	git clone https://github.com/ilyassealdidi/login-bundle $BASE_PATH
	app=$(curl https://app.warp.dev/download\?package\=dmg | awk -F'"' '{print $2}')
	curl -o $APPS_PATH"Warp.dmg" $app
	volume=$(hdiutil attach $APPS_PATH"Warp.dmg" | grep /Volumes/Warp | awk '{print $1}')
	cp -R /Volumes/Warp/Warp.app $APPS_PATH
	hdiutil detach $volume
	rm -rf $APPS_PATH"Warp.dmg"
fi

# Run Scripts
bash ~/Other/Scripts/Cleaner_42.sh;
bash $BASE_PATH"/clean_script.sh";
bash $SCRIPTS_PATH"/bluetooth.sh"

# Open Apps
open $APPS_PATH/HazeOver.app;
open $APPS_PATH/Timey\ 3.app;
open $APPS_PATH/Be\ Focused\ Pro.app;

