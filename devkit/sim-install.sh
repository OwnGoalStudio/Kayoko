#!/bin/sh

if [ -z "$THEOS_DEVICE_SIMULATOR" ]; then
  exit 0
fi

cd $(dirname $0)/..

TWEAK_NAMES="DictationInKeyboard"

for TWEAK_NAME in $TWEAK_NAMES; do
  sudo rm -f /opt/simject/$TWEAK_NAME.dylib
  sudo cp -v $THEOS_OBJ_DIR/$TWEAK_NAME.dylib /opt/simject/$TWEAK_NAME.dylib
  sudo codesign -f -s - /opt/simject/$TWEAK_NAME.dylib
  sudo cp -v $PWD/$TWEAK_NAME.plist /opt/simject
done

resim