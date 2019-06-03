#!/usr/bin/env bash
# refer to https://cloud.google.com/dataproc/docs/concepts/compute/gpus
# should be pushed to gs://seqslab-deepvariant/scripts/

set -e -x

function update_apt_get() {
  for ((i = 0; i < 10; i++)) ; do
    if apt-get update; then
      return 0
    fi
    sleep 5
  done
  return 1
}

# Detect NVIDIA GPU
update_apt_get
apt-get install -y pciutils
# Add non-free Debian 9 Stretch packages.
# See https://www.debian.org/distrib/packages#note
#for type in deb deb-src; do
#  for distro in stretch; do
#    for component in contrib non-free; do
#      echo "${type} http://deb.debian.org/debian/ ${distro} ${component}" \
#          >> /etc/apt/sources.list.d/non-free.list
#    done
#  done
#done
sudo sed -i.bak 's/stretch[^ ]* main$/& contrib non-free/g' /etc/apt/sources.list
sudo apt install linux-headers-$(uname -r)
apt update

# Install proprietary NVIDIA Drivers and CUDA
# See https://wiki.debian.org/NvidiaGraphicsDrivers
export DEBIAN_FRONTEND=noninteractive
apt-get install -y linux-headers-$(uname -r|sed 's/[^-]*-[^-]*-//')
# Without --no-install-recommends this takes a very long time.
apt install -y -t stretch --no-install-recommends \
  nvidia-cuda-toolkit nvidia-kernel-common nvidia-driver nvidia-smi

# Create a system wide NVBLAS config
# See http://docs.nvidia.com/cuda/nvblas/
mkdir -p /etc/nvidia/
NVBLAS_CONFIG_FILE=/etc/nvidia/nvblas.conf

cat << EOF >> ${NVBLAS_CONFIG_FILE}
# Insert here the CPU BLAS fallback library of your choice.
# The standard libblas.so.3 defaults to OpenBLAS, which does not have the
# requisite CBLAS API.
NVBLAS_CPU_BLAS_LIB /usr/lib/libblas/libblas.so

# Use all GPUs
NVBLAS_GPU_LIST ALL

# Add more configuration here.
EOF

if (lspci | grep -q NVIDIA); then
  echo "NVBLAS_CONFIG_FILE=${NVBLAS_CONFIG_FILE}" >> /etc/environment

  # Rebooting during an initialization action is not recommended, so just
  # dynamically load kernel modules. If you want to run an X server, it is
  # recommended that you schedule a reboot to occur after the initialization
  # action finishes.
  # In pure CPU cluster, it will occur the following errors:
  # modprobe: ERROR: could not insert 'nvidia_current': No such device
  # modprobe: ERROR: could not insert 'nvidia_current': No such device
  # modprobe: ERROR: ../libkmod/libkmod-module.c:977 command_do() Error running install command for nvidia
  modprobe -r nouveau
  modprobe nvidia-current
  modprobe nvidia-drm
  modprobe nvidia-uvm
  modprobe drm
fi

function is_master() {
  local role="$(/usr/share/google/get_metadata_value attributes/dataproc-role)"
  if [[ "$role" == 'Master' ]] ; then
    true
  else
    false
  fi
}

if is_master ; then
  # ansible installation
  apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 93C4A3FD7BB9C367
  apt-get update
  apt-get install ansible -y
  apt-get install python-pip -y
  pip install jinja2
  # Restart YARN daemons to pick up new group without restarting nodes.
  systemctl restart hadoop-yarn-resourcemanager

else
  HOME=/usr/local
  PATH="$PATH:${HOME}/bin"
  DEEPVARIANT=deepvariant
  mkdir -p ${HOME}/seqslab
  cd ${HOME}/seqslab
  git clone https://github.com/atgenomix/deepvariant.git
  cd ${DEEPVARIANT}

  if (lspci | grep -q NVIDIA); then
    HOME="${HOME}" DV_GPU_BUILD=1 DV_INSTALL_GPU_DRIVERS=1 bash ./build-prereq.sh
  else
    HOME="${HOME}" bash ./build-prereq.sh
  fi
  HOME="${HOME}" PATH="${PATH}:${HOME}/bin" bash ./build_release_binaries.sh
  BUCKET="gs://${DEEPVARIANT}"
  BIN_VERSION="0.7.0"
  MODEL_VERSION="0.7.0"
  WGS_MODEL_NAME="DeepVariant-inception_v3-${MODEL_VERSION}+data-wgs_standard"
  WGS_MODEL_BUCKET="${BUCKET}/models/DeepVariant/${MODEL_VERSION}/${WGS_MODEL_NAME}"
  gsutil cp -R "${WGS_MODEL_BUCKET}" .
  WES_MODEL_NAME="DeepVariant-inception_v3-${MODEL_VERSION}+data-wes_standard"
  WES_MODEL_BUCKET="${BUCKET}/models/DeepVariant/${MODEL_VERSION}/${WES_MODEL_NAME}"
  gsutil cp -R "${WES_MODEL_BUCKET}" .
  if (lspci | grep -q NVIDIA); then
    systemctl restart hadoop-yarn-nodemanager
  fi
fi

echo "[info] setup_drivers.sh done"
