#!/bin/sh

echo "=====================  $0   $1" 
cd ..

filename=$(basename -- "$1")
foldername="${filename%.*}"
echo "===================== displaying : ./logos/$foldername/image1.jpg"
./bin/jpgr "./logos/$foldername/image1.jpg"   # == Displays a rotated preview of the jpeg file


# Check firmware version
MIYOO_VERSION=`/etc/fw_printenv miyoo_version`
MIYOO_VERSION=${MIYOO_VERSION#miyoo_version=}
echo "현재 펌웨어 버전 : $MIYOO_VERSION"

if [ -f "/customer/app/axp_test" ]; then  # differenciate MM and MMP supported firmware
	MODEL="MMP"
	SUPPORTED_VERSION="202306282128"
else
	MODEL="MM"
	SUPPORTED_VERSION="202306111426"
fi



if [ $MIYOO_VERSION -gt $SUPPORTED_VERSION ]; then
	./bin/blank
	./bin/say "지원하지 않는 펌웨어입니다."$'\n 20230326 이후 버전은\n현재 지원되지 않습니다.\n\n메뉴로 돌아가려면 아무키나 누르세요.'
	./bin/confirm any
	exit 0
fi


# =========================================== Functions ===========================================
HexEdit() {
	filename=$1
	offset=$2
	value="$3"
	binary_value=$(printf "%b" "\\x$value")
	printf "$binary_value" | dd of="$filename" bs=1 seek="$offset" conv=notrunc
}

checkjpg() {
	JpgFilePath=$1
	Filename=`basename "$JpgFilePath"`
	echo
	./bin/checkjpg "$JpgFilePath"
	CHECK_JPG=$?
	if [ $CHECK_JPG -eq 0 ]; then
		echo "$Filename is a valid VGA JPG file"
	elif [ $CHECK_JPG -eq 1 ]; then
		./bin/blank
		./bin/say "$Filename is not a valid jpg file !"$'\n\n(Try to open it with your favorite image\neditor and \"save as\" -> jpg again)\n\nExiting without flash !'
		./bin/confirm any
		exit 0
	elif [ $CHECK_JPG -eq 2 ]; then
		./bin/blank
		./bin/say "$Filename "$'doesn\'t have \nthe right resolution !\n\nIt should be 640x480 (VGA)\n\nExiting without flash !'
		./bin/confirm any
		exit 0
	else
	  echo "Unknown Checkjpg error occurred"
	  exit 0
	fi
}
# =================================================================================================



# if we press "A" for flashing and the current image exists
if [ -f "./logos/$foldername/image1.jpg" ]; then
	DisplayInstructions=1
	./bin/say "정말로 플래싱 할까요?"$'\n'\("$foldername"\)$'\n\nA = 확인    B = 취소\nSelect = 전체화면'

	while :
	do
    	KeyPressed=$(./bin/getkey)
    	sleep 0.15  # Little debounce
    	echo "====== Key pressed : $KeyPressed"

    	if [ "$KeyPressed" = "A" ]; then
    		echo "=== Start flashing ==="
    		
    		rm "./logo.img"
    		cp "./logos/$foldername/image1.jpg" .

    		# if image2.jpg and image3.jpg are not here we get it from the "- Original" folder
    		if [ -f "./logos/$foldername/image2.jpg" ]; then
    			cp "./logos/$foldername/image2.jpg" .
    		else
    			./bin/blank
    			./bin/say "Importing default stock image"$'\n'"for \"System Upgrade\" screen."
    			sleep 1.5
    			cp "./logos/- Original/image2.jpg" .
    			if [[ $? -ne 0 ]] ; then
    			    ./bin/blank
    			    ./bin/say "Default flash images not found."$'\nPlease restore \"logos/- Original\" folder.\n\nExiting without flash !'
    			    ./bin/confirm any
                    exit 1
                fi
    		fi
    
    		if [ -f "./logos/$foldername/image3.jpg" ]; then
    			cp "./logos/$foldername/image3.jpg" .
    		else
    			./bin/blank
    			./bin/say "Importing default stock image"$'\n'"for \"Super Upgrade\" screen."
    			sleep 1.5
    			cp "./logos/- Original/image3.jpg" .
    			if [[ $? -ne 0 ]] ; then
    			    ./bin/blank
    			    ./bin/say "Default flash images not found."$'\nPlease restore \"logos/- Original\" folder.\n\nExiting without flash !'
    			    ./bin/confirm any
                    exit 1
                fi
    		fi
    		
    		# We check if each file is really a jpg file. (and not png files renamed).
    		checkjpg "./image1.jpg"
    		checkjpg "./image2.jpg"
    		checkjpg "./image3.jpg"
    		
    		# we create the logo.img
    		./bin/logomake
    		
    		# Patch screen offset for the Mini+
    		if [ "$MODEL" = "MMP" ]; then
    			HexEdit "./logo.img" 1086 2C
    			HexEdit "./logo.img" 1088 4C
    		fi
    
    
    		# just in case we check the size of the created logo.img
    		myfilesize=$(wc -c "./logo.img" | awk '{print $1}')
    		
    		if [ "$myfilesize" = "131072" ]; then
    			pkill -3 advmenu
    			./bin/blank
    			./bin/say "${myfilesize}kb : 올바른 파일 사이즈"
    			sleep 1.5
				
    			# == We don't backup anymore the current logo (useless most of the time) ==
    			# ./bin/blank
    			# ./bin/say "현재 로고를 백업합니다..."
    			# ./bin/logoread
    			# BackupFolder=backup_$(date +%Y%m%d_%H%M%S)
    			# mkdir ./$BackupFolder
    			# mv ./image1.jpg ./$BackupFolder
    			# mv ./image2.jpg ./$BackupFolder
    			# mv ./image3.jpg ./$BackupFolder
    			# sleep 1
				

				
				if [ "$MODEL" = "MMP" ]; then
						./bin/blank
						./bin/say "플래싱..."
						./bin/logowrite
						sleep 1.5
						./bin/blank
						./bin/say "플래싱 완료."$'\n 변경 사항을 보려면 재부팅하세요.\n\n메뉴로 돌아가려면 아무키나 누르세요.'
						./bin/confirm any
						exit 0
				else
					# Check for SPI write capability (for Mini with BoyaMicro chips)
					CHECK_WRITE=`./bin/checkwrite`
					CHECK_WRITE=$?
					
					if [ $CHECK_WRITE -eq 0 ]; then
						./bin/blank
						./bin/say "플래싱..."
						./bin/logowrite
						sleep 1.5
						./bin/blank
						./bin/say "플래싱 완료."$'\n 변경 사항을 보려면 재부팅하세요.\n\n메뉴로 돌아가려면 아무키나 누르세요.'
						./bin/confirm any
						exit 0
					fi
					
					if [ $CHECK_WRITE -eq 1 ]; then
						./bin/blank
						./bin/say "로고 파일을 작성합니다..."
						./bin/logoimgmake
						mv ./miyoo283_fw.img /mnt/SDCARD/miyoo283_fw.img
						sleep 1.5
						./bin/blank
						./bin/say "이미지 파일 작성완료."$'\n 전원을 끄고 메뉴를 누른 다음\nUSB 충전기에 연결하세요.\n충전 애니메이션이 표시되면 전원을 끄세요.'
						./bin/confirm any
						exit 0
					fi
				fi
				

    		else
    			./bin/blank
    			./bin/say "logo.img의 사이즈가 올바르지 않습니다"$'\n'"플래싱없이 종료합니다!"
    			sleep 3
    			exit 0
    		fi
    	elif [ "$KeyPressed" = "B" ] || [ "$KeyPressed" = "menu" ] ; then
    		./bin/blank
    		./bin/say "취소하는중"
    		exit
		elif [ "$KeyPressed" = "select" ]; then    # == if select has been pressed we don't display the text instructions
			if [ "$DisplayInstructions" = "1" ]; then
				DisplayInstructions=0
				./bin/blank
	            ./bin/jpgr "./logos/$foldername/image1.jpg"   # == Displays a rotated preview of the jpeg file
			else
				DisplayInstructions=1
			#	./bin/blank
	            ./bin/jpgr "./logos/$foldername/image1.jpg"   # == Displays a rotated preview of the jpeg file
				./bin/say "정말로 플래싱 할까요?"$'\n'\("$foldername"\)$'\n\nA = 확인    B = 취소\nSelect = 전체화면'
			fi
   
    	   	   
    	fi
	done
else
	echo "./logos/$foldername/image1.jpg를 찾을 수 없습니다"
	./bin/blank
	./bin/say "$foldername/image1.jpg를 찾을 수 없습니다"$'\n\n플래싱없이 종료합니다!'
	./bin/confirm any
	exit 1
fi

