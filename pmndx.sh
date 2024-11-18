# ************************************************************
# MIT License
#
# Copyright 2024 T.Sang Tran <nerdox.tranit@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
# ************************************************************
# ************************************************************
# Configurations
# ************************************************************
pmndx_tag="pmndx"
pmndx_log_dir="."
if [ -z "${pmndx_log_name}" ]; then
    pmndx_log_name="${pmndx_tag}.log"
fi
pmndx_log_file="${pmndx_log_dir}/${pmndx_log_name}"
pmndx_remove_log=true




# ************************************************************
# Common
# ************************************************************
if [ ! -d ${pmndx_log_dir} ]; then
    echo "[${pmndx_tag}] Create log directory [${pmndx_log_dir}]"
    mkdir -pv ${pmndx_log_dir}
fi


if ${pmndx_remove_log}; then
    if [ -f ${pmndx_log_file} ]; then
        echo "[${pmndx_tag}] Clean log [${pmndx_log_file}]"
        rm -v ${pmndx_log_file}
    fi
fi


pmndx_log() {
    echo "[${pmndx_tag}] ${1}"
    echo "[${pmndx_tag}] ${1}" >> ${pmndx_log_file}
}


pmndx_header() {
    pmndx_log "=============================="
    pmndx_log "= ${1}"
    pmndx_log "=============================="
}


pmndx_create_dir() {
    if [ -z "${1}" ]; then
        pmndx_log "pmndx_create_dir: Missing directory name"
        exit -1
    fi

    if [ ! -d "${1}" ]; then
        pmndx_log "Create the directory [${1}]"
        mkdir -pv "${1}"
    fi
}




# ************************************************************
# Podman
# ************************************************************
pmndx_verify_running() {
    ok=true
    param_name=""


    # ====================
    # Arguments
    # ====================
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --name) param_name="$2"; shift ;;
            *) pmndx_log "pmndx_verify_running: Unknown parameter: $1"; exit 1 ;;
        esac
        shift
    done


    if [ -z "${param_name}" ]; then
        pmndx_log "pmndx_verify_running: Missing name of the container to process"
        ok=false
    fi


    if ! ${ok}; then
        pmndx_log "Example: pmndx_verify_running: --name my_container"
        exit -1
    fi


    # ====================
    # Process
    # ====================
    started=$(podman inspect -f '{{.State.Running}}' ${param_name})
    if [ "${started}" = "true" ]; then
        pmndx_log " * Container '${param_name}' is running ^__^ Yeah!"
    else
        pmndx_log " * Container '${param_name}' not running O__O Nooo!"
    fi
}


pmndx_create_container() {
    ok=true
    param_buildfile=""
    param_cmd=""
    param_detach=false
    param_env=""
    param_envfile=""
    param_hostname=""
    param_image=""
    param_interactive=false
    param_name=""
    param_pod=""
    param_port=""
    param_tty=false
    param_volume=""


    # ====================
    # Arguments
    # ====================
    while [[ "$#" -gt 0 ]]; do
        # Debug
        #echo "PARAMS: ${1} :: ${2}"
        case $1 in
            --buildfile) param_buildfile="$2"; shift ;;
            --cmd) param_cmd="$2"; shift ;;
            --detach) param_detach=true;;
            --env) param_env="${2}"; shift ;;
            --envfile) param_envfile="$2"; shift ;;
            --hostname) param_hostname="$2"; shift ;;
            --image) param_image="$2"; shift ;;
            --interactive) param_interactive=true; ;;
            --name) param_name="$2"; shift ;;
            --pod) param_pod="$2"; shift ;;
            --port) param_port="$2"; shift ;;
            --tty) param_tty=true; ;;
            --volume) param_volume="$2"; shift ;;
            *) pmndx_log "pmndx_create_container: Unknown parameter: $1"; exit 1 ;;
        esac
        shift
    done


    if [ -z "${param_name}" ]; then
        pmndx_log "pmndx_create_container: Missing name of the container"
        ok=false
    fi


    if [ -z "${param_image}" ]; then
        pmndx_log "pmndx_create_container: Missing name of the image to use"
        ok=false
    fi


    if ! ${ok}; then
        pmndx_log "Example: pmndx_create_container --env \"MY_ENV=my_env YOUR_ENV=your_env\" --envfile \"/envfile_a /envfile_b\" --hostname my_hostname --name my_container --volume \"my_dir:/var/lib/my_dir my_file:/var/lib/my_file\" --cmd \"ls -al\" --image my_image"
        exit -1
    fi



    # ====================
    # Process
    # ====================
    # Store in an array.
    volume_array=(${param_volume})
    env_array=(${param_env})
    envfile_array=(${param_envfile})
    port_array=(${param_port})


    pmndx_log "== Container [${param_name}] =="


    # Build if the image not exists.
    if [ -n "${param_buildfile}" ]; then
        if ! podman image exists ${param_image}; then
            pmndx_log " * Image '${param_image}' does not exists, start building from [${param_buildfile}]"

            podman build -f ${param_buildfile} -t ${param_image} .
        fi
    fi



    if ! podman container exists ${param_name}; then
        if ! podman image exists ${param_image}; then
            pmndx_log " * No image '${param_image} exists, skip creating the container"
            return
        fi


        pmndx_log " * Create container from image '${param_image}'"


        volume_args=""
        for vvol in "${volume_array[@]}"; do
            pmndx_log " * Volume: ${vvol}"
            volume_args+="--volume ${vvol} "
        done


        env_args=""
        for venv in "${env_array[@]}"; do
            pmndx_log " * ENV: ${venv}"
            env_args+="--env ${venv} "
        done


        envfile_args=""
        for efile in "${envfile_array[@]}"; do
            if [ -f "${efile}" ]; then
                pmndx_log " * EnvFile: ${efile}"
                envfile_args+="--env-file ${efile} "

            else
                pmndx_log " * EnvFile: ${efile} (SKIP DUE TO NOT EXISTS)"
            fi
        done


        pod_args=""
        if [ -n "${param_pod}" ]; then
            pmndx_log " * Pod: ${param_pod}"
            pod_args="--pod ${param_pod}"
        fi


        port_args=""
        for param_port in "${port_array[@]}"; do
            pmndx_log " * Port: ${param_port}"
            port_args+="-p ${param_port} "
        done


        hostname_args=""
        if [ -n "${param_hostname}" ]; then
            pmndx_log " * Hostname: ${param_hostname}"
            hostname_args="--hostname ${param_hostname}"
        fi



        # Default mode.
        mode="container create"


        # Use run because it supparam_port for running a command.
        if [ -n "${param_cmd}" ]; then
            pmndx_log " * CMD: ${param_cmd}"
            mode="run"
        fi

        if ${param_detach}; then
            mode="run"
        fi


        if [ "${mode}" = "run" ]; then
            pmndx_log " * Switch to run mode"
            pmndx_log " * MODE: run"
        fi


        detach_args=""
        if ${param_detach}; then
            pmndx_log " * Feature: Detach"
            detach_args="-d"
        fi

        interactive_args=""
        if ${param_interactive}; then
            pmndx_log " * Feature: Interactive"
            interactive_args="-i"
        fi

        tty_args=""
        if ${param_tty}; then
            pmndx_log " * Feature: TTY"
            tty_args="-t"
        fi

        podman ${mode} ${detach_args} ${interactive_args} ${tty_args} ${port_args} ${env_args} ${envfile_args} --name "${param_name}" ${hostname_args} ${volume_args} ${pod_args} ${param_image} ${param_cmd}

        # Verify only when using run instead of create.
        if [ "${mode}" = "run" ]; then
            pmndx_verify_running --name ${param_name}
        fi

    else
        pmndx_log " * Container exists, skip creating the container"
    fi
}


pmndx_create_network() {
    ok=true
    param_name=""
    param_driver=""


    # ====================
    # Arguments
    # ====================
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --name) param_name="$2"; shift ;;
            --driver) param_driver="$2"; shift ;;
            *) pmndx_log "pmndx_create_network: Unknown parameter: $1"; exit 1 ;;
        esac
        shift
    done


    if [ -z "${param_name}" ]; then
        pmndx_log "pmndx_create_network: Missing name of the network"
        ok=false
    fi


    if ! ${ok}; then
        pmndx_log "Example: pmndx_create_network --name my_network  --driver bridge"
        exit -1
    fi



    # ====================
    # Process
    # ====================
    pmndx_log "== Network [${param_name}] =="


    if podman network exists ${param_name}; then
        pmndx_log " * Network exists, skip creating the network"

    else
        pmndx_log " * Create network '${param_name}'"

        driver_args=""
        if [ -n "${param_driver}" ]; then
            pmndx_log " * Driver: ${param_driver}"
            driver_args="--driver ${param_driver}"
        fi


        podman network create "${param_name}" ${driver_args}


        # Podman 3.4.4 on Ubuntu 22.04.
        cni="${HOME}/.config/cni/net.d/${param_name}.conflist"
        if grep -q 'cniVersion": "1.0.0",' ${cni}; then
            pmndx_log " * Updating to compatible plugin version (1.0.0 => 0.4.0)"
            sed -i 's/cniVersion": "1.0.0",/cniVersion": "0.4.0",/g' ${cni}
        fi
    fi
}




pmndx_create_pod() {
    ok=true
    param_name=""
    param_port=""
    param_network=""


    # ====================
    # Arguments
    # ====================
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --name) param_name="$2"; shift ;;
            --port) param_port="$2"; shift ;;
            --network) param_network="$2"; shift ;;
            *) pmndx_log "pmndx_create_param_pod: Unknown parameter: $1"; exit 1 ;;
        esac
        shift
    done


    if [ -z "${param_name}" ]; then
        pmndx_log "pmndx_create_param_pod: Missing name of the param_pod"
        ok=false
    fi


    if ! ${ok}; then
        pmndx_log "Example: pmndx_create_param_pod --name my_param_pod --port \"8080:80 8443:443\" --network my_network"
        exit -1
    fi


    # ====================
    # Process
    # ====================
    port_array=(${param_port})

    pmndx_log "Pod [${param_name}]"


    if podman pod exists ${param_name}; then
        pmndx_log " * Pod exists, skip creating the pod"

    else
        pmndx_log " * Create pod '${param_name}'"


        port_args=""
        for vport in "${port_array[@]}"; do
            pmndx_log " * Port: ${vport}"
            port_args+="-p ${vport} "
        done

        network_args=""
        if [ -n "${param_network}" ]; then
            pmndx_log " * Network: ${param_network}"
            network_args="--network ${param_network}"
        fi


        podman pod create ${port_args} ${network_args} -n "${param_name}"
    fi
}



pmndx_create_volume() {
    ok=true
    param_name=""


    # ====================
    # Arguments
    # ====================
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --name) param_name="$2"; shift ;;
            *) pmndx_log "pmndx_create_volume: Unknown parameter: $1"; exit 1 ;;
        esac
        shift
    done


    if [ -z "${param_name}" ]; then
        pmndx_log "pmndx_create_volume: Missing name of the param_volume"
        ok=false
    fi


    if ! ${ok}; then
        pmndx_log "Example: pmndx_create_volume --name my_param_volume"
        exit -1
    fi


    # ====================
    # Process
    # ====================
    pmndx_log "== Volume [${param_name}] =="

    if podman volume exists ${param_name}; then
        pmndx_log " * Volume exists, skip creating the param_volume"

    else
        pmndx_log " * Create param_volume '${param_name}'"
        podman volume create ${param_name}
    fi
}


pmndx_exist_container() {
    ok=true
    param_name=""

    # ====================
    # Arguments
    # ====================
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --name) param_name="$2"; shift ;;
            *) pmndx_log "pmndx_exist_container: Unknown parameter: $1"; exit 1 ;;
        esac
        shift
    done


    if [ -z "${param_name}" ]; then
        pmndx_log "pmndx_exist_container: Missing name of the container to check"
        ok=false
    fi

    if ! ${ok}; then
        pmndx_log "Example: pmndx_exist_container --name my_container"
        exit -1
    fi


    # ====================
    # Process
    # ====================
    #pmndx_log "== Exists [${param_name}] =="
    if ! podman container exists ${param_name}; then
        #pmndx_log " * Container not exists"
        return 1
    else
        #pmndx_log " * Container exists"
        return 0
    fi
}




pmndx_export_image() {
    ok=true
    param_image=""
    param_output=""

    # ====================
    # Arguments
    # ====================
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --image) param_image="$2"; shift ;;
            --output) param_output="$2"; shift ;;
            *) pmndx_log "pmndx_export_image: Unknown parameter: $1"; exit 1 ;;
        esac
        shift
    done


    if [ -z "${param_image}" ]; then
        pmndx_log "pmndx_export_image: Missing name of the image to export"
        ok=false
    fi

    if [ -z "${param_output}" ]; then
        pmndx_log "pmndx_export_image: Missing output name"
        ok=false
    fi

    if ! ${ok}; then
        pmndx_log "Example: pmndx_export_image --image my_image:latest --output Build/Release"
        exit -1
    fi


    # ====================
    # Process
    # ====================
    format="docker-archive"
    pmndx_log "== Export [${param_image}] =="
    if ! podman image exists ${param_image}; then
        pmndx_log " * Image not exists, skip export the image"
    else
        pmndx_log " * Format: ${format}"
        pmndx_log " * Export: ${output}"
        podman save --format ${format} -o ${output} ${param_image}
    fi
}




pmndx_pull_image() {
    ok=true
    param_name=""

    # ====================
    # Arguments
    # ====================
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --name) param_name="$2"; shift ;;
            *) pmndx_log "pmndx_pull_image: Unknown parameter: $1"; exit 1 ;;
        esac
        shift
    done


    if [ -z "${param_name}" ]; then
        pmndx_log "pmndx_pull_image: Missing name of the image to pull"
        ok=false
    fi

    if ! ${ok}; then
        pmndx_log "Example: pmndx_pull_image --name my_image"
        exit -1
    fi


    # ====================
    # Process
    # ====================
    pmndx_log "== Pull [${param_name}] =="


    if ! podman image exists ${param_name}; then
        pmndx_log " * Image not exists, start pulling the image"
        podman pull ${param_name}
    else
        pmndx_log " * Image exists, no need to be pulled"
    fi
}




pmndx_run_once() {
    ok=true
    param_cmd=""
    param_detach=false
    param_env=""
    param_envfile=""
    param_image=""
    param_interactive=false
    param_pod=""
    param_tty=false


    # ====================
    # Arguments
    # ====================
    while [[ "$#" -gt 0 ]]; do
        #echo "PARAMS: ${1} :: ${2}"
        case $1 in
            --cmd) param_cmd="$2"; shift ;;
            --detach) param_detach=true;;
            --env) param_env="${2}"; shift ;;
            --envfile) param_envfile="$2"; shift ;;
            --image) param_image="$2"; shift ;;
            --interactive) param_interactive=true;;
            --pod) param_pod="$2"; shift ;;
            --tty) param_tty=true;;
            *) pmndx_log "pmndx_run_once: Unknown parameter: $1"; exit 1 ;;
        esac
        shift
    done


    if [ -z "${param_image}" ]; then
        pmndx_log "pmndx_run_once: Missing name of the image to use"
        ok=false
    fi

    if [ -z "${param_cmd}" ]; then
        pmndx_log "pmndx_run_once: Missing command to execute"
        ok=false
    fi


    if ! ${ok}; then
        pmndx_log "Example: pmndx_run_once: --detach --interactive --tty --env \"MY_ENV=my_env YOUR_ENV=your_env\" --envfile \"/envfile_a /envfile_b\" --cmd \"ls -al\" --image my_image --pod my_pod"
        exit -1
    fi



    # ====================
    # Process
    # ====================
    env_array=(${param_env})
    envfile_array=(${param_envfile})


    pmndx_log "== Run [${param_image}] =="


    if ! podman image exists ${param_image}; then
        pmndx_log " * No image '${param_image} exists, skip running the image"
        return
    fi


    env_args=""
    for venv in "${env_array[@]}"; do
        pmndx_log " * ENV: ${venv}"
        env_args+="--env ${venv} "
    done


    envfile_args=""
    for efile in "${envfile_array[@]}"; do
        if [ -f "${efile}" ]; then
            pmndx_log " * EnvFile: ${efile}"
            envfile_args+="--env-file ${efile} "

        else
            pmndx_log " * EnvFile: ${efile} (SKIP DUE TO NOT EXISTS)"
        fi
    done


    pod_args=""
    if [ -n "${param_pod}" ]; then
        pmndx_log " * Pod: ${param_pod}"
        pod_args="--pod ${param_pod}"
    fi

    detach_args=""
    if ${param_detach}; then
        pmndx_log " * Feature: Detach"
        detach_args="-d"
    fi

    interactive_args=""
    if ${param_interactive}; then
        pmndx_log " * Feature: Interactive"
        interactive_args="-i"
    fi

    tty_args=""
    if ${param_tty}; then
        pmndx_log " * Feature: TTY"
        tty_args="-t"
    fi

    podman run ${detach_args} ${interactive_args} ${tty_args} --rm ${env_args} ${envfile_args} ${pod_args} ${param_image} ${param_cmd}
}




pmndx_start_container() {
    ok=true
    param_name=""

    # ====================
    # Arguments
    # ====================
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --name) param_name="$2"; shift ;;
            *) pmndx_log "pmndx_start_container: Unknown parameter: $1"; exit 1 ;;
        esac
        shift
    done


    if [ -z "${param_name}" ]; then
        pmndx_log "pmndx_start_container: Missing name of the container"
        ok=false
    fi

    if ! ${ok}; then
        pmndx_log "Example: pmndx_start_container --name my_container"
        exit -1
    fi


    # ====================
    # Process
    # ====================
    pmndx_log "== Start [${param_name}] =="
    if ! podman container exists ${param_name}; then
        pmndx_log " * Container does not exists, cannot be started"
    else
        started=$(podman inspect -f '{{.State.Running}}' ${param_name})
        if [ "${started}" = "false" ]; then
            pmndx_log " * Container not running, starting up"
            podman container start "${param_name}"


            pmndx_verify_running ${param_name}
        else
            pmndx_log " * Container is already running"
        fi
    fi
}

