#!/bin/bash

ESUDO=""

if [[ -e "/dev/input/by-path/platform-ff300000.usb-usb-0:1.2:1.0-event-joystick" ]]; then
  param_device="anbernic"
elif [[ -e "/dev/input/by-path/platform-odroidgo2-joypad-event-joystick" ]]; then
  if [[ ! -z $(cat /etc/emulationstation/es_input.cfg | grep "190000004b4800000010000001010000") ]]; then
    param_device="oga"
  else
    param_device="rk2020"
  fi
elif [[ -e "/dev/input/by-path/platform-odroidgo3-joypad-event-joystick" ]]; then
  param_device="ogs"
elif [[ -e "/dev/input/by-path/platform-singleadc-joypad-event-joystick" ]]; then
  param_device="rg503"
else
  param_device="chi"
fi

if grep -q '<string name="Language" value="zh-CN" />' /home/ark/.emulationstation/es_settings.cfg; then
  export LANG=zh_CN.UTF-8 
  export LC_ALL=zh_CN.UTF-8
fi

if [[ $1 == *"standalone"* ]]; then
  directory=$(dirname "$2" | cut -d "/" -f2)
  if [[ ! -d "/$directory/saturn/yabasanshiro" ]]; then
    mkdir /$directory/saturn/yabasanshiro
  fi
  if [[ $1 == *"pi4"* ]]; then
    YABA_BIN="./yabasanshiro-pi4"
  else
    YABA_BIN="./yabasanshiro"
  fi
  cd /opt/yabasanshiro
  if [[ ! -f "input.cfg" ]]; then
    if [[ -f "keymapv2.json" ]]; then
      rm -f keymapv2.json
    fi
    cp -f /etc/emulationstation/es_input.cfg input.cfg
  fi
  sudo /opt/quitter/oga_controls yaba $param_device &
  if [[ $1 == *"-bios"* ]]; then
    if [[ ! -f "/$directory/bios/saturn_bios.bin" ]]; then
      printf "\033c" >> /dev/tty1
      printf "\033[1;33m" >> /dev/tty1
      printf "\n I don't detect a saturn_bios.bin bios file in the" >> /dev/tty1
      printf "\n /$directory/bios folder.  Either place one in that" >> /dev/tty1
      printf "\n location or switch to the standalone-nobios emulator." >> /dev/tty1
      sleep 10
      printf "\033[0m" >> /dev/tty1
    else
      $YABA_BIN  -r 3 -i "$2" -b /$directory/bios/saturn_bios.bin
    fi
  else
    $YABA_BIN  -r 3 -i "$2"
  fi
  if [[ ! -z $(pidof oga_controls) ]]; then
    sudo kill -9 $(pidof oga_controls)
  fi
  sudo systemctl restart oga_events &
  cd ~
elif  [[ $1 == "retroarch" ]]; then
  /usr/local/bin/"$1" -L /home/ark/.config/"$1"/cores/"$2"_libretro.so "$3"
elif [[ $1 == "retroarch32" ]]; then
  /usr/local/bin/"$1" -L /home/ark/.config/"$1"/cores/"$2"_libretro.so "$3"
elif [[ $1 == "retrorun" ]]; then
  directory=$(dirname "$3" | cut -d "/" -f2)
  if [[ ! -f "/$directory/bios/saturn_bios.bin" ]]; then
    printf "\033c" >> /dev/tty1
    printf "\033[1;33m" >> /dev/tty1
    printf "\n I don't detect a saturn_bios.bin bios file in the" >> /dev/tty1
    printf "\n /$directory/bios folder.  Either place one in that" >> /dev/tty1
    printf "\n location or switch to the standalone-nobios emulator." >> /dev/tty1
    sleep 10
    printf "\033[0m" >> /dev/tty1
  fi
  if [[ -e "/dev/input/by-path/platform-ff300000.usb-usb-0:1.2:1.0-event-joystick" ]]; then
    #sudo rm /dev/input/by-path/platform-odroidgo2-joypad-event-joystick || true
    #echo 'creating fake joypad'
    #sudo /usr/local/bin/rg351p-js2xbox --silent -t oga_joypad &
    #sleep 0.2
    #sudo ln -s /dev/input/event4 /dev/input/by-path/platform-odroidgo2-joypad-event-joystick
    #sudo chmod 777 /dev/input/by-path/platform-odroidgo2-joypad-event-joystick
    #sleep 0.2
    ESUDO="sudo --preserve-env=DEVICE_NAME"
    DEVICENAME="RG351V"
  elif [ -f "/boot/rk3566.dtb" ] || [ -f "/boot/rk3566-OC.dtb" ]; then
    if test ! -z "$(grep "RG353V" /home/ark/.config/.DEVICE | tr -d '\0')"
    then
      DEVICENAME="RG353V"
    elif test ! -z "$(grep "RG353M" /home/ark/.config/.DEVICE | tr -d '\0')"
    then
      DEVICENAME="RG353M"
    else
      DEVICENAME="RG503"
    fi
  elif [ -f "/boot/rk3326-r33s-linux.dtb" ] || [ -f "/boot/rk3326-r35s-linux.dtb" ] || [ -f "/boot/rk3326-r36s-linux.dtb" ] || [ -f "/boot/rk3326-rg351mp-linux.dtb" ]; then
    DEVICENAME="RG351MP"
  elif [ -f "/boot/rk3326-gameforce-linux.dtb" ]; then
    DEVICENAME="RG351MP"
  elif [ -f "/boot/rk3326-odroidgo2-linux.dtb" ] || [ -f "/boot/rk3326-odroidgo2-linux-v11.dtb" ] || [ -f "/boot/rk3326-odroidgo3-linux.dtb" ]; then
    DEVICENAME="RGB10"
  elif [ -f "/boot/.console" ]; then
      # 读取内容并去除换行符
      CONSOLE_VAL="$(tr -d '\r\n' < /boot/.console 2>/dev/null)"

      case "$CONSOLE_VAL" in
          u8|r50s|dr28s)
              DEVICENAME="U8"
              ;;
          a10miniv4)
            DEVICENAME="A10miniv2"
            ;;
          xf28)
            DEVICENAME="XF28"
            ;;
          *)
              DEVICENAME="RG351MP"
              ;;
      esac
  else
      DEVICENAME="RG351P"
  fi
  export DEVICE_NAME="${DEVICENAME}"

  #CURRUMBLESET="$(grep "retrorun_rumble_type = " /home/ark/.config/retrorun.cfg | cut -c24-)"

  #if [[ ${DEVICENAME} == "RG503" ]]; then
    #if [[ ${CURRUMBLESET} != "event" ]]; then
      #sed -i "/retrorun_rumble_type \=/c\retrorun_rumble_type \= event" /home/ark/.config/retrorun.cfg
    #fi
  #else
    #if [[ ${CURRUMBLESET} != "pwm" ]]; then
      #sed -i "/retrorun_rumble_type \=/c\retrorun_rumble_type \= pwm" /home/ark/.config/retrorun.cfg
    #fi
  #fi

  directory=$(dirname "$3" | cut -d "/" -f2)
  CURDIRECTORYSET="$(grep "retrorun_screenshot_folder = " /home/ark/.config/retrorun.cfg | cut -d "/" -f2-3)"
  if [[ "${CURDIRECTORYSET}" != "${directory}/saturn" ]]; then
    sed -i "/retrorun_screenshot_folder \=/c\retrorun_screenshot_folder \= \/$directory\/saturn" /home/ark/.config/retrorun.cfg
  fi

  $ESUDO /usr/local/bin/retrorun -c /home/ark/.config/retrorun.cfg --triggers -s /$directory/saturn -d /$directory/bios /home/ark/.config/retroarch/cores/"$2"_libretro.so "$3"

  if [[ -e "/dev/input/by-path/platform-ff300000.usb-usb-0:1.2:1.0-event-joystick" ]]; then
    sleep 0.5
    sudo rm /dev/input/by-path/platform-odroidgo2-joypad-event-joystick
    sudo kill $(pidof rg351p-js2xbox)
  fi
else
  directory=$(dirname "$3" | cut -d "/" -f2)
  if [[ ! -f "/$directory/bios/saturn_bios.bin" ]]; then
    printf "\033c" >> /dev/tty1
    printf "\033[1;33m" >> /dev/tty1
    printf "\n I don't detect a saturn_bios.bin bios file in the" >> /dev/tty1
    printf "\n /$directory/bios folder.  Either place one in that" >> /dev/tty1
    printf "\n location or switch to the standalone-nobios emulator." >> /dev/tty1
    sleep 10
    printf "\033[0m" >> /dev/tty1
  fi
  if [[ -e "/dev/input/by-path/platform-ff300000.usb-usb-0:1.2:1.0-event-joystick" ]]; then
    #sudo rm /dev/input/by-path/platform-odroidgo2-joypad-event-joystick || true
    #echo 'creating fake joypad'
    #sudo /usr/local/bin/rg351p-js2xbox --silent -t oga_joypad &
    #sleep 0.2
    #sudo ln -s /dev/input/event4 /dev/input/by-path/platform-odroidgo2-joypad-event-joystick
    #sudo chmod 777 /dev/input/by-path/platform-odroidgo2-joypad-event-joystick
    #sleep 0.2
    ESUDO="sudo --preserve-env=DEVICE_NAME"
    DEVICENAME="RG351V"
  elif [ -f "/boot/rk3566.dtb" ] || [ -f "/boot/rk3566-OC.dtb" ]; then
    if test ! -z "$(grep "RG353V" /home/ark/.config/.DEVICE | tr -d '\0')"
    then
      DEVICENAME="RG353V"
    elif test ! -z "$(grep "RG353M" /home/ark/.config/.DEVICE | tr -d '\0')"
    then
      DEVICENAME="RG353M"
    else
      DEVICENAME="RG503"
    fi
  elif [ -f "/boot/rk3326-r33s-linux.dtb" ] || [ -f "/boot/rk3326-r35s-linux.dtb" ] || [ -f "/boot/rk3326-r36s-linux.dtb" ] || [ -f "/boot/rk3326-rg351mp-linux.dtb" ]; then
    DEVICENAME="RG351MP"
  elif [ -f "/boot/rk3326-gameforce-linux.dtb" ]; then
    DEVICENAME="RG351MP"
  elif [ -f "/boot/rk3326-odroidgo2-linux.dtb" ] || [ -f "/boot/rk3326-odroidgo2-linux-v11.dtb" ] || [ -f "/boot/rk3326-odroidgo3-linux.dtb" ]; then
    DEVICENAME="RGB10"
  elif [ -f "/boot/.console" ]; then
      # 读取内容并去除换行符
      CONSOLE_VAL="$(tr -d '\r\n' < /boot/.console 2>/dev/null)"

      case "$CONSOLE_VAL" in
          u8|r50s|dr28s)
              DEVICENAME="U8"
              ;;
          a10miniv4)
            DEVICENAME="A10miniv2"
            ;;
          xf28)
            DEVICENAME="XF28"
            ;;
          *)
              DEVICENAME="RG351MP"
              ;;
      esac
  else
      DEVICENAME="RG351P"
  fi
  export DEVICE_NAME="${DEVICENAME}"

  #CURRUMBLESET="$(grep "retrorun_rumble_type = " /home/ark/.config/retrorun.cfg | cut -c24-)"

  #if [[ ${DEVICENAME} == "RG503" ]]; then
    #if [[ ${CURRUMBLESET} != "event" ]]; then
      #sed -i "/retrorun_rumble_type \=/c\retrorun_rumble_type \= event" /home/ark/.config/retrorun.cfg
    #fi
  #else
    #if [[ ${CURRUMBLESET} != "pwm" ]]; then
      #sed -i "/retrorun_rumble_type \=/c\retrorun_rumble_type \= pwm" /home/ark/.config/retrorun.cfg
    #fi
  #fi

  directory=$(dirname "$3" | cut -d "/" -f2)
  CURDIRECTORYSET="$(grep "retrorun_screenshot_folder = " /home/ark/.config/retrorun.cfg | cut -d "/" -f2-3)"
  if [[ "${CURDIRECTORYSET}" != "${directory}/saturn" ]]; then
    sed -i "/retrorun_screenshot_folder \=/c\retrorun_screenshot_folder \= \/$directory\/saturn" /home/ark/.config/retrorun.cfg
  fi

  $ESUDO /usr/local/bin/retrorun32 -c /home/ark/.config/retrorun.cfg --triggers -s /$directory/saturn -d /$directory/bios /home/ark/.config/retroarch32/cores/"$2"_libretro.so "$3"

  if [[ -e "/dev/input/by-path/platform-ff300000.usb-usb-0:1.2:1.0-event-joystick" ]]; then
    sleep 0.5
    sudo rm /dev/input/by-path/platform-odroidgo2-joypad-event-joystick
    sudo kill $(pidof rg351p-js2xbox)
  fi
fi
