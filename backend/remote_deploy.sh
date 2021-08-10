STAGING_ENVIRONMENT="staging_environment"
PRODUCTION_ENVIRONMENT="production_environment"

environment=$1
username=$2
wheel_path=$3

VIRTUALENV_DIR="/home/$username/.virtualenvs/awattprice"
VIRTUALENV_PYTHON="$VIRTUALENV_DIR/bin/python -m"

if [[ $environment == $STAGING_ENVIRONMENT ]]; then
	service_name="staging_awattprice.service"
elif [[ $environment == $PRODUCTION_ENVIRONMENT ]]; then
	service_name="awattprice.service"
else
	echo "Didn't recognize environment type $environment on remote side."
	exit 1
fi
echo "- Started remote deploying -"
eval "$VIRTUALENV_PYTHON pip install -q --upgrade pip"
eval "$VIRTUALENV_PYTHON pip install -q --force-reinstall $wheel_path" || { echo "Couldn't install wheel."; exit 1; }
rm $wheel_path
echo "Installed AWattPrice backend successfully."
echo "Restarting AWattPrice backend service."
systemctl --user restart $service_name
echo "New AWattPrice backend is now up and running."
