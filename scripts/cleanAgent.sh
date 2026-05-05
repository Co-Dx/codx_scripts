#####################################################################################
# cleanAgent script
# 2025-07-01
# This is the script used to clean up agents after pipeline runs. It is not to be
# used outside of the pipeline so it is not designed to be user friendly and cannot
# be run using the codx router.
#####################################################################################

RED='\x1B[31m'; GREEN='\x1B[32m'; YELLOW='\x1B[33m'; BLUE='\x1B[34m'; MAGENTA='\x1B[35m'; CYAN='\x1B[36m'; ORANGE='\x1B[33m'; WHITE='\x1B[37m'; NC='\x1B[0m'
CRITICAL="$RED[CRITICAL]$NC"; ERROR="$RED[ERROR]$NC"; WARNING="$YELLOW[WARNING]$NC"; INFO="$BLUE[INFO]$NC"; PASS="$GREEN[PASS]$NC"; FAIL="$RED[FAIL]$NC"

many=0
if [[ $1 == "-m" || $1 == "--many" ]]; then
    many=1
fi

#####################################################################################
# Remove all docker images and volumes from the VM. This is necessary because the
# pipeline agent will not clean up docker images and volumes automatically, and
# this can lead to the VM running out of disk space.
printf "========================================================================\n"
printf "CLEAN DOCKER\n"

if [[ $(docker images --format "{{.ID}}") != "" ]]; then
    docker rmi -f $(docker images --format "{{.ID}}") || true
fi
docker volume prune -f || true
docker builder prune -af || true
docker system prune -af || true

printf "\n$INFO Docker cleaned.\n"

#####################################################################################
# Clean containerd snapshots and images. Azure DevOps pipeline agents use containerd
# to pull the pipeline container image, and its storage at /var/lib/containerd is 
# separate from Docker's storage. Without this cleanup, containerd layers accumulate
# and consume disk space on /dev/root.
printf "========================================================================\n"
printf "CLEAN CONTAINERD\n"

if command -v ctr &> /dev/null; then
    # Remove all containerd images across all namespaces
    for ns in $(sudo ctr namespaces list -q 2>/dev/null); do
        sudo ctr -n "$ns" images ls -q 2>/dev/null | while read -r img; do
            sudo ctr -n "$ns" images rm "$img" 2>/dev/null || true
        done
        # Clean up any leased snapshots
        sudo ctr -n "$ns" leases ls -q 2>/dev/null | while read -r lease; do
            sudo ctr -n "$ns" leases rm "$lease" 2>/dev/null || true
        done
    done
    printf "\n$INFO Containerd images cleaned via ctr.\n"
elif command -v crictl &> /dev/null; then
    sudo crictl rmi --prune 2>/dev/null || true
    printf "\n$INFO Containerd images cleaned via crictl.\n"
else
    printf "\n$WARNING Neither ctr nor crictl found, skipping containerd cleanup.\n"
fi

# Clean up any orphaned overlayfs snapshots left on disk
if [[ -d /var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots ]]; then
    # Restart containerd to release references, then garbage collect
    sudo systemctl restart containerd 2>/dev/null || true
    sleep 2
fi

printf "\n$INFO Containerd cleaned.\n"

#####################################################################################
# Remove all files and directories in the _work directory that are not needed for 
# the pipeline agent to function
printf "========================================================================\n"
printf "CLEAN WORKING DIRECTORY\n"

# This will iterativly select all the directories in the _work directory
find ~/myagent/_work -mindepth 1 -maxdepth 1 -type d | while read -r subdir; do
    # If the directory is a number, then it is a job directory and its intrenal 
    # structure should be cleaned up. If the directory is not a number, then it
    # should be removed completely.
    if [[ $(basename "$subdir") =~ ^[0-9]+$ ]]; then
        # This will iterativly select all the directories in the job directory
        find $subdir -mindepth 1 -maxdepth 1 -type d,f | while read -r subdir2; do
            # If the directory is an s directory it is the base directory used 
            # durring the pipeline run, and should be kept. However all of the 
            # files and directories inside of it should be removed.
            # If the directory is not an s directory, then it should be removed
            # completly
            if [[ $(basename "$subdir2") == "s" ]]; then
                # If there are multiple repositories being used in a single job
                # then we need to delete everything inside the repos but not the
                # repos themselves. If there is only a single repository being
                # used in a job, then we can delete the entire s directory.
                if [[ $many -eq 1 ]]; then
                    find $subdir2 -mindepth 2 -print -delete
                else
                    find $subdir2 -mindepth 1 -print -delete
                fi
            else
                rm -rvf $subdir2 || true
            fi
        done
    else
        rm -rvf $subdir || true
    fi
done

# This will iterativly select all the files in the _work directory and then remove 
# them
find ~/myagent/_work -mindepth 1 -maxdepth 1 -type f | while read -r file; do
    rm -vf "$file"
done

printf "\n$INFO Working directory cleaned.\n"

#####################################################################################
# Remove the storage_preview-1.0.0b1-py2.py3-none-any.whl file from the VM. This 
# is necessary becasue the file will not be cleaned up naturally by the pipeline 
# agent.
printf "========================================================================\n"
printf "CLEAN PYTHON PACKAGES\n"

rm -rvf /tmp/*/storage_preview-1.0.0b1-py2.py3-none-any.whl || true

printf "\n$INFO Python packages cleaned.\n"
