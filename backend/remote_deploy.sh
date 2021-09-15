STAGING_ENVIRONMENT="staging_environment"
AWATTPRICE_V2_ENVIRONMENT="awattprice_v2_environment"

environment=$1
wheel_path=$2
restart_service=$3

if [[ $environment == $STAGING_ENVIRONMENT ]]; then
	service_name="staging_awattprice.service"
	awattprice_service_name="staging_awattprice"
elif [[ $environment == $AWATTPRICE_V2_ENVIRONMENT ]]; then
	service_name="awattprice_v2.service"
	awattprice_service_name="awattprice_v2"
else
	echo "Didn't recognize environment type $environment on remote side."
	exit 1
fi

VIRTUALENV_DIR="/home/awattprice_service/$awattprice_service_name/.virtualenvs/awattprice"
VIRTUALENV_PYTHON="$VIRTUALENV_DIR/bin/python -m"

echo "- Started remote deploying -"
eval "$VIRTUALENV_PYTHON pip install -q --upgrade pip"
eval "$VIRTUALENV_PYTHON pip install -q --force-reinstall $wheel_path" || { echo "Couldn't install wheel."; exit 1; }
rm $wheel_path
echo "Installed AWattPrice backend successfully."
if [[ $restart_service == 1 ]]; then
    echo "Restarting AWattPrice backend service."
    systemctl --user restart $service_name
fi
echo "Finished new AWattPrice backend deployment."
