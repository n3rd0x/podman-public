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
pmndx_log_file="${pmndx_tag}.log"
pmndx_remove_log=true




# ************************************************************
# Common
# ************************************************************
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
    name=""


    # ====================
    # Arguments
    # ====================
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --name) name="$2"; shift ;;
            *) pmndx_log "pmndx_verify_running Unknown parameter: $1"; exit 1 ;;
        esac
        shift
    done


    if [ -z "${name}" ]; then
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
    started=$(podman inspect -f '{{.State.Running}}' ${name})
    if [ "${started}" = "true" ]; then
        pmndx_log " * Container '${name}' is running ^__^ Yeah!"
    else
        pmndx_log " * Container '${name}' not running O__O Nooo!"
    fi
}


pmndx_create_container() {
    ok=true
    buildfile=""
    cmd=""
    detach=false
    env=""
    envfile=""
    hostname=""
    image=""
    interactive=false
    name=""
    pod=""
    port=""
    tty=false
    volume=""


    # ====================
    # Arguments
    # ====================
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --buildfile) file="$2"; shift ;;
            --cmd) cmd="$2"; shift ;;
            --detach) detach=true; ;;
            --env) env="${2}"; shift ;;
            --envfile) envfile="$2"; shift ;;
            --hostname) hostname="$2"; shift ;;
            --image) image="$2"; shift ;;
            --interactive) interactive=true; ;;
            --name) name="$2"; shift ;;
            --pod) pod="$2"; shift ;;
            --port) port="$2"; shift ;;
            --tty) tty=true; ;;
            --volume) volume="$2"; shift ;;
            *) pmndx_log "pmndx_create_container: Unknown parameter: $1"; exit 1 ;;
        esac
        shift
    done


    if [ -z "${name}" ]; then
        pmndx_log "pmndx_create_container: Missing name of the container"
        ok=false
    fi


    if [ -z "${image}" ]; then
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
    volume_array=(${volume})
    env_array=(${env})
    envfile_array=(${envfile})
    port_array=(${port})


    pmndx_log "== Container [${name}] =="


    # Build if the image not exists.
    if [ -n "${buildfile}" ]; then
        if ! podman image exists ${image}; then
            pmndx_log " * Image '${image}' does not exists, start building from [${buildfile}]"

            podman build -f ${buildfile} -t ${image} .
        fi
    fi



    if ! podman container exists ${name}; then
        if ! podman image exists ${image}; then
            pmndx_log " * No image '${image} exists, skip creating the container"
            return
        fi


        pmndx_log " * Create container from image '${image}'"


        volume_args=""
        for vol in "${volume_array[@]}"; do
            pmndx_log " * Volume: ${vol}"
            volume_args+="--volume ${vol} "
        done


        env_args=""
        for eval in "${env_array[@]}"; do
            pmndx_log " * ENV: ${eval}"
            env_args+="--env ${eval} "
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
        if [ -n "${pod}" ]; then
            pmndx_log " * Pod: ${pod}"
            pod_args="--pod ${pod}"
        fi


        port_args=""
        for port in "${port_array[@]}"; do
            pmndx_log " * Port: ${port}"
            port_args+="-p ${port} "
        done


        hostname_args=""
        if [ -n "${hostname}" ]; then
            pmndx_log " * Hostname: ${hostname}"
            hostname_args="--hostname ${hostname}"
        fi



        # Default mode.
        mode="container create"


        # Use run because it support for running a command.
        if [ -n "${cmd}" ]; then
            pmndx_log " * CMD: ${cmd}"
            pmndx_log " * Switch to run mode"
            mode="run"
        fi


        detach_args=""
        if ${detach}; then
            pmndx_log " * Detach"
            detach_args="-d"
        fi


        interactive_args=""
        if ${interactive}; then
            pmndx_log " * Interactive"
            interactive_args="-i"
        fi

        tty_args=""
        if ${tty}; then
            pmndx_log " * Support TTY"
            tty_args="-t"
        fi


        podman ${mode} ${detach_args} ${interactive_args} ${tty_args} ${port_args} ${env_args} ${envfile_args} --name "${name}" ${hostname_args} ${volume_args} ${pod_args} ${image} ${cmd}

        # Verify only when using run instead of create.
        if [ "${mode}" = "run" ]; then
            pmndx_verify_running --name ${name}
        fi

    else
        pmndx_log " * Container exists, skip creating the container"
    fi
}


pmndx_create_network() {
    ok=true
    name=""
    driver=""


    # ====================
    # Arguments
    # ====================
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --name) name="$2"; shift ;;
            --driver) driver="$2"; shift ;;
            *) pmndx_log "pmndx_create_network: Unknown parameter: $1"; exit 1 ;;
        esac
        shift
    done


    if [ -z "${name}" ]; then
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
    pmndx_log "== Network [${name}] =="


    if podman network exists ${name}; then
        pmndx_log " * Network exists, skip creating the network"

    else
        pmndx_log " * Create network '${name}'"

        driver_arg=""
        if [ -n "${driver}" ]; then
            pmndx_log " * Driver: ${driver}"
            driver_arg="--driver ${driver}"
        fi


        podman network create "${name}" ${driver_arg}


        # Podman 3.4.4 on Ubuntu 22.04.
        cni="${HOME}/.config/cni/net.d/${name}.conflist"
        if grep -q 'cniVersion": "1.0.0",' ${cni}; then
            pmndx_log " * Updating to compatible plugin version (1.0.0 => 0.4.0)"
            sed -i 's/cniVersion": "1.0.0",/cniVersion": "0.4.0",/g' ${cni}
        fi
    fi
}




pmndx_create_pod() {
    ok=true
    name=""
    port=""
    network=""


    # ====================
    # Arguments
    # ====================
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --name) name="$2"; shift ;;
            --port) port="$2"; shift ;;
            --network) network="$2"; shift ;;
            *) pmndx_log "pmndx_create_pod: Unknown parameter: $1"; exit 1 ;;
        esac
        shift
    done


    if [ -z "${name}" ]; then
        pmndx_log "pmndx_create_pod: Missing name of the pod"
        ok=false
    fi


    if ! ${ok}; then
        pmndx_log "Example: pmndx_create_pod --name my_pod --port \"8080:80 8443:443\" --network my_network"
        exit -1
    fi


    # ====================
    # Process
    # ====================
    port_array=(${port})

    pmndx_log "Pod [${name}]"


    if podman pod exists ${name}; then
        pmndx_log " * Pod exists, skip creating the pod"

    else
        pmndx_log " * Create pod '${name}'"


        port_args=""
        for port in "${port_array[@]}"; do
            pmndx_log " * Port: ${port}"
            port_args+="-p ${port} "
        done

        network_args=""
        if [ -n "${network}" ]; then
            pmndx_log " * Network: ${network}"
            network_args="--network ${network}"
        fi


        podman pod create ${port_args} ${network_args} -n "${name}"
    fi
}



pmndx_create_volume() {
    ok=true
    name=""


    # ====================
    # Arguments
    # ====================
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --name) name="$2"; shift ;;
            *) pmndx_log "pmndx_create_volume: Unknown parameter: $1"; exit 1 ;;
        esac
        shift
    done


    if [ -z "${name}" ]; then
        pmndx_log "pmndx_create_volume: Missing name of the volume"
        ok=false
    fi


    if ! ${ok}; then
        pmndx_log "Example: pmndx_create_volume --name my_volume"
        exit -1
    fi


    # ====================
    # Process
    # ====================
    pmndx_log "== Volume [${1}] =="

    if podman volume exists ${1}; then
        pmndx_log " * Volume exists, skip creating the volume"

    else
        pmndx_log " * Create volume '${1}'"
        podman volume create ${1}
    fi
}


pmndx_export_image() {
    ok=true
    image=""
    output=""

    # ====================
    # Arguments
    # ====================
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --image) image="$2"; shift ;;
            --output) output="$2"; shift ;;
            *) pmndx_log "pmndx_export_image: Unknown parameter: $1"; exit 1 ;;
        esac
        shift
    done


    if [ -z "${image}" ]; then
        pmndx_log "pmndx_export_image: Missing name of the image to export"
        ok=false
    fi

    if [ -z "${output}" ]; then
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
    pmndx_log "== Export [${image}] =="
    if ! podman image exists ${image}; then
        pmndx_log " * Image not exists, skip exporting the image"
    else
        pmndx_log " * Format: ${format}"
        pmndx_log " * Export: ${output}"
        podman save --format ${format} -o ${output} ${image}
    fi
}


pmndx_start_container() {
    ok=true
    name=""

    # ====================
    # Arguments
    # ====================
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --name) name="$2"; shift ;;
            *) pmndx_log "pmndx_start_container: Unknown parameter: $1"; exit 1 ;;
        esac
        shift
    done


    if [ -z "${name}" ]; then
        pmndx_log "pmndx_start_container: Missing name"
        ok=false
    fi

    if ! ${ok}; then
        pmndx_log "Example: pmndx_start_container --name my_container"
        exit -1
    fi


    # ====================
    # Process
    # ====================
    pmndx_log "== Start [${name}] =="
    if ! podman container exists ${name}; then
        pmndx_log " * Container does not exists, cannot be started"
    else
        started=$(podman inspect -f '{{.State.Running}}' ${name})
        if [ "${started}" = "false" ]; then
            pmndx_log " * Container not running, starting up"
            podman container start "${name}"


            pmndx_verify_running ${name}
        else
            pmndx_log " * Container is already running"
        fi
    fi
}

