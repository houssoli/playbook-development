# Refresh project in Tower
echo "Refreshing project in Ansible Tower."
tower-cli project update -n "Operating System Department" --monitor

TEMPLATES=$(ls|grep yml|cut -d'.' -f1)

# For all playbooks files we find in the cloned git repository
for item in ${TEMPLATES[@]}; do

	# Run a syntax check for all the playbooks
  	ansible-playbook --syntax-check ./$item.yml
  
  	# If the test is unsuccessful, exit, otherwise continue
  	if [ "$?" -ne 0 ]; then
      		echo "Syntax error found in: $item.yml. See details from syntax check above."
      		exit 1
  	else
      		# If there already is a test job_template found in Ansible Tower, delete it 
		if tower-cli job_template list|grep "Test - $item" >/dev/null; then
			echo "Found existing Test job_template for $item. Deleting it."
			tower-cli job_template delete --name "Test - $item check"
		fi	
        
		echo "Creating job_template: Test - $item"
        	tower-cli job_template create --name "Test - $item check" --description "Created by Jenkins: $(date)" --job-type run --inventory Hostnetwork --project "Operating System Department" --playbook "$item.yml" --credential "Required access on hostnet" --verbosity "debug"
        
		echo "Launching test run for template"
        	tower-cli job launch --job-template "Test - $item check" --monitor >$item.output
          
        	echo "Output from run:"
        	cat $item.output
          
        	# Fetch number of tasks which were OK, CHANGED, UNREACHABLE or FAILED
        	OK=$(cat $item.output|grep unreachable|awk '{ print $3 }'|cut -d= -f2)
        	CHANGED=$(cat $item.output|grep unreachable|awk '{ print $4 }'|cut -d= -f2)
        	UNREACHABLE=$(cat $item.output|grep unreachable|awk '{ print $5 }'|cut -d= -f2)
        	FAILED=$(cat $item.output|grep unreachable|awk '{ print $5 }'|cut -d= -f2)

        	# If target systems are reachable..
        	if [ "$UNREACHABLE" -eq 0 ]; then
        		# And no runs failed, we are happy
        		if [ "$FAILED" -eq 0 ]; then
            			echo "Test run for Test - $item completed successful."
                  		echo "Deleting test template"
                  		tower-cli job_template delete --name "Test - $item check"
                  		tower-cli job_template create --name "$item" --description "Created by Jenkins: $(date)" --job-type run --inventory Hostnetwork --project "Operating System Department" --playbook "$item.yml" --credential "Required access on hostnet" --job-tags "tested_ok"
              		else
                		echo "Test run for Test - $item failed."
                		exit 1
              		fi
          	# If any tasks exists with unreachable, we failed
          	else
          		echo "Test run for Test - $item failed. Targets unreachable."
              		exit 1
          	fi
	fi
done
