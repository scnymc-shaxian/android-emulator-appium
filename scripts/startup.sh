#!/bin/bash

# Variables
RUN_FLAG=true
p_avd_name=
p_api_level=
p_avd_skin=
p_appium_port=
p_appium_log=
p_app_path=
# Variables default value
d_avd_name=AUT-Android
d_api_level=android-29
d_avd_skin=1920x1080
d_appium_port=4723
d_appium_log=/var/log/appium.log
d_app_path=na


usage()
{
	echo -e "Usage: startup.sh [--options] arg ..."
	echo -e "[-d|--avd]:            Name of the AVD to launch"
	echo -e "[-l|--level]:          Specified the Android SDK API Level to be created" 
	echo -e "[-s|--skin]:           The AVD skin"
	echo -e "[-p|--port]:           The Appium service port"
    echo -e "[-o|--log]:            The Appium log path"
	echo -e "[-i|--install]:        App path for pre-install"
	echo -e "[-v|--version]:        Version"
	echo -e "[-h|--help]:           Help"
}

fun_version()
{
	echo -e "DockerMobileAutoCLI Version: 1.0 (By scnymc@20200517)\n"
	exit 0
}

fun_required()
{
# $1 is the passed parameters value to be validated
# $2 is the parameters refs
    if [ ! -n "$1" ]; then
            echo ">>>>>> Parameters check ERROR: The Parameter options $2 is required"  
            RUN_FLAG=false
    else
            echo ">>> The Parameter options $2 is set to '$1'"  
    fi
}

fun_optional()
{
# $1 is the passed parameters to be validated
# $2 is the passed parameter's name
# $3 is the default value for this parameter if the passed parameter is null
# $4 is the parameter's arg for comments
    if [ ! -n "$1" ]; then
    	eval $2=$3
        echo ">>> The Parameter options $4 has been set to the default value '$3'"
    else
        echo ">>> The Parameter options $4 is set to $1"  
    fi
}

ARGS=`getopt -o hvd:l:s:a:p:o:i: -a --long help,version,avd:,level:,skin:,address:,port:,log:,install: -- "$@"`
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi
eval set -- "$ARGS"
while true;do
	case "$1" in
		-d|--avd)
			p_avd_name=$2
			shift 2
			;;
		-l|--level)
			p_api_level=$2
			shift 2
			;;
		-s|--skin)
			p_avd_skin=$2
			shift 2
			;;
		-p|--port)
			p_appium_port=$2
			shift 2
			;;
		-o|--log)
			p_appium_log=$2
			shift 2
			;;		
		-i|--install)
			p_app_path=$2
			shift 2
			;;	
		-v|--version)
			fun_version
			shift
			;;
		-h|--help)
			usage
			exit 0
			shift
			;;
		--)
			shift
			break
			;;
		*) 
			echo "Unknown attribute: {$1}"
			echo -e "\nFor Usage: [-h|--help]"
			exit 1
			;;
	esac
done

echo -e ">>> Setting Parameters..."
#fun_required "${p_avd_name}" "[ -d|--avd ]"

if [ "$RUN_FLAG" == "true" ]
then
    fun_optional "${p_avd_name}" "p_avd_name" "${d_avd_name}" "[ -d|--avd ]"
    fun_optional "${p_api_level}" "p_api_level" "${d_api_level}" "[ -l|--level ]"
    fun_optional "${p_avd_skin}" "p_avd_skin" "${d_avd_skin}" "[ -s|--skin ]"
    fun_optional "${p_appium_port}" "p_appium_port" "${d_appium_port}" "[ -p|--port ]"
    fun_optional "${p_appium_log}" "p_appium_log" "${d_appium_log}" "[ -o|--log ]"
	fun_optional "${p_app_path}" "p_app_path" "${d_app_path}" "[ -i|--install ]"

    # Startup Appium services
    CONTAINER_IP=$(ip a | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | grep 172.17.0)
    echo "Appium will be started on $CONTAINER_IP"
    xvfb-run --auto-servernum appium -a $CONTAINER_IP -p ${p_appium_port} --log ${p_appium_log} &

    # Create avd
    SYSTEM_IMAGE="system-images;${p_api_level};google_apis;x86_64"
    AVD_NAME=${p_avd_name}
    echo ">>> Create AVD [$SYSTEM_IMAGE]"
    echo "no" | avdmanager create avd -n $AVD_NAME -k "$SYSTEM_IMAGE"
    echo ">>> List AVD"
    avdmanager list avd

    # start avd
    echo ">>> Start AVD [$AVD_NAME]"
    emulator -avd $AVD_NAME -no-audio -no-boot-anim -accel on -gpu off -skin ${p_avd_skin}
    echo "Start with command [emulator -avd $AVD_NAME -no-audio -no-boot-anim -accel on -gpu off -skin ${p_avd_skin}]"

	if [ "${p_app_path}" == "na" ]
	then
		echo "There is no pre-install app"
	else
		if [ ! -f "$p_app_path" ]
		then
			echo "The specified pre-install app does not exit"
			exit 1
		else
			sleep 30
			adb install ${p_app_path}
			if [ "$?" == 0 ]
			then
				echo "Pre-install app from $p_app_path"
			else
				echo "Pre-install app from $p_app_path failed!"
				exit 1
			fi
		fi
	fi

    # Keep the session running in foreground
    tail -f /dev/null
else
	echo -e "\nFor Usage: [-h|--help]"
    usage
	exit 1
fi



