# ----------------------------------------------------------------------------
#  Copyright (c) 2018 WSO2, Inc. http://www.wso2.org
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
# ----------------------------------------------------------------------------

# Claas ei_msf4j::params
# This class includes all the necessary parameters.
class ei_msf4j::params {
  $user = 'wso2carbon'
  $user_group = 'wso2'
  $product = 'wso2ei'
  $product_version = '6.4.0'
  $profile = 'msf4j'
  $service_name = "${product}-${profile}"

  # JDK Distributions
  if $::osfamily == 'redhat' {
    $lib_dir = "/usr/lib64/wso2"
  }
  elsif $::osfamily == 'debian' {
    $lib_dir = "/usr/lib/wso2"
  }
  $jdk_name = 'amazon-corretto-8.202.08.2-linux-x64'
  $java_home = "${lib_dir}/${jdk_name}"

  # Define the template
  $start_script_template = "wso2/msf4j/bin/carbon.sh"

  # Directories
  $products_dir = "/usr/local/wso2"

  # Product and installation information
  $product_binary = "${product}-${product_version}.zip"
  $distribution_path = "${products_dir}/${product}/${profile}/${product_version}"
  $install_path = "${distribution_path}/${product}-${product_version}"
}