#!/bin/bash

# Custom Flutter run script with filtered Android logs
# This filters out common Android system noise

echo "Starting Flutter app with filtered logs..."

# Run Flutter and filter out noisy logs
flutter run -d d6430b64 2>&1 | grep -v -E "(mPausedTimes|notifyStatusToSF|notifyDecodeFpsToSF|OplusFeedbackInfo|hdrtype is 0|fps is 0|mEDRDelayTime)"
