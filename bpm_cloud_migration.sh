#!/bin/bash
# --- Start Functions ---

function disableScriptTasks(){

	local isServiceTask=0
	local linecounter=1
	local bpmn_filename=$1

	while read line; do

		  if [[ $line == "<bpmn:scriptTask"* ]]; 
		  then 

			echo "bpmn:scriptTask found at line number:" $linecounter
			echo $line;
			isServiceTask=1; 

		  elif [[ $line == *"isDraft"* && $isServiceTask == 1 ]];
		  then

		  	isServiceTask=0;
			echo "Enabling isDraft property to disable serviceTask when converted from scriptTask. Line number:" $linecounter; 
			echo $line;
			### Only changes isDraft=true for the row indicated by $linecounter since the option 'g' at the end of pattern is not specified. 
			sed -i $linecounter's/bpmnext:BooleanFeature value=\"false\" name=\"isDraft\"/bpmnext:BooleanFeature value=\"true\" name=\"isDraft\"/' "${bpmn_filename}";

		  fi
	
		  #echo $line;
		  let linecounter++;
		  ##linecounter=$((linecounter+1));

	done < "${bpmn_filename}";

}


function addPCSRESTConnectionToScriptTask(){

	local isScriptTask=0
	#local addOracleExtensions_conversations=0;
	local linecounter=1
	local bpmn_filename=$1

	while read line; do

		  if [[ $line == "<bpmn:scriptTask"* ]]; 
		  then 
			echo -e "Adding PCS_REST_Integration to scriptTask. Line number: " $linecounter
			echo $line
			sed -i $linecounter's/bpmn:scriptTask/bpmn:scriptTask implementation=\"Services.Externals.PCS_REST_Integration\" operationRef=\"bpmn:getProcessDefinitions\" resourceId=\"ProcessDefinitions\"/' "${bpmn_filename}"
			isScriptTask=1
			#addOracleExtensions_conversations=1

		  elif [[ $line == "</bpmnext:Localization>"* && $isScriptTask == 1 ]];
		  then
			echo -e "Adding Conversational to serviceTask. Line number: " $linecounter; 
			echo -e $line;			
			sed -i $linecounter'r ./config/PCS_REST_serviceTask_bpmnext_Conversational.xml' "${bpmn_filename}"
		  	isScriptTask=0;
			### Counting number of lines /config/PCS_REST_serviceTask_bpmnext_Conversational.xml
			### This is required to keep $linecounter sync with the content that it is being added by sed command above 
			### which is adding more than 1 line with through a XML snippet(./config/PCS_REST_serviceTask_bpmnext_Conversational.xml) 
			### to the original file ${bpmn_filename} used in this while loop
			total_lines_bpmnext_conversational=$(wc -l < ./config/PCS_REST_serviceTask_bpmnext_Conversational.xml)
			linecounter=$((linecounter+$total_lines_bpmnext_conversational));
		  fi
	
		  #echo $line;
		  let linecounter++;
		  ##linecounter=$((linecounter+1));

	done < "${bpmn_filename}";


	#if [[ ${addOracleExtensions_conversations} == 1 ]]; 
	#then			
		### Conversations tag is added in case there is at least one scriptTask activity found within ${bpmn_filename} file
		### Finds line number to add content from PCS_REST_OracleExtensions_Conversations.xml to composite.xml through sed command. 
		### It returns only first line containing the searched string
		local linenumber=0			
		linenumber=$(grep -n -m 1 "<bpmnext:Conversations>" "${bpmn_filename}" | sed 's/\([0-9]*\).*/\1/')

		if [[ $linenumber > 0 ]]; 
		then 
			### <bpmnext:Conversations> tag found. Adding content within the tag			
			### Adding content from ./config/PCS_REST_OracleExtensions_Conversations_short.xml file to ${bpmn_filename}
			echo -e "Content from PCS_REST_OracleExtensions_Conversations_short.xml will be added at line number: " $linenumber	
			sed -i $linenumber'r ./config/PCS_REST_OracleExtensions_Conversations_short.xml' "${bpmn_filename}"
		else
			### <bpmnext:Conversations> tag not found, then a new Conversations tag will be added to the ${bpmn_filename}	
			### It returns only first line containing the searched string					
			#linenumber=$(grep -n -m 1 "</bpmnext:Localization>" "${bpmn_filename}" | sed 's/\([0-9]*\).*/\1/')
			linenumber=$(grep -n -m 1 "</bpmnext:FeatureSet>" "${bpmn_filename}" | sed 's/\([0-9]*\).*/\1/')

			### Adding content from ./config/PCS_REST_OracleExtensions_Conversations.xml file to ${bpmn_filename}
			echo -e "Content from PCS_REST_OracleExtensions_Conversations.xml will be added at line number: " $linenumber	
			sed -i $linenumber'r ./config/PCS_REST_OracleExtensions_Conversations.xml' "${bpmn_filename}"
		fi

	#fi

}


function addPCSRESTConnectionToProjectDefinition() {

	local directoryname
	local executedisableScriptTasks=$1
	
	find . -mindepth 2 -maxdepth 2 -type d | while read directoryname;
	do 

		### Creating PCS Connection assets(businessCatalog, Schemas, connectors, WADLs) so that a serviceTask, 
		### that was created from a scriptTask, something not supported in PCS, can call a dummy PCS REST API in order to 
		### execute all transformations from the mappings that came defined within the original scriptTask

		echo -e "\n#################################################################################################################################################";	
		echo "Working on Directory: ${directoryname} to add PCS REST Connection"; 
		echo "#################################################################################################################################################";	

		## Check to find at least one scriptTask activity within at least one BPMN process in a BPM application project
		## If this is true, then it unzips PCSREST_config_assets.zip to be further added to scriptTasks when converted to serviceTask
		local countScriptTasksperApplication=$(find "${directoryname}/SOA/processes" -type f -name '*.bpmn' -exec cat {} + | grep -c 'bpmn:scriptTask')

		if [[ $countScriptTasksperApplication != 0 ]]; 
	        then 
			if [[ $executedisableScriptTasks == "disableScriptTasks" ]]; 
			then 
				### invoke the function disableScriptTasks for all .bpmn files within current project directory
				find "${directoryname}/SOA/processes" -type f -name '*.bpmn' | while read bpmn_filename;
				do
					echo "#################################################################################################################################################";		
					echo "**** calling function disableScriptTasks(${bpmn_filename}) ****"
					echo -e "#################################################################################################################################################\n";	
		
					disableScriptTasks "${bpmn_filename}"
		
					echo -e "\n#################################################################################################################################################\n";		
		
				done;
				continue;

			else

				echo "Unzipping PCS REST Connection assets at ${directoryname}/SOA"
				unzip -o -O UTF-8 -d "${directoryname}/SOA" PCSREST_config_assets.zip 
				#countScriptTasksperApplication=0
		
			fi

		else
			echo -e "This application project does not have any bpmn process files with scriptTask activities."
			continue
		fi

		### Changing ${directoryname}/SOA/composite.xml of every BPM project to add reference, wire, and 
		### reference to componentType of BPMN Process component to support PCS_REST_Connection
		echo -e "\n#################################################################################################################################################";	
		echo "Changing file ${directoryname}/SOA/composite.xml to support PCS_REST_Connection"; 
		echo "#################################################################################################################################################";	

		### Finds line number to add content from PCS_REST_Integration_Reference.xml to composite.xml through sed command. 
		### It returns only first line containing the searched string
		local linenumber=0	
		linenumber=$(grep -n -m 1 "<wire>" "${directoryname}/SOA/composite.xml" | sed 's/\([0-9]*\).*/\1/')

		if [[ $linenumber > 0 ]]; 
		then 
			echo -e "Content from PCS_REST_Integration_Reference.xml will be added at line number: " $linenumber	
			#It is needed to decrease linenumber by 1 in order to add content above the searched string, otherwise it would be adding below it		
			let linenumber--; 
			### Add content from ./config/PCS_REST_Integration_Reference.xml file to composite.xml
			sed -i $linenumber'r ./config/PCS_REST_Integration_Reference.xml' "${directoryname}/SOA/composite.xml"
			cat "./config/PCS_REST_Integration_Reference.xml"
		else
			echo "Unable to find a line to add PCS_REST_Integration_Reference.xml content. Skipping to next BPM application project if any."
			continue		
		fi


		## Returns all .bpmn files with a scriptTask to add both PCS_REST_Integration_componentTypeReference* and PCS_REST_Integration_wire.xml
		## within their respective session in the composite.xml file		
		find "${directoryname}/SOA/processes" -type f -name '*.bpmn' -exec grep -l 'bpmn:scriptTask' {} + | while read -r bpmn_filename; 
		do
		    local bpmnfilename=${bpmn_filename##*/}  ## Returns only process file name (Eg.: TravelApproval.bpmn)
		    echo -e "Looking for $bpmnfilename within composite.xml since this process has scriptTask activities"

		    ### Finds line number to add content from PCS_REST_Integration_componentTypeReference*.xml to composite.xml through sed command. 
		    ### It returns only first line containing the searched string
  		    linenumber=0	
		    linenumber=$(grep -n -m 1 ${bpmnfilename} "${directoryname}/SOA/composite.xml" | sed 's/\([0-9]*\).*/\1/')

		    if [[ $linenumber > 0 ]]; 
		    then 

			## It is needed to increase linenumber by 1 in order to add content one line below the searched string
			## (Eg.:<implementation.bpmn src="processes/TravelApproval.bpmn"/>
			## under the respective <componentType> for each .bpmn process file			
			let linenumber++; 

			local componentTypeString			
			componentTypeString=$(sed -n ${linenumber}p "${directoryname}/SOA/composite.xml")
			echo "ComponentTypeString: $componentTypeString"

			if [[ $componentTypeString == *"<componentType>" ]]; 
  		        then 
			     ### Add content from ./config/PCS_REST_Integration_componentTypeReference_short.xml file to composite.xml
		 	     echo -e "Content from PCS_REST_Integration_componentTypeReference_short.xml will be added at line number: " $linenumber	
			     sed -i $linenumber'r ./config/PCS_REST_Integration_componentTypeReference_short.xml' "${directoryname}/SOA/composite.xml"
			     cat "./config/PCS_REST_Integration_componentTypeReference_short.xml"

			elif [[ $componentTypeString == *"<componentType/>" ]];
			then
			     ### Removes the <componentType/> tag to add content from ./config/PCS_REST_Integration_componentTypeReference.xml
			     echo "Removing tag <componentType/>"
			     sed -i "${linenumber}d" "${directoryname}/SOA/composite.xml"
			     ### Decrease linenumber by 1 since <componentType/> was removed 
			     let linenumber--
			     ### Add content from ./config/PCS_REST_Integration_componentTypeReference.xml file to composite.xml
		 	     echo -e "Content from PCS_REST_Integration_componentTypeReference.xml will be added at line number: " $linenumber	
			     sed -i $linenumber'r ./config/PCS_REST_Integration_componentTypeReference.xml' "${directoryname}/SOA/composite.xml"
			     cat "./config/PCS_REST_Integration_componentTypeReference.xml"
			else
			
			     echo "Unable to find <componentType> or <componentType/> tag under <implementation.bpmn>. Skipping to next BPM application project if any."
			     break
			fi


		    else
			echo "Unable to find a line to add PCS_REST_Integration_componentTypeReference*.xml content. Skipping to next BPM application project if any."
			break
		    fi
		    

		    ### Finds line number to add content from PCS_REST_Integration_wire.xml to composite.xml through sed command. 
		    ### It returns only first line containing the searched string
		    linenumber=0			
		    linenumber=$(grep -n -m 1 "</composite>" "${directoryname}/SOA/composite.xml" | sed 's/\([0-9]*\).*/\1/')

		    if [[ $linenumber > 0 ]]; 
		    then 
		    	echo -e "Content from PCS_REST_Integration_wire.xml will be added at line number: " $linenumber	
			#It is needed to decrease linenumber by 1 in order to add content above the searched string, otherwise it would be adding below it		
			let linenumber--;
			## Creates a temp PCS_REST_Integration_wire.xml file that will receive ${bpmnprocessname} as part of the <source.uri>
			bpmnprocessname="${bpmnfilename%.*}" ## Removes suffix starting with ".", so in this example would be returned "TravelApproval" only.		
			sed -e "s/<source.uri>/<source.uri>${bpmnprocessname}/g" "./config/PCS_REST_Integration_wire.xml" | cat > "./config/PCS_REST_Integration_wire_${bpmnprocessname}.xml"

			### Add content from ./config/PCS_REST_Integration_wire.xml file to composite.xml
			#sed -i $linenumber'r ./config/PCS_REST_Integration_wire.xml' "${directoryname}/SOA/composite.xml"
			sed -i $linenumber"r ./config/PCS_REST_Integration_wire_${bpmnprocessname}.xml" "${directoryname}/SOA/composite.xml"
			cat "./config/PCS_REST_Integration_wire_${bpmnprocessname}.xml"
			rm  "./config/PCS_REST_Integration_wire_${bpmnprocessname}.xml" 
		    else
		   	echo "Unable to find a line to add PCS_REST_Integration_wire.xml content. Skipping to next BPM application project if any."
		   	break
		    fi

		    echo "#################################################################################################################################################";		
		    echo "**** calling function addPCSRESTConnectionToScriptTask(${bpmn_filename}) ****"
		    echo -e "#################################################################################################################################################\n";	
			
		    addPCSRESTConnectionToScriptTask "${bpmn_filename}"
			
		    echo -e "\n#################################################################################################################################################\n";		
			

		done




		### invoke the function addPCSRESTConnectionToScriptTask for all .bpmn files within current project directory
		#find "${directoryname}/SOA/processes" -type f -name '*.bpmn' | while read bpmn_filename;
		#do
		#	echo "#################################################################################################################################################";		
		#	echo "**** calling function addPCSRESTConnectionToScriptTask(${bpmn_filename}) ****"
		#	echo -e "#################################################################################################################################################\n";	
		#
		#	addPCSRESTConnectionToScriptTask "${bpmn_filename}"
		#
		#	echo -e "\n#################################################################################################################################################\n";		
		#
		#done;

	done;

}



function movingProjectDataObjects() {

	local directoryname
	
	find . -mindepth 2 -maxdepth 2 -type d | while read directoryname;
	do 
		echo -e "\n#################################################################################################################################################";	
		echo "Working on Directory: ${directoryname} for moving project Data Objects"; 
		echo "#################################################################################################################################################";	
		#find "${directoryname}" -type f -name '*.bpmn'; 
		### Returns full path (Eg.: ./Bpm Projects/TravelApplication/SOA/processes/TravelApproval.bpmn	
		local FIRST_BPM_PROCESS="$(find "${directoryname}" -type f -name '*.bpmn' | head -n 1)" 
		FIRST_BPM_PROCESS=${FIRST_BPM_PROCESS##*/}  ## Returns only process file name (Eg.: TravelApproval.bpmn)
		FIRST_BPM_PROCESS="${FIRST_BPM_PROCESS%.*}"   ## Removes suffix starting with ".", so in this example would be returned "TravelApproval" only.
		echo "First BPMN process returned (${FIRST_BPM_PROCESS}) to be used as component Reference for Business Indicator: ${directoryname}/SOA/businessIndicators.bi" ; 	

		### PCS doesn't support project Data Objects, then a componentName with "projectInfo" as input is not valid, thus it is needed 
		### to replace by a valid process name within the project 
		### The regexp '.\+' match all the characters in a string(no spaces) with at least one character
		### More details about sed & regexp can be found at the following link 
		### https://www.gnu.org/software/sed/manual/html_node/Regular-Expressions.html#Regular-Expressions
		#sed -i "s/componentName=\".\+\"/componentName=\"${FIRST_BPM_PROCESS}\"/g" "${directoryname}/SOA/businessIndicators.bi";

		if [[ -z ${FIRST_BPM_PROCESS} ]]; then

		   echo "Unable to find a valid process name to be used as the ComponentName for business indicators. Skipping to next BPM application project if any."
		   continue

		fi

		#sed -i "s/componentName=\".\+\"/componentName=\"${FIRST_BPM_PROCESS}\" componentType=\"BPMN\"/g" "${directoryname}/SOA/businessIndicators.bi";
		sed -i "s/componentName=\".\+\"/componentName=\"${FIRST_BPM_PROCESS}\" componentType=\"BPMN\" bpmn=\"http:\/\/www.omg.org\/bpmn20\"/g" "${directoryname}/SOA/businessIndicators.bi";    


		### This will delete the last two lines from all .bpmn files, and eliminates the need for redirection and temp files, 
		### since it edits the files in place through sed -i option. It will also work with filenames and paths that contain spaces. 
		### It is used to remove the last two lines from every .bpmn file to be able to properly add Project data objects at the end of each .bpmn file
		find "${directoryname}" -type f -name '*.bpmn' -exec sed -i 'N;$!P;$!D;$d' '{}' ';'

		### Moving Project Dataobjects from projectInfo.xml to all bpmn process files
		echo "Moving Project data objects from ${directoryname}/SOA/projectInfo.xml to all bpmn process files";	

		### It is needed to explicity export dir_name in order to the command below to be able to access that variable through 
		### the option -exec sh -c, otherwise it will return null and then it will raise the following error 
		### "sed: can't read /SOA/projectInfo.xml: No such file or directory" since the variable {dir_name} is not
		### acessible through bash	
		export dir_name="${directoryname}"

		### Copying data from projectInfo.xml that is within <dataObjects> and </dataObjects> tags to all .bpmn files		
		### Using '*' as regexp for sed, since <dataObjects> tag can contain any name as for the namespace, or even it can't have anything explicitly declared, 
		### so both <dataObjects> and <ns5:dataObjects> should work smoothly
		find "${directoryname}" -type f -name '*.bpmn' -exec sh -c 'echo "$(sed -e "1,/<*dataObjects>/d" "${dir_name}/SOA/projectInfo.xml" | head -n -2)" >> "{}"' \;
		#COPY_DATA_OBJECTS="$(sed -e "1,/<*dataObjects>/d" "${directoryname}/SOA/projectInfo.xml" | head -n -2)"
		#echo ${COPY_DATA_OBJECTS};
		#find "${directoryname}" -type f -name '*.bpmn' -exec sh -c 'echo ${COPY_DATA_OBJECTS} >> "{}"' \;
		echo "Project data objects moved successfully!!";	

		## Changing tags copied from ${dir_name}/SOA/projectInfo.xml to all .bpmn files in order to be supported in PCS process files		
		echo "Changing dataobjects tags imported from ${dir_name}/SOA/projectInfo.xml to be supported in PCS process files!!";	
		find "${directoryname}" -type f -name '*.bpmn' -exec sed -i 's/ns2:/bpmn:/g' {} \; ## ns2 means that BPM project was created in Oracle BPM Composer	
		find "${directoryname}" -type f -name '*.bpmn' -exec sed -i 's/ns3:/bpmn:/g' {} \; ## ns3 means that BPM project was created in Oracle BPM Studio(JDev)	
		find "${directoryname}" -type f -name '*.bpmn' -exec sed -i 's/ns7:/bpmnext:/g' {} \;
		echo "Dataobjects tags changed!!";	


		### Enclosing all bpmn files with proper XML tags removed earlier for adding all project data objects into all .bpmn files	
		echo "Enclosing all bpmn files with proper XML tags removed earlier for adding all project data objects into all .bpmn files";	
		find "${directoryname}" -type f -name '*.bpmn' -exec sh -c 'echo "    </bpmn:process>" >> "{}"' \;
		find "${directoryname}" -type f -name '*.bpmn' -exec sh -c 'echo "</bpmn:definitions>" >> "{}"' \;


		### Removes Project dataobjects from projectInfo.xml since this is not supported in PCS
		### Reads everything BEFORE <dataObjects> and AFTER </dataObjects> tags and then concatenates content from both BEFORE and AFTER to update projectInfo.xml 		
		## without <dataObjects> and </dataObjects> tags respectively
		echo "Removing Project dataobjects from ${directoryname}/SOA/projectInfo.xml";	
		### Detailing the regular expression
		### [a-z]* matches any number of characters
		### [0-9]* matches any number of digits
		### :\? zero or one colon. 
		### Note that dataObjects namespace is optional, so these are valid inputs: 
		### <dataObjects>, </dataObjects>, <ns5:dataObjects>, </ns5:dataObjects>, so the regexp should be able to handle all these variations
		( sed -e "/<[a-z]*[0-9]*:\?dataObjects>/,\$d" "${directoryname}/SOA/projectInfo.xml" ; sed -e "1,/<\/[a-z]*[0-9]*:\?dataObjects>/d" "${directoryname}/SOA/projectInfo.xml" ) | cat > "${directoryname}/SOA/projectInfoTMP.xml"
		#( sed -e "/<dataObjects>/,\$d" "${directoryname}/SOA/projectInfo.xml" ; sed -e "1,/<\/dataObjects>/d" "${directoryname}/SOA/projectInfo.xml" ) | cat > "${directoryname}/SOA/projectInfoTMP.xml"
		cat "${directoryname}/SOA/projectInfoTMP.xml" > "${directoryname}/SOA/projectInfo.xml"
		rm "${directoryname}/SOA/projectInfoTMP.xml"

		### Another way of create regexp for sed to work against the projectInfo.xml in the statement above
		### sed -e "1,/<\/n\?s\?[0-9]\?:\?dataObjects>/d" "${directoryname}/SOA/projectInfo.xml" 
		### "n\?" matches 'n' optionally, s\? matches 'n' optionally, [0-9]\? matches any number between 0 and 9, but optionally, since '?' 
		### only matches zero or one digit or character
		### More details at https://www.gnu.org/software/sed/manual/html_node/Regular-Expressions.html#Regular-Expressions

	done;  

}


# --- End Functions ---



echo "#################################################################################################################################################";	
echo "#################################################################################################################################################";	
echo "#################################################################################################################################################";	
echo "Starting migration from Oracle BPM projects to be imported into PCS in a compatible fashion"
echo "#################################################################################################################################################";	
echo "#################################################################################################################################################";
echo "#################################################################################################################################################";		


echo "Decompressing all BPM project files (.exp) recursively"
find . -type f -name "*.exp" | xargs -P 5 -I fileName sh -c 'unzip -o -O UTF-8 -d "$(dirname "fileName")" "fileName"'

echo "Enabling BPM projects to run in PCS"
find . -type f -name 'projectInfo.xml' -exec sed -i 's/projectVersion=\"20120601\"/projectVersion=\"20140730\"/g' {} +

echo "Changing BPM activities to be supported within PCS"

echo "Transforming manualTasks into userTasks"
find . -type f -name '*.bpmn' -exec sed -i 's/manualTask/userTask/g' {} +

echo "Transforming both catch and throw signalEvents into messageEvents"
find . -type f -name '*.bpmn' -exec sed -i 's/signalEventDefinition/messageEventDefinition/g' {} +

#echo "Transforming Event Based Gateways into Exclusive Gateways"
#find . -type f -name '*.bpmn' -exec sed -i 's/eventGatewayType=\"Exclusive\"//g' {} +
#find . -type f -name '*.bpmn' -exec sed -i 's/bpmn:eventBasedGateway/bpmn:exclusiveGateway/g' {} +

echo "Transforming Complex Gateways into Inclusive Gateways"
find . -type f -name '*.bpmn' -exec sed -i 's/bpmn:complexGateway/bpmn:inclusiveGateway/g' {} +
find . -type f -name '*.bpmn' -exec sed -i 's/<bpmn:activationCondition xsi:type=\"bpmn:tFormalExpression\" xmlns:xsi=\"http:\/\/www.w3.org\/2001\/XMLSchema-instance\"\/>//g' {} +

echo "Tranforming Update Tasks into Service Tasks"
find . -type f -name '*.bpmn' -exec sed -i 's/<bpmnext:StringFeature value=\"UPDATE_OUTCOME\" name=\"updateType\"\/>//g' {} +

#echo "Transforming Human Task Initiator into Simple Human Task"
#find . -type f -name '*.bpmn' -exec sed -i 's/bpmnext:StringFeature value=\"INITIATOR\" name=\"humanTaskType\"/<bpmnext:StringFeature value=\"SIMPLE\" name=\"humanTaskType\"/g' {} +

echo "Removing all non supported attributes from Human task files"
find . -type f -name '*.task' -exec sed -i 's/<hideCreator>false<\/hideCreator>//g' {} +
find . -type f -name '*.task' -exec sed -i 's/<hideCreator>true<\/hideCreator>//g' {} +

find . -type f -name '*.task' -exec sed -i 's/<excludeSaturdayAndSunday>false<\/excludeSaturdayAndSunday>//g' {} +
find . -type f -name '*.task' -exec sed -i 's/<excludeSaturdayAndSunday>true<\/excludeSaturdayAndSunday>//g' {} +


echo "#################################################################################################################################################";	
echo "#################################################################################################################################################";	
echo "Moving Project Data Objects from projectInfo.xml to all bpmn process files for every Oracle BPM project under the migration root folder"
echo "#################################################################################################################################################";	
echo "#################################################################################################################################################";	
### invoke the function movingProjectDataObjects to move all project data objects found in all Oracle BPM projects to their bpmn processes instead
movingProjectDataObjects
echo -e "\n#################################################################################################################################################";	
echo "#################################################################################################################################################";	
echo "Moving Project Data Objects function finished"
echo "#################################################################################################################################################";	
echo "#################################################################################################################################################";


echo -e "\n#################################################################################################################################################";	
echo "#################################################################################################################################################";
echo "Calling addPCSRESTConnectionToProjectDefinition() function to add PCS REST Connection"
echo "#################################################################################################################################################";	
echo "#################################################################################################################################################";
varDisableScriptTasks=$1
addPCSRESTConnectionToProjectDefinition $varDisableScriptTasks
echo -e "\n#################################################################################################################################################";	
echo "#################################################################################################################################################";	
echo "addPCSRESTConnectionToProjectDefinition() function finished"
echo "#################################################################################################################################################";	
echo "#################################################################################################################################################";

	

echo -e "\nTransforming scriptTask tags into serviceTask tags\n"
find . -type f -name '*.bpmn' -exec sed -i 's/bpmn:scriptTask/bpmn:serviceTask/g' {} +

echo "#################################################################################################################################################";	
echo "All bpmn files changed successfully!!!" 
echo "#################################################################################################################################################";	


### Removing all *.gy files from all folders to avoid errors after importing project within PCS Composer due to type mismatch. Deleting these files will force PCS
### to rebuild them again while importing the project export file (.exp)
echo -e "\nRemoving all *.gy files from all folders"
find . -name '*.gy' -type f -delete

echo "Renaming all original BPM project files to .zip files"
find . -type f -name '*.exp' -exec rename 's/\.exp/.zip/' '{}' \;

echo -e "\nCompressing all directories after changes were properly applied to *.xml and *.bpmn files to create PCS enabled project files (.exp)\n"
#find . -mindepth 2 -maxdepth 2 -type d | xargs -P 5 -I directoryname sh -c 'zip -r "directoryname.exp" "directoryname"'
#find . -mindepth 2 -maxdepth 2 -type d | while read directoryname; do zip -r "${directoryname}.exp" "${directoryname}"; done;
find . -mindepth 2 -maxdepth 2 -type d | while read directoryname; do cd "${directoryname%/*}"; zip -r "${directoryname##*/}.exp" "${directoryname##*/}"; cd ..; done;

echo "#################################################################################################################################################";	
echo "#################################################################################################################################################";	
echo "#################################################################################################################################################";	
echo "PCS Migration finished!!!"
echo "#################################################################################################################################################";	
echo "#################################################################################################################################################";	
echo "#################################################################################################################################################";

#TEST
