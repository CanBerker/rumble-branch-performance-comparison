#!/bin/bash
set -e # exit if any command fails

# read parameters
branch1=$1
branch2=${2:-master}
repetition_count=${3:-5}
dataset=${4:-"large"}       # large, medium, small
rumble_project_root=${5:-"../rumble"}

echo "branch1: $branch1"
echo "branch2: $branch2"
echo "repetition_count: $repetition_count"
echo "dataset: $dataset"
echo "rumble_project_root: $rumble_project_root"

# get jars from project branches
for branch_index in 1 2
do
    branch_name="branch$branch_index"
    echo "Getting jar for branch: ${!branch_name}"
    pushd $rumble_project_root
    git checkout ${!branch_name}
    mvn clean compile assembly:single
    popd
    mkdir -p bin
    chmod -R 755 bin
    find ../rumble/target/ -name "*.jar" -exec cp {} "bin/${!branch_name}_exec.jar" \;
done

# clean leftover logs and outputs
find . -name "*log*.txt" -type f | xargs rm -rf 
find . -name "*output*.txt" -type d | xargs rm -rf

export SPARK_SUBMIT_OPTS=-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=5005;

for ((i=0; i<repetition_count; i++));
do
    echo "Iteration: $i "
    for query in "query1" "query4" "query5"
    do
        echo "Query: $query "
        for branch in $branch1 $branch2
        do
            echo "Branch: $branch "
            # define query parameters
            query_path="./${query}/${dataset}-${query}.jq"
            query_ouput_path="./output/${dataset}-${branch}-${query}-output${i}.txt"
            query_log_path="./output/${dataset}-${branch}-${query}-log${i}.txt"

            spark-submit --master local[*] "bin/${branch}_exec.jar" --query-path "${query_path}" --output-path "${query_ouput_path}" --log-path "${query_log_path}" --result-size 16000000
        done
    done
done

# cleanup unused output files
find . -name "*output*.txt" -type d | xargs rm -rf

# run python script that calculates the average performance metrics across repetitions
python aggregateResults.py $branch1 $branch2 $repetition_count $dataset

