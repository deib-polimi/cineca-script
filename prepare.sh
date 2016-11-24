#!/bin/bash
## Copyright 2015-2016 Alessandro Maria Rizzi
##
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
##
##     http://www.apache.org/licenses/LICENSE-2.0
##
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.

rm -rf local

wget http://home.deib.polimi.it/arizzi/cineca/hive-tez-binaries.tar.gz
tar -xvf hive-tez-binaries.tar.gz
rm -f hive-tez-binaries.tar.gz

wget http://home.deib.polimi.it/arizzi/cineca/dsdgen.tar.gz
tar -xvf dsdgen.tar.gz
rm -f dsdgen.tar.gz

wget http://home.deib.polimi.it/arizzi/cineca/spark-binaries.tar.gz
tar -xvf spark-binaries.tar.gz
rm -f spark-binaries.tar.gz
