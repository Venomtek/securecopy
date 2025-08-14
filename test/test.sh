#!/bin/bash

CRCPATH="../bin"
CHECKSUM="BE2C65AC2D090191"
#CHECKSUM="BE2C65AC2D090192"

# Ensure local path, to guarantee that xattr works
# For example, a TrueNAS samba share does not work
TESTFILE="/tmp/fileundertest.txt"
CPFILE="/tmp/copyfile.txt"

echo "##################################################################################################"
echo "##################################################################################################"
echo "#########################  Basic test for crcsum and crccp  ######################################"
echo "##################################################################################################"
echo "##################################################################################################"

rm -f ${TESTFILE} ${CPFILE}

echo "TEST: Add CRC to file and compare with expected pre-calculated CRC"
echo "Create test file without checksum..."
dd if=<(yes foo) of=${TESTFILE} bs=1024 count=200 > /dev/null 2>&1

echo "Add checksum..."
${CRCPATH}/crcsum -a ${TESTFILE}  > /dev/null 2>&1
echo "Display checksum..."
OUTPUT=$(${CRCPATH}/crcsum -p ${TESTFILE}) > /dev/null 2>&1

echo $OUTPUT

# https://www.regextester.com/107384
# Extract calculated checksum
[[ ${OUTPUT} =~ (\[ )(.*)(.* \]) ]]
CHECKSUM_CALCULATED=(${BASH_REMATCH[2]})

if [[ "$OUTPUT" =~ .*"$CHECKSUM".* ]]; then
  echo "SUCCESS: Checksum calculated = ${CHECKSUM_CALCULATED}; Checksum expected = ${CHECKSUM}"
else
  echo "FAILURE: Checksum calculated = ${CHECKSUM_CALCULATED}; Checksum expected = ${CHECKSUM}"
  exit 1
fi

echo "##################################################################################################"
echo "##################################################################################################"
rm ${TESTFILE}
echo "TEST: Copy file (crccp -cx) without source CRC and compare with expected pre-calculated CRC"
echo "Create test file without checksum..."
dd if=<(yes foo) of=${TESTFILE} bs=1024 count=200 > /dev/null 2>&1

echo "Copy file and test checksum of destination..."
${CRCPATH}/crccp -cx -v ${TESTFILE} ${CPFILE}

echo "Display checksum..."
OUTPUT=$(${CRCPATH}/crcsum -p ${CPFILE})

echo ${OUTPUT}

# Extract calculated checksum
[[ ${OUTPUT} =~ (\[ )(.*)(.* \]) ]]
CHECKSUM_CALCULATED=(${BASH_REMATCH[2]})

if [[ "$OUTPUT" =~ .*"$CHECKSUM".* ]]; then
  echo "SUCCESS: Checksum calculated = ${CHECKSUM_CALCULATED}; Checksum expected = ${CHECKSUM}"
else
  echo "FAILURE: Checksum calculated = ${CHECKSUM_CALCULATED}; Checksum expected = ${CHECKSUM}"
  exit 1
fi

echo "##################################################################################################"
echo "##################################################################################################"
echo "TEST: File corruption test (crcsum -c)..."
rm ${TESTFILE}
dd if=<(yes foo) of=${TESTFILE} bs=1024 count=200 > /dev/null 2>&1

# Add checksum to testfile
${CRCPATH}/crcsum -a ${TESTFILE} > /dev/null 2>&1
OUTPUT=$(${CRCPATH}/crcsum -p ${TESTFILE})

echo "Simulate that ${TESTFILE} got corrupted..."
# Change content of file but restore timestamp
# Store timestamp
touch -r ${TESTFILE} time.stamp > /dev/null 2>&1

# Add 1 character
echo "a" >> ${TESTFILE}
touch -r time.stamp  ${TESTFILE} > /dev/null 2>&1
rm time.stamp > /dev/null 2>&1

OUTPUT=$(${CRCPATH}/crcsum -c -v ${TESTFILE})

echo $OUTPUT

# Extract calculated checksum
#regexp="\[[[:space:]]+(.*)[[:space:]]*\].*"
regexp=".*(FAILED|OK).*"
[[ ${OUTPUT} =~ ${regexp} ]]
REMATCH=(${BASH_REMATCH[1]})

if [[ "$REMATCH" =~ .*"FAILED".* ]]; then
  echo "Success: corrupted file detected"
else
  echo "Failure: corrupted file not detected"
  exit 1
fi

echo "##################################################################################################"
echo "##################################################################################################"
echo "TEST: Copy corrupted file (crccp -cx)..."
echo "Copy file and test checksum of destination..."
OUTPUT=$(${CRCPATH}/crccp -cx ${TESTFILE} ${CPFILE})
${CRCPATH}/crccp -cx -v ${TESTFILE} ${CPFILE}

regexp=".*(WARNING).*"
[[ ${OUTPUT} =~ ${regexp} ]]
REMATCH=(${BASH_REMATCH[1]})

if [[ "$REMATCH" =~ .*"WARNING".* ]]; then
  echo "Success: corrupted file while copying detected"
else
  echo "Failure: corrupted file not detected"
  exit 1
fi

rm -f ${TESTFILE} ${CPFILE}
