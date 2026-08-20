#!/bin/bash

echo "================================================"
echo "LandShip CloudKit Sync Log Capture"
echo "================================================"
echo ""
echo "This script will capture logs using multiple methods."
echo "Press Ctrl+C to stop."
echo ""
echo "Capturing logs now..."
echo "================================================"
echo ""

# Try multiple predicates to catch the logs
log stream \
  --predicate 'eventMessage CONTAINS "LandShip" OR processImagePath CONTAINS "LandShip" OR subsystem CONTAINS "com.aeronauticaltrax"' \
  --style compact \
  --level debug \
  --color always

