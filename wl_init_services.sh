#!/bin/sh

# CLBJ - 2016- Shell script to check and kill weblogic processes
# Dependency: netstat, curl, pgrep
# https://github.com/clbj/weblogic-scripts
# Version 1.3.0
# $1 weblogic install path
# $2 domain name
# $3 Weblogic Node Manager port ex: 5556
# $4 init mode for Node Manager (stop|start|restart|none)
# $5 Weblogic Admin server port ex: 7001
# $6 init mode for Admin Server (stop|start|restart|none)

if ([ "$1" = "" ] || [ "$2" = "" ] || [ "$3" = "" ] || [ "$4" = "" ] || [ "$5" = "" ] || [ "$6" = "" ]); then
	echo "------------------------------------------------------------------------"
	echo "ERROR: Missing arguments"
	echo "Usage: wl_init_services.sh wl_install_path (ex: /bea/weblogicTest) "
	echo "			 domain_name (ex: domainTest) node_manager_port (ex: 5556) admin_server (ex: 7001)"
	echo "			 node_manager_mode (start|stop|restart|none) admin_server_mode (start|stop|restart|none)"
	echo "-----------------------------------------------------------------------"
	exit
fi

VERSION="1.3.0"
SLEEP_TIME=3
LONG_TIME=400
ADMIN_SERVER_STOP_TIMEOUT=60
NODE_MANAGER_STOP_TIMEOUT=60
WL_INSTALL_PATH=${1}
WL_DOMAIN_NAME=${2}
NODE_MANAGER_PORT=${3}
NODE_MANAGER_MODE=$(echo ${4} | tr '[:upper:]' '[:lower:]')
ADMIN_SERVER_PORT=${5}
ADMIN_SERVER_MODE=$(echo ${6} | tr '[:upper:]' '[:lower:]')
PID_ADMIN_SERVER=""
PID_NODE_MANAGER=""
PID_MANAGED_SERVER=""
PID_APACHE_DERBY=""
OVERALL_STOP_STATUS=true
OVERALL_START_STATUS=true

echo "---------------------------------------------------------------------"
echo "CLBJ's Weblogic Start/Stop script started!"
echo "Version: ${VERSION}"
echo "http://github.com/clbj"
echo "---------------------------------------------------------------------"

echo "Collecting hardware information..."
SYSTEM_TOTAL_CPU=$(grep -c ^processor /proc/cpuinfo)
SYSTEM_TOTAL_RAM=$(free | awk '/^Mem:/{print $2}')
echo "Number of CPU: ${SYSTEM_TOTAL_CPU}"
echo "Total ammount of RAM: $(( ${SYSTEM_TOTAL_RAM}/1024 )) MB"

checkTimeout() {
	if ([ $1 -gt ${LONG_TIME} ]); then
		echo "---------------------------------------------------------------------"
		echo "WARN: The execution is taking too much time to finish."
		echo "Please check if the parameters are correct or if you are not facing"
		echo "any hardware or network issues then run the script again."
		echo "---------------------------------------------------------------------"
		echo "WARN: The execution has been interrupted!"
		echo "---------------------------------------------------------------------"
		exit 1
	fi
}

checkMinTimeout() {
	# $1 hold time in seconds $2 comparable time
	if ([ $1 -gt $2 ]); then
		local time_to_sleep=$(( $1 - $2 ))
		echo "---------------------------------------------------------------------"
		echo "WARN: The execution finished too early."
		echo "Holding the execution for $1 seconds to ensure that the service"
		echo "operation."
		echo "---------------------------------------------------------------------"
		sleep ${time_to_sleep}
	fi
}

stopApacheDerbyProcess() {
  local time_spent=0
  PID_APACHE_DERBY=$(pgrep -f "${WL_INSTALL_PATH}.*org.apache.derby.drda.NetworkServerControl start")

  if ! ([ "${PID_APACHE_DERBY}" = "" ]); then
    echo "---------------------------------------------------------------------"
    echo "Weblogic's Apache Derby process running with PID ${PID_APACHE_DERBY}"
    echo "Stopping Weblogic's Apache Derby process for domain ${WL_DOMAIN_NAME}"
    echo "---------------------------------------------------------------------"
    kill -9 "${PID_APACHE_DERBY}"
    sleep ${SLEEP_TIME}
    PID_APACHE_DERBY=$(pgrep -f "${WL_INSTALL_PATH}.*org.apache.derby.drda.NetworkServerControl start")

    until ([ "${PID_APACHE_DERBY}" = "" ]); do
      echo "Still stopping Weblogic's Apache Derby process ..."
      sleep ${SLEEP_TIME}
      time_spent=$(( time_spent + ${SLEEP_TIME} ))
      echo "Time spent so far to stop process: ${time_spent} seconds"
      PID_APACHE_DERBY=$(pgrep -f "${WL_INSTALL_PATH}.*org.apache.derby.drda.NetworkServerControl start")
			checkTimeout $time_spent
    done

    if ([ "${PID_APACHE_DERBY}" = "" ]); then
      echo "Successfully stopped Weblogic's Apache Derby process"
    else
      kill -9 "${PID_APACHE_DERBY}"
      sleep ${SLEEP_TIME}
      if ! ([ "${PID_APACHE_DERBY}" = "" ]); then
        echo "Could not stop Weblogic's Apache Derby process running with PID ${PID_APACHE_DERBY} manual shutdown is needed!"
        OVERALL_STOP_STATUS=false
      fi
    fi
  else
    echo "Weblogic's Apache Derby process is NOT running"
  	echo "---------------------------------------------------------------------"
  fi
}

stopNodeManager() {
  local time_spent=0
	PID_NODE_MANAGER=$(pgrep -f "${WL_INSTALL_PATH}.*nodemanager.JavaHome")

  if ! ([ "${PID_NODE_MANAGER}" = "" ]); then
    echo "---------------------------------------------------------------------"
    echo "Weblogic Node Manager process running with PID ${PID_NODE_MANAGER}"
    echo "Stopping Weblogic's Node Manager process for domain ${WL_DOMAIN_NAME}"
    echo "---------------------------------------------------------------------"
    . /${WL_INSTALL_PATH}/user_projects/domains/${WL_DOMAIN_NAME}/bin/stopNodeManager.sh < /dev/null &> /dev/null &
    sleep ${SLEEP_TIME}
    PID_NODE_MANAGER=$(pgrep -f "${WL_INSTALL_PATH}.*nodemanager.JavaHome")

    until ([ "${PID_NODE_MANAGER}" = "" ]); do
      echo "Still stopping Weblogic Node Manager process ..."
      sleep ${SLEEP_TIME}
      time_spent=$(( time_spent + ${SLEEP_TIME} ))
      if ([ $time_spent -gt ${NODE_MANAGER_STOP_TIMEOUT} ]); then
        kill -9 "${PID_NODE_MANAGER}"
      fi
      echo "Time spent so far to stop process: ${time_spent} seconds"
			checkTimeout $time_spent
      PID_NODE_MANAGER=$(pgrep -f "${WL_INSTALL_PATH}.*nodemanager.JavaHome")
    done

    if ([ "${PID_NODE_MANAGER}" = "" ]); then
      echo "Successfully stopped Weblogic's Node Manager process"
    else
      kill -9 "${PID_NODE_MANAGER}"
      sleep ${SLEEP_TIME}
      if ! ([ "${PID_NODE_MANAGER}" = "" ]); then
        echo "Could not stop Weblogic's Node Manager process running with PID ${PID_NODE_MANAGER} manual shutdown is needed!"
        OVERALL_STOP_STATUS=false
      fi
    fi
  else
    echo "Weblogic's Node Manager process is NOT running"
  	echo "---------------------------------------------------------------------"
  fi
}

startNodeManager() {
  echo "---------------------------------------------------------------------"
	echo "Checking state of Weblogic Node Manager process"
	echo "---------------------------------------------------------------------"

	local time_spent=0
  echo "---------------------------------------------------------------------"
  echo "Starting Weblogic Node Manager process in background ..."
  echo "---------------------------------------------------------------------"
  . /${WL_INSTALL_PATH}/user_projects/domains/${WL_DOMAIN_NAME}/bin/startNodeManager.sh < /dev/null &> /dev/null &
  sleep ${SLEEP_TIME}

	while ([ "${PID_NODE_MANAGER}" = "" ]); do
    echo "Still starting Weblogic Node Manager process in background..."
    sleep ${SLEEP_TIME}
    time_spent=$(( time_spent + ${SLEEP_TIME} ))
    echo "Time spent so far to start process: ${time_spent} seconds"
    PID_NODE_MANAGER=$(pgrep -f "${WL_INSTALL_PATH}.*nodemanager.JavaHome")
		checkTimeout $time_spent
  done

	local netstat_node_manager=$(netstat -ln | grep :"$NODE_MANAGER_PORT" | grep 'LISTEN')

	while ([ "${netstat_node_manager}" = "" ]); do
		echo "Wating for Weblogic Node Manager service to be avaliable ..."
		local netstat_node_manager_5556=$(netstat -ln | grep ':5556' | grep 'LISTEN' &)
		local netstat_node_manager_12556=$(netstat -ln | grep ':12556' | grep 'LISTEN' &)

		if ! ([ "${netstat_node_manager_5556}" = "" ]); then
			echo "INFO: Weblogic Node Manager seems to be running at the default port 5556"
			netstat_node_manager=netstat_node_manager_5556
		elif ! ([ "${netstat_node_manager_12556}" = "" ]); then
			echo "INFO: Weblogic Node Manager seems to be running at port 12556"
			netstat_node_manager=netstat_node_manager_12556
		else
			netstat_node_manager=$(netstat -ln | grep :"$NODE_MANAGER_PORT" | grep 'LISTEN' &)
		fi
		sleep ${SLEEP_TIME}
    time_spent=$(( time_spent + ${SLEEP_TIME} ))
		echo "Time spent so far to start process: ${time_spent} seconds"
		checkTimeout $time_spent
	done

	checkMinTimeout 30 $time_spent

  echo "---------------------------------------------------------------------"
  echo "Weblogic Node Manager process started successfully with PID ${PID_NODE_MANAGER}"
  echo "---------------------------------------------------------------------"
}

stopManagedServers() {
  local time_spent=0
  PID_MANAGED_SERVER=$(pgrep -f "${WL_INSTALL_PATH}.*management.server")

	echo "---------------------------------------------------------------------"
	echo "Checking state of Weblogic Managed Server process"
	echo "---------------------------------------------------------------------"

  for PID in $PID_MANAGED_SERVER; do
      echo "Weblogic's Node Managed Server running with PID ${PID}"
      echo "Stopping Weblogic's Managed Servers processes for domain"
      echo "${WL_DOMAIN_NAME}"
      echo "-----------------------------------------------------------------"
      kill -9 "${PID}"
      sleep ${SLEEP_TIME}
      time_spent=$(( time_spent + ${SLEEP_TIME} ))
      checkTimeout $time_spent
  done

  checkMinTimeout 30 $time_spent

  PID_MANAGED_SERVER=$(pgrep -f "${WL_INSTALL_PATH}.*management.server")

  if ([ "${PID_MANAGED_SERVER}" = "" ]); then
    echo "Successfully stopped Weblogic Managed Server process"
  else
    echo "Could not stop Weblogic Managed Server process running with PID ${PID_MANAGED_SERVER} manual shutdown is needed!"
    OVERALL_STOP_STATUS=false
  fi
}

stopAdminServer() {
  local time_spent=0
  echo "---------------------------------------------------------------------"
  echo "Checking state of Weblogic Admin Server process"
  echo "---------------------------------------------------------------------"
  PID_ADMIN_SERVER=$(pgrep -f "AdminServer.*${WL_INSTALL_PATH}")

	if ! ([ "${PID_ADMIN_SERVER}" = "" ]); then
    echo "---------------------------------------------------------------------"
    echo "Weblogic Admin Server process running with PID ${PID_ADMIN_SERVER}"
    echo "Stopping Weblogic's Admin Server process for domain ${WL_DOMAIN_NAME}"
    echo "---------------------------------------------------------------------"
    . /${WL_INSTALL_PATH}/user_projects/domains/${WL_DOMAIN_NAME}/bin/stopWebLogic.sh < /dev/null &> /dev/null &
    sleep 5
    PID_ADMIN_SERVER=$(pgrep -f "AdminServer.*${WL_INSTALL_PATH}")

    until ([ "${PID_ADMIN_SERVER}" = "" ]); do
      echo "Stopping Weblogic Admin Server process ..."
      sleep ${SLEEP_TIME}
      time_spent=$(( time_spent + ${SLEEP_TIME} ))
      if ([ $time_spent -gt ${ADMIN_SERVER_STOP_TIMEOUT} ]); then
        kill -9 "${PID_ADMIN_SERVER}"
      fi
      echo "Time spent so far to stop process: ${time_spent} seconds"
			checkTimeout $time_spent
      PID_ADMIN_SERVER=$(pgrep -f "AdminServer.*${WL_INSTALL_PATH}")
    done

    if ([ "${PID_ADMIN_SERVER}" = "" ]); then
      echo "Successfully stopped Weblogic Admin Server process"
    else
      kill -9 "${PID_ADMIN_SERVER}"
      sleep ${SLEEP_TIME}
      if ! ([ "${PID_ADMIN_SERVER}" = "" ]); then
        echo "Could not stop Weblogic Admin Server process running with PID ${PID_ADMIN_SERVER} manual shutdown is needed!"
        OVERALL_STOP_STATUS=false
      fi
    fi
  else
    echo "Weblogic Admin Server process is NOT running"
  	echo "---------------------------------------------------------------------"
  fi
}

startAdminServer() {
	local time_spent=0
  echo "---------------------------------------------------------------------"
  echo "Starting Weblogic Admin Server process in background for domain"
  echo "${WL_DOMAIN_NAME}"
  echo "---------------------------------------------------------------------"
  . /${WL_INSTALL_PATH}/user_projects/domains/${WL_DOMAIN_NAME}/startWebLogic.sh < /dev/null &> /dev/null &
  sleep ${SLEEP_TIME}

	while ([ "${PID_ADMIN_SERVER}" = "" ]); do
	  echo "Still starting Weblogic Admin Server process in background ..."
	  sleep ${SLEEP_TIME}
	  time_spent=$(( time_spent + ${SLEEP_TIME} ))
	  echo "Time spent so far to start process: ${time_spent} seconds"
	  PID_ADMIN_SERVER=$(pgrep -f "weblogic.Name=AdminServer -Djava.security.policy=${WL_INSTALL_PATH}")
		checkTimeout $time_spent
	done

	local netstat_admin_server=$(netstat -ln | grep :"$ADMIN_SERVER_PORT" | grep 'LISTEN')

	while ([ "${netstat_admin_server}" = "" ]); do
		echo "Waiting for Weblogic Admin Server service to be avaliable ..."
		local netstat_admin_server_7001=$(netstat -ln | grep ':7001' | grep 'LISTEN')

		if ! ([ "${netstat_admin_server_7001}" = "" ]); then
			echo "INFO: Weblogic Admin Server seems to be running at the default port 7001"
			netstat_admin_server=netstat_admin_server_7001
		else
			netstat_admin_server=$(netstat -ln | grep :"$ADMIN_SERVER_PORT" | grep 'LISTEN')
		fi
		sleep ${SLEEP_TIME}
		time_spent=$(( time_spent + ${SLEEP_TIME} ))
		echo "Time spent so far to start process: ${time_spent} seconds"
		checkTimeout $time_spent
	done

	local wl_http_status_code=$(curl -I http://127.0.0.1:"$ADMIN_SERVER_PORT"/console/login/LoginForm.jsp 2>/dev/null | head -n 1 | cut -d' ' -f2)

	while ! ([ "${wl_http_status_code}" = "200" ]); do
		echo "Waiting for Weblogic Admin Server console to be ready ..."
 		sleep ${SLEEP_TIME}
 		time_spent=$(( time_spent + ${SLEEP_TIME} ))
 		echo "Time spent so far to start process: ${time_spent} seconds"
 		wl_http_status_code=$(curl -I http://127.0.0.1:"$ADMIN_SERVER_PORT"/console/login/LoginForm.jsp 2>/dev/null | head -n 1 | cut -d' ' -f2)
		checkTimeout $time_spent
 	done

	checkMinTimeout 60 $time_spent

	echo "---------------------------------------------------------------------"
  echo "Weblogic Admin Server process started successfully with PID ${PID_ADMIN_SERVER}"
  echo "---------------------------------------------------------------------"
}

run() {
  if ([ "${SYSTEM_TOTAL_CPU}" -lt 2 ] || [ "${SYSTEM_TOTAL_RAM}" -lt 16330176 ]); then
    LONG_TIME=600
    ADMIN_SERVER_STOP_TIMEOUT=120
    NODE_MANAGER_STOP_TIMEOUT=120
  fi

  echo "INFO: Setting script timeout to ${LONG_TIME} seconds."

	# if a full restart is requested
	if ([ "${NODE_MANAGER_MODE}" = "restart" ] && [ "${ADMIN_SERVER_MODE}" = "restart" ]); then
    stopNodeManager
    stopManagedServers
		stopAdminServer
    stopApacheDerbyProcess
    startAdminServer
		startNodeManager
	else
	  if ([ "${ADMIN_SERVER_MODE}" = "stop" ]); then
	    stopAdminServer
	  elif ([ "${ADMIN_SERVER_MODE}" = "start" ] || [ "${ADMIN_SERVER_MODE}" = "restart" ]); then
      stopAdminServer
	    startAdminServer
	  elif ([ "${ADMIN_SERVER_MODE}" = "none" ]); then
	    echo "---------------------------------------------------------------------"
	    echo "INFO: No action for Admin Server process"
	    echo "---------------------------------------------------------------------"
	  else
	    echo "---------------------------------------------------------------------"
	    echo "ERROR: Invalid init parameter for Admin Server"
	    echo "---------------------------------------------------------------------"
	    exit
	  fi
	fi

  if ([ "${NODE_MANAGER_MODE}" = "stop" ]); then
    stopNodeManager
    stopManagedServers
    stopApacheDerbyProcess
  elif ([ "${NODE_MANAGER_MODE}" = "start" ] || [ "${NODE_MANAGER_MODE}" = "restart" ]); then
    stopNodeManager
    stopManagedServers
    stopApacheDerbyProcess
    startNodeManager
  elif ([ "${NODE_MANAGER_MODE}" = "none" ]); then
    echo "---------------------------------------------------------------------"
    echo "INFO: No action for Node Manager process"
    echo "---------------------------------------------------------------------"
  else
    echo "---------------------------------------------------------------------"
    echo "ERROR: Invalid init parameter for Node Manager"
    echo "---------------------------------------------------------------------"
    exit
  fi

  if ! ([ ${OVERALL_STOP_STATUS} ]); then
    echo "---------------------------------------------------------------------"
    echo "ERROR: Could not executed some stopping tasks."
    echo "---------------------------------------------------------------------"
		exit 1
  fi

  if ! ([ ${OVERALL_START_STATUS} ]); then
    echo "---------------------------------------------------------------------"
    echo "ERROR: Could not executed some starting tasks."
    echo "---------------------------------------------------------------------"
		exit 1
  fi

  echo "-----------------------------------------------------------------------"
  echo "INFO: Finished executing script wl_init_services.sh ${1} ${2} ${3} ${4} ${5} ${6}"
  echo "-----------------------------------------------------------------------"
  exit 0
}

run
