#!/bin/bash
# ----------------------------------------------------------------------------
#
# Copyright (c) 2019, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
#
# WSO2 Inc. licenses this file to you under the Apache License,
# Version 2.0 (the "License"); you may not use this file except
# in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#
# ----------------------------------------------------------------------------

# Build artifacts and versions
: ${product:="wso2ei"}
: ${profile:="integrator"}
: ${product_version:="6.5.0"}
: ${products_dir:="/usr/local/wso2"}
: ${distribution_path:=${products_dir}"/"${product}"/"${profile}"/"${product_version}}
: ${install_path:=${distribution_path}"/"${product}"-"${product_version}}
: ${product_binary:=${product}"-"${product_version}".zip"}
: ${puppet_env:="/etc/puppet/code/environments/production"}

# Apply configurations
puppet apply -e "include ei_integrator_master" --modulepath=${puppet_env}/modules

# exit immediately if a command exits with a non-zero status
set -e

updated_templates=()

copy_to_agent() {
  cd ${distribution_path}
  rm ${product_binary}
  echo "Repackaging ${1} pack..."
  zip -qr ${product_binary} ${product}-${product_version}
  echo "Copying updated pack to Agent files directory..."
  cp ${product_binary} ${puppet_env}/modules/ei_integrator/files/
}

# Check if user has a WSO2 subscription
while :
do
  read -p "Do you have a WSO2 subscription? (Y/n) "
  echo
  if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z "$REPLY" ]]
  then
    if [[ ! -f ${install_path}/bin/update_linux ]]
    then
      echo "Update executable not found. Please download package for subscription users from website."
      exit 1
    else
      break
    fi
  elif [[ $REPLY =~ ^[Nn]$ ]]
  then
    copy_to_agent "modified"
    exit 0
  else
    echo "Invalid input provided."
    sleep .5
  fi
done

# Create updates directory if it doesn't exist
if [[ ! -d ${distribution_path}/updates ]]
then
  mkdir ${distribution_path}/updates
fi

# Getting update status
# 0 - first/last update successful
# 1 - Error occurred in last update
# 2 - In-place has been updated
# 3 - conflicts encountered in last update
status=0
if [[ -f ${distribution_path}/updates/status ]]
then
  status=$(cat ${distribution_path}/updates/status)
fi

# Move into binaries of installation directory
cd ${install_path}/bin

# Run in-place update
if [[ ${status} -eq 0 ]] || [[ ${status} -eq 1 ]] || [[ ${status} -eq 2 ]]
then
  ./update_linux --verbose 2>&1 | tee ${install_path}/bin/output.txt
  update_status=${PIPESTATUS[0]}
elif [[ ${status} -eq 3 ]]
then
  ./update_linux --verbose --continue 2>&1 | tee ${install_path}/bin/output.txt
  update_status=${PIPESTATUS[0]}

  # Handle user running update script without resolving conflicts
  if [[ ${update_status} -eq 1 ]]
  then
    echo "Error occurred while attempting to resolve conflicts."
    exit 1
  fi
else
  echo "status file is invalid. Please delete or clear file content."
  exit 1
fi

# Handle the In-place tool being updated
if [[ ${update_status} -eq 2 ]]
then
    echo "In-place tool has been updated. Running update again."
    ./update_linux --verbose 2>&1 | tee ${install_path}/bin/output.txt
    update_status=${PIPESTATUS[0]}
fi

# Update status
echo ${update_status} > ${distribution_path}/updates/status
if [[ ${update_status} -eq 0 ]]
then
  echo
  echo "Update completed successfully."
  copy_to_agent "updated"
elif [[ ${update_status} -eq 3 ]]
then
  echo "Conflicts encountered. Please resolve conflicts and run the update script again."
else
  echo "Update error occurred. Stopped with exit code ${update_status}"
  exit ${update_status}
fi

# Get list of merged files
if [[ ${update_status} -eq 0 ]] # If update is successful
then
  sed -n '/files./,/Successfully/p' ${install_path}/bin/output.txt > ${install_path}/bin/merged_files.txt
elif [[ ${update_status} -eq 3 ]] # If conflicts were encountered during update
then
  sed -n '/files./,/Merging/p' ${install_path}/bin/output.txt > ${install_path}/bin/merged_files.txt
fi

if [[ -s ${install_path}/bin/merged_files.txt ]]
then
  sed -i '1d' ${install_path}/bin/merged_files.txt # Remove first line from file
  sed -i '$ d' ${install_path}/bin/merged_files.txt # Remove last line from file

  while read -r line; do
    filepath=${line##*${product}-${product_version}/}
    template_file=${puppet_env}/modules/ei_integrator_master/templates/carbon-home/${filepath}.erb
    if [[ -f ${template_file} ]]
    then
      updated_templates+=(${template_file})
    fi
  done < ${install_path}/bin/merged_files.txt

  # Display template files to be changed
  if [[ -n ${updated_templates} ]]
  then
    DATE=`date +%Y-%m-%d`
    update_file_name="update_${DATE}.log"
    echo
    echo "Update has made changes to the following files. Please update the templates accordingly before running the next update." | tee -a ${distribution_path}/updates/${update_file_name}
    printf '%s\n' "${updated_templates[@]}" | tee -a ${distribution_path}/updates/${update_file_name}
  fi
fi

# Clean files
rm ${install_path}/bin/output.txt ${install_path}/bin/merged_files.txt
