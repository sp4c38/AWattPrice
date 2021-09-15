NEWLINE=$'\n'

WORKING_DIR=$(pwd)

STAGING_ENVIRONMENT="staging_environment"
AWATTPRICE_V2_ENVIRONMENT="awattprice_v2_environment"
SERVER_HOST="aws"

read -p "Assuming that your current directory $WORKING_DIR is the base directory of the backend project with the pyproject.toml configuration file. Enter to continue. $NEWLINE"

read -p "Deploy to (s)taging or awattprice v2 (av2) environment? " environment_selection_string
if [[ "$environment_selection_string" == "s" ]]; then
	environment=$STAGING_ENVIRONMENT
	awattprice_service_name="staging_awattprice"
elif [[ $environment_selection_string == "av2" ]]; then
	environment=$AWATTPRICE_V2_ENVIRONMENT
	awattprice_service_name="awattprice_v2"
else
	echo "Your selection '$environment_selection_string' is not valid."
	exit 1
fi

echo "Using awattprice service name $awattprice_service_name.$NEWLINE"

read -p "Restart the backend service after installing? (y / n) " restart_service_string
if [[ "$restart_service_string" == "y" ]]; then
	restart_service=1
elif [[ $restart_service_string == "n" ]]; then
	restart_service=0
else
	echo "Your selection '$restart_service_string' is not valid."
	exit 1
fi

echo " $NEWLINE---- Building project ----"
echo "Checking if pyproject.toml is valid..."
poetry check  || { exit 1;  }
OLD_VERSION_NUMBER=$(poetry version -s)
read -p "Specify the new AWattPrice backend version (enter to keep $OLD_VERSION_NUMBER): " new_version_number
if [[ $new_version_number == "" ]]; then
	new_version_number=$OLD_VERSION_NUMBER
else
	poetry version  $new_version_number || { exit 1; }
fi
poetry build -f wheel || { exit 1; }
WHEEL_FILE_NAME="AWattPrice_Backend-$new_version_number-py3-none-any.whl"
WHEEL_PATH="$WORKING_DIR/dist/$WHEEL_FILE_NAME"
echo "Assuming that the wheel file name is $WHEEL_FILE_NAME and that it is at $WHEEL_PATH."

echo "$NEWLINE---- Deploying project ----"
echo "Sending wheel to server."
REMOTE_WHEEL_PATH="/home/awattprice_service/$awattprice_service_name/$WHEEL_FILE_NAME"
REMOTE_DEPLOY_SCRIPT_PATH="/usr/local/bin/deploy_awattprice.sh"
REMOTE="$awattprice_service_name@$SERVER_HOST"
scp $WHEEL_PATH "$REMOTE:$REMOTE_WHEEL_PATH"
ssh $REMOTE "/usr/bin/bash $REMOTE_DEPLOY_SCRIPT_PATH $environment $REMOTE_WHEEL_PATH $restart_service" || { exit 1; }

echo "${NEWLINE}Deployment successful."
