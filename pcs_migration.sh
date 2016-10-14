echo "Starting migration from BPM projects to be imported into PCS in a compatible fashion"

echo "Decompressing all BPM project files (.exp) recursively"
find . -type f -name "*.exp" | xargs -P 5 -I fileName sh -c 'unzip -o -O UTF-8 -d "$(dirname "fileName")" "fileName"'

echo "Making BPM projects PCS enabled"
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

echo "Renaming all BPM project files to .zip file"
find . -type f -name '*.exp' -exec rename 's/\.exp/.zip/' '{}' \;

echo "Compressing all directories after changes were properly applied to *.xml and *.bpmn files to create PCS enabled project files (.exp)"
#find . -mindepth 2 -maxdepth 2 -type d | xargs -P 5 -I directoryname sh -c 'zip -r "directoryname.exp" "directoryname"'
#find . -mindepth 2 -maxdepth 2 -type d | while read directoryname; do zip -r "${directoryname}.exp" "${directoryname}"; done;
find . -mindepth 2 -maxdepth 2 -type d | while read directoryname; do cd "${directoryname%/*}"; zip -r "${directoryname##*/}.exp" "${directoryname##*/}"; cd ..; done;

echo "PCS Migration Completed!!!"

