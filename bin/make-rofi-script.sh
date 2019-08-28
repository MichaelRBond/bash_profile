#!/bin/bash

ROFI_SCRIPT_PATH="/home/mbond/bin/rofi.sh"

rm ${ROFI_SCRIPT_PATH}
echo "#!/bin/bash" > ${ROFI_SCRIPT_PATH}
echo "PATH=${PATH}" >> ${ROFI_SCRIPT_PATH}
echo "export PATH" >> ${ROFI_SCRIPT_PATH} 
echo "rofi -combi-modi window,run -show combi -theme android_notification" >> ${ROFI_SCRIPT_PATH}

chmod a+x ${ROFI_SCRIPT_PATH}
